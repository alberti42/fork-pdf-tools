;; -*- lexical-binding: t -*-

(require 'pdf-view)
(require 'ert)

;; Tests for pdf-view-register struct and cl-defmethod implementations.
;; These tests use mock bookmark data because the actual pdf-view-registerv-make
;; function requires a window context which isn't available in batch mode.

(ert-deftest pdf-view-register-struct-creation ()
  "Test that pdf-view-register struct can be created."
  (let* ((mock-bookmark '("test.pdf"
                          (filename . "/path/to/test.pdf")
                          (page . 1)
                          (origin . (0.0 . 0.0))
                          (handler . pdf-view-bookmark-jump-handler)))
         (reg (pdf-view-register--make mock-bookmark)))
    ;; Should return non-nil
    (should reg)
    ;; Should be a pdf-view-register struct
    (should (pdf-view-register-p reg))
    ;; Should store the bookmark
    (should (equal (pdf-view-register-bookmark reg) mock-bookmark))))

(ert-deftest pdf-view-register-val-describe ()
  "Test that register-val-describe works for PDF register entries."
  (let* ((mock-bookmark '("test.pdf"
                          (filename . "/path/to/test.pdf")
                          (page . 5)
                          (origin . (0.0 . 0.5))
                          (handler . pdf-view-bookmark-jump-handler)))
         (reg (pdf-view-register--make mock-bookmark)))
    ;; register-val-describe should return a non-empty string
    (should (stringp
             (with-output-to-string
               (register-val-describe reg nil))))
    ;; The description should mention the page number
    (should (string-match-p "page 5"
             (with-output-to-string
               (register-val-describe reg nil))))))

(ert-deftest pdf-view-register-val-insert ()
  "Test that register-val-insert works for PDF register entries."
  (let* ((mock-bookmark '("test.pdf"
                          (filename . "/path/to/test.pdf")
                          (page . 1)
                          (handler . pdf-view-bookmark-jump-handler)))
         (reg (pdf-view-register--make mock-bookmark)))
    ;; register-val-insert should insert text without error
    (with-temp-buffer
      (register-val-insert reg)
      (should (> (buffer-size) 0)))))

(ert-deftest pdf-view-handle-archived-file ()
  :expected-result :failed
  (skip-unless (executable-find "gzip"))
  (let ((tramp-verbose 0)
        (temp
         (make-temp-file "pdf-test")))
    (unwind-protect
        (progn
          (copy-file "test.pdf" temp t)
          (call-process "gzip" nil nil nil temp)
          (setq temp (concat temp ".gz"))
          (should (numberp (pdf-info-number-of-pages temp)))))
    (when (file-exists-p temp)
      (delete-file temp))))

;;; Saving a document the server cannot open by itself

(defmacro pdf-view-test-with-compressed-pdf (var &rest body)
  "Gzip test.pdf, open it, bind VAR to the buffer and run BODY."
  (declare (indent 1) (debug t))
  `(let* ((plain (make-temp-file "pdf-view-test-" nil ".pdf"))
          (gz (concat plain ".gz")))
     (unwind-protect
         (progn
           ;; As `pdf-test-with-pdf' does: another test may have left the
           ;; server dead.
           (pdf-info-quit)
           (pdf-info-process-assert-running t)
           (copy-file (expand-file-name "test.pdf") plain t)
           (unless (eq 0 (call-process "gzip" nil nil nil "-f" plain))
             (error "Could not gzip %s" plain))
           (let ((,var (find-file-noselect gz)))
             (with-current-buffer ,var
               (unless (derived-mode-p 'pdf-view-mode) (pdf-view-mode)))
             (unwind-protect (progn ,@body)
               (when (buffer-live-p ,var)
                 (with-current-buffer ,var
                   (set-buffer-modified-p nil)
                   (let (kill-buffer-hook) (kill-buffer)))))))
       (pdf-info-quit)
       (dolist (f (list plain gz))
         (when (file-exists-p f) (delete-file f))))))

(defun pdf-view-test-file-magic (file)
  "Return the first two bytes of FILE as a string."
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (insert-file-contents-literally file nil 0 2)
    (buffer-string)))

(defun pdf-view-test-annotation-count (gz)
  "Return how many annotations the gzipped document GZ has."
  (let ((copy (make-temp-file "pdf-view-test-" nil ".pdf")))
    (unwind-protect
        (progn
          (with-temp-file copy
            (set-buffer-multibyte nil)
            (unless (eq 0 (call-process "gzip" nil t nil "-dc" gz))
              (error "Could not decompress %s" gz)))
          (prog1 (length (pdf-info-getannots nil copy))
            (pdf-info-close copy)))
      (when (file-exists-p copy) (delete-file copy)))))

(ert-deftest pdf-view-save-keeps-a-pdf-compressed ()
  "Saving a .pdf.gz leaves a gzip file, not a plain PDF."
  (skip-unless (executable-find "gzip"))
  (pdf-view-test-with-compressed-pdf buffer
    (with-current-buffer buffer
      (pdf-info-addannot 1 '(0.1 0.1 0.5 0.15) 'highlight)
      (set-buffer-modified-p t)
      (save-buffer)
      (should (equal (unibyte-string #x1f #x8b)
                     (pdf-view-test-file-magic (buffer-file-name)))))))

(ert-deftest pdf-view-save-leaves-the-buffer-in-step ()
  "After saving a .pdf.gz the buffer shows what the file holds.

The server reads a copy of a document Emacs had to decompress for it, and
that copy has to be given the saved document too."
  (skip-unless (executable-find "gzip"))
  (pdf-view-test-with-compressed-pdf buffer
    (with-current-buffer buffer
      (let ((before (length (pdf-info-getannots))))
        (pdf-info-addannot 1 '(0.1 0.1 0.5 0.15) 'highlight)
        ;; `pdf-info-addannot' changes the document the server holds; the
        ;; commands that call it are what mark the buffer.
        (set-buffer-modified-p t)
        (save-buffer)
        (should (= (1+ before) (pdf-view-test-annotation-count (buffer-file-name))))
        (should (= (1+ before) (length (pdf-info-getannots))))))))

(ert-deftest pdf-view-save-twice-keeps-both-annotations ()
  "Two saves in a row keep what each of them added."
  (skip-unless (executable-find "gzip"))
  (pdf-view-test-with-compressed-pdf buffer
    (with-current-buffer buffer
      (let ((before (length (pdf-info-getannots))))
        (pdf-info-addannot 1 '(0.1 0.1 0.5 0.15) 'highlight)
        ;; `pdf-info-addannot' changes the document the server holds; the
        ;; commands that call it are what mark the buffer.
        (set-buffer-modified-p t)
        (save-buffer)
        (pdf-info-addannot 1 '(0.1 0.2 0.5 0.25) 'highlight)
        (set-buffer-modified-p t)
        (save-buffer)
        (should (= (+ 2 before) (pdf-view-test-annotation-count (buffer-file-name))))))))

(ert-deftest pdf-view-save-a-pdf-inside-a-tar ()
  "Saving a PDF that lives in a tar puts it back into the archive."
  (skip-unless (executable-find "tar"))
  ;; `tar-extract' displays the buffer, so a page is rendered, which an
  ;; Emacs built without PNG cannot do.
  (skip-unless (image-type-available-p 'png))
  (let* ((dir (make-temp-file "pdf-view-test-" t))
         (tarfile (expand-file-name "archive.tar" dir))
         (out (expand-file-name "out" dir))
         tarbuf member)
    (unwind-protect
        (progn
          (pdf-info-quit)
          (pdf-info-process-assert-running t)
          (copy-file (expand-file-name "test.pdf") (expand-file-name "doc.pdf" dir) t)
          (let ((default-directory dir))
            (unless (eq 0 (call-process "tar" nil nil nil "cf" tarfile "doc.pdf"))
              (error "Could not write %s" tarfile)))
          ;; `tar-extract' runs `normal-mode' and then turns on
          ;; `tar-subfile-mode'; setting the major mode afterwards would
          ;; undo that, so let the mode be chosen the usual way.
          (add-to-list 'auto-mode-alist '("\\.[pP][dD][fF]\\'" . pdf-view-mode))
          (setq tarbuf (find-file-noselect tarfile))
          (with-current-buffer tarbuf
            (goto-char (point-min))
            (should (re-search-forward "doc\\.pdf" nil t))
            (beginning-of-line)
            (tar-extract)
            (setq member (current-buffer)))
          (with-current-buffer member
            (should (derived-mode-p 'pdf-view-mode))
            (should (bound-and-true-p tar-subfile-mode))
            (let ((before (length (pdf-info-getannots))))
              (pdf-info-addannot 1 '(0.1 0.1 0.5 0.15) 'highlight)
              (set-buffer-modified-p t)
              (save-buffer)
              (with-current-buffer tarbuf (save-buffer))
              (make-directory out t)
              (unless (eq 0 (call-process "tar" nil nil nil "xf" tarfile "-C" out))
                (error "Could not read %s back" tarfile))
              (should (= (1+ before)
                         (length (pdf-info-getannots
                                  nil (expand-file-name "doc.pdf" out))))))))
      (pdf-info-quit)
      (dolist (b (list member tarbuf))
        (when (buffer-live-p b)
          (with-current-buffer b
            (set-buffer-modified-p nil)
            (let (kill-buffer-hook) (kill-buffer)))))
      (when (file-directory-p dir) (delete-directory dir t)))))

(defconst pdf-view-test-gpg-uid "pdf-tools-test@example.invalid"
  "The mock key the encrypted-document test encrypts to.")

(defconst pdf-view-test-gpg-fingerprint
  "3B19520851A05B7873843D3DBAB0869C7E18F8F7"
  "Fingerprint of the key in test/gpg, so its owner trust can be set.
Without that epa stops to ask whether an untrusted key may be used.")

(defmacro pdf-view-test-with-gnupghome (&rest body)
  "Run BODY with a GNUPGHOME holding only test/gpg's key.
The key has no passphrase, so nothing asks for one."
  (declare (indent 0) (debug t))
  ;; Short, because the gpg-agent socket lives in here and a Unix socket
  ;; path cannot exceed about a hundred characters -- which the temporary
  ;; directory alone uses up on macOS.
  `(let* ((home (make-temp-file (expand-file-name
                                 "pdf-gh" (if (file-directory-p "/tmp")
                                              "/tmp"
                                            temporary-file-directory))
                                t))
          (process-environment (cons (concat "GNUPGHOME=" home)
                                     process-environment)))
     (set-file-modes home #o700)
     (unwind-protect
         (progn
           (unless (eq 0 (call-process "gpg" nil nil nil "--batch" "--quiet"
                                       "--import"
                                       (expand-file-name
                                        "gpg/test-key-no-passphrase.asc")))
             (error "Could not import the test key"))
           ;; Ultimate owner trust, or epa asks whether the key may be used.
           (with-temp-buffer
             (insert pdf-view-test-gpg-fingerprint ":6:\n")
             (unless (eq 0 (call-process-region
                            (point-min) (point-max) "gpg" nil nil nil
                            "--batch" "--quiet" "--import-ownertrust"))
               (error "Could not set the owner trust of the test key")))
           ,@body)
       (ignore-errors
         (call-process "gpgconf" nil nil nil "--homedir" home "--kill" "all"))
       (when (file-directory-p home) (delete-directory home t)))))

(ert-deftest pdf-view-save-keeps-a-pdf-encrypted ()
  "Saving a .pdf.gpg leaves an encrypted file with the annotation in it."
  (skip-unless (and (executable-find "gpg")
                    (file-exists-p (expand-file-name
                                    "gpg/test-key-no-passphrase.asc"))))
  (require 'epa-file)
  (pdf-view-test-with-gnupghome
    (let* ((dir (make-temp-file "pdf-view-test-" t))
           (plain (expand-file-name "doc.pdf" dir))
           (enc (concat plain ".gpg"))
           (out (expand-file-name "out.pdf" dir))
           buffer)
      (unwind-protect
          (progn
            (pdf-info-quit)
            (pdf-info-process-assert-running t)
            (copy-file (expand-file-name "test.pdf") plain t)
            (unless (eq 0 (call-process "gpg" nil nil nil "--batch" "--yes"
                                        "--trust-model" "always" "--quiet"
                                        "--recipient" pdf-view-test-gpg-uid
                                        "--output" enc "--encrypt" plain))
              (error "Could not encrypt %s" plain))
            (epa-file-enable)
            (add-to-list 'auto-mode-alist '("\\.[pP][dD][fF]\\'" . pdf-view-mode))
            (setq buffer (find-file-noselect enc))
            (with-current-buffer buffer
              (should (derived-mode-p 'pdf-view-mode))
              (setq-local epa-file-encrypt-to (list pdf-view-test-gpg-uid))
              (let ((before (length (pdf-info-getannots))))
                (pdf-info-addannot 1 '(0.1 0.1 0.5 0.15) 'highlight)
                (set-buffer-modified-p t)
                (save-buffer)
                ;; Still OpenPGP: a plain PDF would start with "%PDF".
                (should-not (equal "%PDF"
                                   (with-temp-buffer
                                     (set-buffer-multibyte nil)
                                     (insert-file-contents-literally enc nil 0 4)
                                     (buffer-string))))
                ;; And it decrypts to the document with the annotation.
                (unless (eq 0 (call-process "gpg" nil nil nil "--batch" "--yes"
                                            "--quiet" "--output" out
                                            "--decrypt" enc))
                  (error "Could not decrypt %s" enc))
                (should (= (1+ before) (length (pdf-info-getannots nil out)))))))
        (when (buffer-live-p buffer)
          (with-current-buffer buffer
            (set-buffer-modified-p nil)
            (let (kill-buffer-hook) (kill-buffer))))
        (pdf-info-quit)
        (when (file-directory-p dir) (delete-directory dir t))))))

(defun pdf-test-mode-line-position ()
  "Return `mode-line-position' as redisplay would render it.
`format-mode-line' returns the empty string in batch, so the construct is
evaluated here instead."
  (mapconcat (lambda (element)
               (cond
                ((and (consp element) (eq (car element) :eval))
                 (format "%s" (eval (cadr element) t)))
                ((and (symbolp element) (boundp element))
                 (format "%s" (symbol-value element)))
                (t (format "%s" element))))
             mode-line-position ""))

(ert-deftest pdf-view-mode-line-asks-the-server-nothing ()
  "The mode line is evaluated during redisplay, so it may not query.

A query waits in `accept-process-output', which runs timers and other
processes' filters and sentinels in the middle of that redisplay."
  (pdf-test-with-test-pdf
    ;; `find-file-noselect' alone does not enter the mode in batch.
    (pdf-view-mode)
    (should (equal 6 pdf-view--mode-line-number-of-pages))
    (should (equal '("1" "2" "3" "4" "5" "6") pdf-view--mode-line-pagelabels))
    (let (queried)
      (cl-letf (((symbol-function 'pdf-info-query)
                 (lambda (cmd &rest _) (setq queried cmd)))
                ((symbol-function 'image-mode-window-get)
                 (lambda (prop &optional _w) (when (eq prop 'page) 3))))
        (should (equal " P3/6" (pdf-test-mode-line-position)))
        (let ((pdf-view-mode-line-position-use-labels t))
          (should (equal " P3/6" (pdf-test-mode-line-position)))))
      (should-not queried))))

(ert-deftest pdf-view-mode-line-answers-without-the-data ()
  "The construct reports the states it used to signal in."
  (pdf-test-with-test-pdf
    (pdf-view-mode)
    (cl-letf (((symbol-function 'image-mode-window-get) (lambda (&rest _) nil)))
      ;; No page in the window yet.
      (should (equal " P?/6" (pdf-test-mode-line-position))))
    (let ((pdf-view--mode-line-number-of-pages nil))
      (cl-letf (((symbol-function 'image-mode-window-get)
                 (lambda (prop &optional _w) (when (eq prop 'page) 3))))
        (should (equal " P3/???" (pdf-test-mode-line-position)))))))

(ert-deftest pdf-view-desired-image-size-keeps-the-aspect-under-the-cap ()
  "Capping the width at `pdf-view-max-image-width' reduces the height too."
  (pdf-test-with-test-pdf
    (pdf-view-mode)
    (cl-letf (((symbol-function 'pdf-cache-pagesize) (lambda (_) '(600 . 800))))
      (let ((pdf-view-display-size 2.0))
        (let ((pdf-view-max-image-width nil))
          (should (equal '(1200 . 1600) (pdf-view-desired-image-size 1))))
        (let ((pdf-view-max-image-width 600))
          (should (equal '(600 . 800) (pdf-view-desired-image-size 1))))))))

(ert-deftest pdf-view-create-page-gives-emacs-the-height ()
  "The image gets the height epdfinfo renders, not one Emacs computes.

At 900 pixels a 612x792 page is 1164.7 rows high, which epdfinfo rounds
to 1165.  `create-image' and `pdf-view-image-type' are replaced because
Emacs on CI lacks PNG support."
  (pdf-test-with-test-pdf
    (pdf-view-mode)
    (let (props)
      (cl-letf (((symbol-function 'pdf-cache-pagesize) (lambda (_) '(612 . 792)))
                ((symbol-function 'pdf-cache-renderpage) (lambda (&rest _) "data"))
                ((symbol-function 'pdf-view-image-type) (lambda () 'png))
                ((symbol-function 'create-image)
                 (lambda (_data _type _data-p &rest p) (setq props p))))
        (let ((pdf-view-display-size 2.0)
              (pdf-view-max-image-width 900))
          (should (equal '(900 . 1165) (pdf-view-desired-image-size 1)))
          (pdf-view-create-page 1)
          (should (equal 900 (plist-get props :width)))
          (should (equal 1165 (plist-get props :height))))))))

(ert-deftest pdf-view-displayed-page-size-applies-relief-rotation-and-slice ()
  "The displayed size follows the image through relief, rotation and slice.

The sizes are those a graphical Emacs 32.0.50 displayed for the same
settings; `image-display-size' cannot be called in batch."
  (pdf-test-with-test-pdf
    (pdf-view-mode)
    (cl-letf (((symbol-function 'pdf-cache-pagesize) (lambda (_) '(600 . 800))))
      (let ((pdf-view-display-size 1.0)
            (pdf-view-max-image-width nil)
            (pdf-view-image-relief 0)
            (pdf-view--current-rotation 0))
        (should (equal '(600 . 800) (pdf-view-displayed-page-size 1)))
        (let ((pdf-view-image-relief 3))
          (should (equal '(606 . 806) (pdf-view-displayed-page-size 1)))
          (let ((pdf-view--current-rotation 90))
            (should (equal '(806 . 606) (pdf-view-displayed-page-size 1)))
            (setf (pdf-view-current-slice) '(0.1 0.2 0.5 0.6))
            (unwind-protect
                ;; 0.5 * 806 and 0.6 * 606 = 363.6
                (should (equal '(403 . 364) (pdf-view-displayed-page-size 1)))
              (setf (pdf-view-current-slice) nil))))
        (let ((pdf-view--current-rotation 180))
          (should (equal '(600 . 800) (pdf-view-displayed-page-size 1))))))))

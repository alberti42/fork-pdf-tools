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

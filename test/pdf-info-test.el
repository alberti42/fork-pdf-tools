;; -*- lexical-binding: t -*-

(ert-deftest pdf-info-open/close ()
  (pdf-test-with-test-pdf
   (should-not (pdf-info-open))
   (should (pdf-info-close)))
  (pdf-test-with-encrypted-pdf
   (should-error (pdf-info-open nil "Invalid Password"))
   (should-not (pdf-info-open nil "pdftool"))))

(ert-deftest pdf-info-metadata ()
  (pdf-test-with-test-pdf
    (should (cl-every (lambda (elt)
                        (and (consp elt)
                             (symbolp (car elt))))
                      (pdf-info-metadata)))))

(ert-deftest pdf-info-search-string ()
  (pdf-test-with-test-pdf
   (let (matches)
     (should (setq matches (pdf-info-search-string "PDF Tools")))
     (should (= 2 (length matches)))
     (should (cl-every (lambda (m)
                         (let-alist m
                           (and (stringp .text)
                                (cl-every 'pdf-test-relative-edges-p .edges)
                                (= 1 .page))))
                       matches)))))


(ert-deftest pdf-info-search-regexp ()
  (pdf-test-with-test-pdf
    (let (case-fold-search matches)
      (should (setq matches (pdf-info-search-regexp "PDF Tools")))
      (should (= 2 (length matches)))
      (should (cl-every (lambda (m)
                          (let-alist m
                            (and (stringp .text)
                                 (cl-every 'pdf-test-relative-edges-p .edges)
                                 (= 1 .page))))
                        matches)))))

(ert-deftest pdf-info-pagelinks ()
  (pdf-test-with-test-pdf
    (let ((links (pdf-info-pagelinks 3)))
      (should (= 2 (length links)))
      (should (cl-every 'pdf-test-relative-edges-p
                        (mapcar (apply-partially 'alist-get 'edges)
                                links)))
      (should (equal (mapcar (apply-partially 'alist-get 'type) links)
                     '(goto-dest uri)))
      (should (equal (mapcar (apply-partially 'alist-get 'uri)
                             links)
                     '(nil "http://www.gnu.org")))
      (should (equal (mapcar (apply-partially 'alist-get 'page)
                             links)
                     '(1 nil))))))

(ert-deftest pdf-info-number-of-pages ()
  (pdf-test-with-test-pdf
    (should (= 6 (pdf-info-number-of-pages)))))

(ert-deftest pdf-info-outline ()
  (pdf-test-with-test-pdf
   (let ((outline (pdf-info-outline)))
     (should (= 7 (length outline)))
     (should (equal (mapcar (apply-partially 'alist-get 'depth) outline)
                    '(1 1 1 1 1 2 3)))
     (should (cl-every (lambda (elt)
                         (eq (alist-get 'type elt)
                             'goto-dest))
                       outline)))))

(ert-deftest pdf-info-gettext ()
  (pdf-test-with-test-pdf
    (should (string-match "PDF Tools\\(?:.\\|\n\\)*in memory"
                          (pdf-info-gettext 1 '(0 0 1 1))))))

(ert-deftest pdf-info-getselection ()
  (pdf-test-with-test-pdf
    (should (consp (pdf-info-getselection 1 '(0 0 1 1))))
    (should (cl-every 'pdf-test-relative-edges-p
                      (pdf-info-getselection 1 '(0 0 1 1))))))

(ert-deftest pdf-info-textregions ()
  (pdf-test-with-test-pdf
    (should (consp (pdf-info-textregions 1)))))

(ert-deftest pdf-info-pagesize ()
  (pdf-test-with-test-pdf
    (should (cl-every (lambda (size)
                        (and (consp size)
                             (natnump (car size))
                             (natnump (cdr size))))
                      (list (pdf-info-pagesize 1))))))

(ert-deftest pdf-info-quit ()
  (pdf-test-with-test-pdf
    (pdf-info-quit)
    (let (pdf-info-restart-process-p)
      (should-error (pdf-info-open)))
    (let ((pdf-info-restart-process-p t))
      (pdf-info-open)
      (should (pdf-info-close)))))

(ert-deftest pdf-info-getannots ()
  (skip-unless (pdf-info-writable-annotations-p))
  (pdf-test-with-test-pdf
    (when (memq 'markup-annotations
                (pdf-info-features))
      (cl-labels ((alists-get (alists key)
                    (mapcar (lambda (alist)
                              (cdr (assoc key alist)))
                            alists)))
        (let (annots)
          (should (= 5 (length (setq annots (cl-remove-if
                                             (lambda (elt)
                                               (memq (cdr (assq 'type elt))
                                                     '(file link)))
                                             (pdf-info-getannots))))))
          (should (equal (alists-get annots 'page)
                         '(2 2 2 2 2)))
          (should (equal (sort (copy-sequence (alists-get annots 'type)) 'string-lessp)
                         (sort (copy-sequence
                                '(text strike-out highlight underline squiggly))
                               'string-lessp)))
          (should (equal (alists-get annots 'color)
                         '("#ff0000" "#ff0000" "#ff0000"
                           "#ff0000" "#ff0000")))
          (should (cl-every 'pdf-test-relative-edges-p
                            (alists-get annots 'edges))))))))

(ert-deftest pdf-info-getannot ()
  (skip-unless (pdf-info-writable-annotations-p))
  (pdf-test-with-test-pdf
    (let* ((text-annot (car
                        (cl-remove-if-not (lambda (elt)
                                            (eq (cdr (assq 'type elt)) 'text))
                                          (pdf-info-getannots))))
           (key (cdr (assq 'id text-annot))))
      (should (consp text-annot))
      (should (symbolp key))
      (should key)
      (should (equal (cl-sort text-annot 'string-lessp :key 'car)
                     (cl-sort (pdf-info-getannot key)
                              'string-lessp :key 'car))))))

(ert-deftest pdf-info-addannot ()
  (skip-unless (pdf-info-writable-annotations-p))
  (pdf-test-with-test-pdf
    (let (annot)
      (should (consp (setq annot
                           (pdf-info-addannot 1 '(0 0 1 1) 'text))))
      (should (eq 1 (cdr (assq 'page annot))))
      (should (eq 'text (cdr (assq 'type annot))))
      (should (equal "" (cdr (assq 'contents annot)))))))

(ert-deftest pdf-info-delannot ()
  (skip-unless (pdf-info-writable-annotations-p))
  (pdf-test-with-test-pdf
    (let ((nannots (length (pdf-info-getannots)))
          annots)
      (push (pdf-info-addannot 1 '(0 0 1 1) 'text)
            annots)
      (when (memq 'markup-annotations
                  (pdf-info-features))

         (push (pdf-info-addannot 1 '(0 0 1 1) 'squiggly nil nil '(0 0 1 1)) annots)
         (push (pdf-info-addannot 1 '(0 0 1 1) 'highlight 'word nil '(0 0 1 1)) annots)
         (push (pdf-info-addannot 1 '(0 0 1 1) 'underline 'line nil '(0 0 1 1)) annots)
        (push (pdf-info-addannot 1 '(0 0 1 1) 'strike-out 'glyph nil '(0 0 1 1)) annots))
      (dolist (a annots)
        (pdf-info-delannot (cdr (assq 'id a))))
      (should (= nannots (length (pdf-info-getannots)))))))

(ert-deftest pdf-info-mvannot ()
  (skip-unless (pdf-info-writable-annotations-p))
  (pdf-test-with-test-pdf
    (let ((edges '(0.25 0.25 1.0 1.0))
          (id (cdr (assq 'id (car (pdf-info-getannots))))))
      (pdf-info-mvannot id edges)
      (should (equal (cdr (assq 'edges (pdf-info-getannot id)))
                     edges)))))

(ert-deftest pdf-info-editannot ()
  (skip-unless (pdf-info-writable-annotations-p))
  (pdf-test-with-test-pdf
    (let ((color "#ffa500")
          (id (cdr (assq 'id (car (pdf-info-getannots))))))
      (should (and id (symbolp id)))
      (pdf-info-editannot id `((color . ,color)))
      (should (equal (cdr (assq 'color (pdf-info-getannot id)))
                     color)))))

(ert-deftest pdf-info-save ()
  (skip-unless (pdf-info-writable-annotations-p))
  (pdf-test-with-test-pdf
    (dolist (id (mapcar (lambda (a)
                          (cdr (assq 'id a)))
                        (pdf-info-getannots)))
      (pdf-info-delannot id))
    (let (tempfile)
      (unwind-protect
          (progn
            (setq tempfile (pdf-info-save))
            (should (file-exists-p tempfile))
            (should (= 0 (length (pdf-info-getannots nil tempfile)))))
        (when (file-exists-p tempfile)
          (delete-file tempfile))))))

(ert-deftest pdf-info-check-epdfinfo ()
  (should (progn (pdf-info-check-epdfinfo) t))
  (should-error
   (let (pdf-info-epdfinfo-program)
     (pdf-info-check-epdfinfo)))
  (should-error
   (let ((pdf-info-epdfinfo-program 42))
     (pdf-info-check-epdfinfo)))
  (should-error
   (let ((pdf-info-epdfinfo-program
          (make-temp-name "pdf-info")))
     (pdf-info-check-epdfinfo))))

;; FIXME: Write me.
;; (ert-deftest pdf-info-getattachment-from-annot ()
;;   (pdf-test-with-test-pdf
;;     ))

;; (ert-deftest pdf-info-getattachments ()
;;   (pdf-test-with-test-pdf
;;     ))

;; (ert-deftest pdf-info-synctex-forward-search ()
;;   (pdf-test-with-test-pdf
;;     ))

;; (ert-deftest pdf-info-synctex-backward-search ()
;;   (pdf-test-with-test-pdf
;;     ))

;; (ert-deftest pdf-info-renderpage ()
;;   (pdf-test-with-test-pdf
;;     ))

;; (ert-deftest pdf-info-renderpage-text-regions ()
;;   (pdf-test-with-test-pdf
;;     ))

;; (ert-deftest pdf-info-renderpage-highlight ()
;;   (pdf-test-with-test-pdf
;;     ))

;; (ert-deftest pdf-info-boundingbox ()
;;   (pdf-test-with-test-pdf
;;     ))

(ert-deftest pdf-info-query-runs-no-timers-while-waiting ()
  "A synchronous query may not hand control to a timer.

The wait is reachable from a mode-line construct, which Emacs evaluates
while it is displaying, so a timer running here runs arbitrary Lisp in the
middle of a redisplay."
  (pdf-test-with-test-pdf
    (let (fired)
      (run-at-time 0 nil (lambda () (setq fired t)))
      ;; Long enough for a timer due now to have had its chance.
      (should (pdf-info-renderpage 1 1400))
      (should-not fired)
      ;; And it is only held off, not lost.
      (sit-for 0.1)
      (should fired))))

(ert-deftest pdf-info-document-survives-its-file-written-over ()
  "A document read into memory stays as it was opened, until closed."
  (let* ((test-pdf (expand-file-name "test.pdf"))
         (other-pdf (expand-file-name "encrypted.pdf"))
         (dir (file-name-as-directory (make-temp-file "pdf-info-test-" t)))
         (default-directory dir))
    (unwind-protect
        (progn
          (copy-file test-pdf dir)
          (pdf-test-with-test-pdf
            (skip-unless (pdf-info-documents-in-memory-p))
            (should (string-prefix-p "1" (pdf-info-gettext 1 '(0 0 1 1))))
            ;; Write over the file in place, as `write-region' does.
            (let ((coding-system-for-write 'binary))
              (with-temp-buffer
                (set-buffer-multibyte nil)
                (insert-file-contents-literally other-pdf)
                (write-region nil nil (expand-file-name "test.pdf" dir)
                              nil 'silent)))
            (dolist (page '(2 3 4 5))
              (should (string-prefix-p (number-to-string page)
                                       (pdf-info-gettext page '(0 0 1 1)))))))
      (delete-directory dir t))))

(ert-deftest pdf-info-epdfinfo-version-matches-server ()
  "`pdf-info-epdfinfo-version' equals EPDFINFO_VERSION in the server."
  (with-temp-buffer
    (insert-file-contents "../server/epdfinfo.h")
    (should (re-search-forward
             "^#define EPDFINFO_VERSION \"\\([^\"]+\\)\"" nil t))
    (should (equal (match-string 1) pdf-info-epdfinfo-version))))

(ert-deftest pdf-info-epdfinfo-program-version ()
  (should (equal (pdf-info-epdfinfo-program-version)
                 pdf-info-epdfinfo-version)))

(ert-deftest pdf-info-epdfinfo-version-problem ()
  (let ((pdf-info-epdfinfo-version "1.2.3"))
    (should (eq 'older (pdf-info-epdfinfo-version-problem nil)))
    (should (eq 'older (pdf-info-epdfinfo-version-problem "0.9.9")))
    (should (eq 'older (pdf-info-epdfinfo-version-problem "1.2.2")))
    (should-not (pdf-info-epdfinfo-version-problem "1.2.3"))
    (should-not (pdf-info-epdfinfo-version-problem "1.3.0"))
    (should (eq 'newer (pdf-info-epdfinfo-version-problem "2.0.0")))))

(ert-deftest pdf-info-quit-keeps-unsaved-changes ()
  (pdf-test-with-test-pdf
    ;; Visiting the file runs `pdf-view-mode' only if an earlier test
    ;; added it to `auto-mode-alist'.
    (unless (derived-mode-p 'pdf-view-mode)
      (pdf-view-mode))
    (set-buffer-modified-p t)
    (when (get-buffer "*Warnings*")
      (kill-buffer "*Warnings*"))
    ;; Interactively, a modified PDF buffer keeps the server running.
    (pdf-info-quit nil t)
    (should (pdf-info-running-p))
    (with-current-buffer "*Warnings*"
      (goto-char (point-min))
      (should (search-forward (buffer-name (car (pdf-info-unsaved-pdf-buffers)))
                              nil t))
      (let ((pdf-buffer (car (pdf-info-unsaved-pdf-buffers))))
        (funcall (lookup-key (get-text-property (1- (point)) 'keymap)
                             (kbd "RET")))
        (should (eq (window-buffer (selected-window)) pdf-buffer))))
    ;; From Lisp, it quits.
    (pdf-info-quit)
    (should-not (pdf-info-running-p))))

(ert-deftest pdf-info-render-options-per-request ()
  (pdf-test-with-test-pdf
    (let ((plain (pdf-info-renderpage 1 100))
          themed)
      (pdf-info-set-render-options '(:render/usecolors 1
                                     :render/foreground "#ffffff"
                                     :render/background "#000000"))
      (setq themed (pdf-info-renderpage 1 100))
      (should-not (equal plain themed))
      ;; The options came with the request; the server keeps none.
      (should (equal 0 (plist-get (pdf-info-getoptions) :render/usecolors)))
      ;; A new server renders the same image.
      (pdf-info-quit)
      (pdf-info-process-assert-running t)
      (should (equal themed (pdf-info-renderpage 1 100)))
      (pdf-info-set-render-options nil)
      (should (equal plain (pdf-info-renderpage 1 100))))))

(ert-deftest pdf-info-render-options-older-server ()
  (pdf-test-with-test-pdf
    ;; A server older than 1.1.0 keeps the options of the document.
    (cl-letf (((symbol-function 'pdf-info--render-options-per-request-p)
               #'ignore))
      (pdf-info-set-render-options '(:render/usecolors 1))
      (should (equal pdf-info-render-options '(:render/usecolors 1)))
      (should (equal 1 (plist-get (pdf-info-getoptions) :render/usecolors)))
      (should-not (pdf-info--render-option-args nil)))))

(ert-deftest pdf-info-reopen-encrypted-document ()
  (pdf-test-with-encrypted-pdf
    (pdf-info-open nil "pdftool")
    (should (= 6 (pdf-info-number-of-pages)))
    ;; A new server opens the document with the password the buffer keeps.
    (pdf-info-quit)
    (pdf-info-process-assert-running t)
    (should (= 6 (pdf-info-number-of-pages)))
    ;; So does a request after the document was closed.
    (pdf-info-close)
    (should (= 6 (pdf-info-number-of-pages)))
    ;; And an asynchronous request.
    (pdf-info-close)
    (let (answer)
      (let ((pdf-info-asynchronous
             (lambda (status result) (setq answer (list status result)))))
        (pdf-info-number-of-pages))
      (with-timeout (5 (ert-fail "No answer"))
        (while (null answer)
          (accept-process-output (pdf-info-process) 0.05)))
      (should (equal answer '(nil 6))))
    ;; Without a password, the error comes through.
    (pdf-info-close)
    (setq pdf-info-document-passwords nil)
    (should-error (pdf-info-number-of-pages))))

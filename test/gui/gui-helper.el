;;; gui-helper.el --- Shared setup for the checks in test/gui  -*- lexical-binding: t; -*-

;;; Commentary:

;; The checks in this directory need what the ert tests cannot have: a
;; graphical frame, where `image-size' and `image-display-size' work and
;; redisplay really runs, or documents that are built on the fly.  Each
;; check is loaded with `emacs -Q -l', reports its result through
;; `gui-check-finish', and exits.  See README.org.
;;
;; The checks load pdf-tools from this working tree and use the epdfinfo
;; built in server/.  `tablist' is found with `locate-library', or in the
;; directory named by the environment variable PDF_TOOLS_TABLIST_DIR.

;;; Code:

(require 'cl-lib)

(defvar gui-check-root
  (file-name-as-directory
   (expand-file-name "../.." (file-name-directory
                              (or load-file-name buffer-file-name))))
  "The root of the pdf-tools working tree.")

(defvar gui-check-out-dir
  (file-name-as-directory
   (or (getenv "GUI_CHECK_OUT")
       (expand-file-name "pdf-tools-gui-checks" temporary-file-directory)))
  "Where the checks write their reports and build their documents.")

(make-directory gui-check-out-dir t)
(add-to-list 'load-path (expand-file-name "lisp" gui-check-root))
(let ((dir (getenv "PDF_TOOLS_TABLIST_DIR")))
  (when dir (add-to-list 'load-path dir)))
(unless (locate-library "tablist")
  (error "Cannot find tablist: set PDF_TOOLS_TABLIST_DIR to its directory"))

(require 'pdf-tools)
(dolist (feature '(pdf-roll pdf-history pdf-isearch pdf-links pdf-misc
                   pdf-outline pdf-annot pdf-sync pdf-cache pdf-occur))
  (require feature))
(setq pdf-info-epdfinfo-program
      (expand-file-name "server/epdfinfo" gui-check-root))
;; With -Q a PDF opens in DocView, whose converter process signals when
;; `pdf-view-mode' takes the buffer over.
(add-to-list 'auto-mode-alist '("\\.pdf\\'" . pdf-view-mode))
(when (display-graphic-p)
  (set-frame-size (selected-frame) 900 700 t))

(defvar gui-check-lines nil
  "The report of the running check, newest line first.")

(defun gui-check-log (format-string &rest args)
  "Add a line to the report, made from FORMAT-STRING and ARGS."
  (push (apply #'format format-string args) gui-check-lines))

(defun gui-check-finish (name ok)
  "Write the report of the check NAME and exit, with status 0 if OK."
  (let ((file (expand-file-name (concat name ".out") gui-check-out-dir)))
    (with-temp-file file
      (insert (if ok "PASS" "FAIL") " " name "\n"
              (mapconcat #'identity (reverse gui-check-lines) "\n") "\n"
              "=== Messages\n"
              (with-current-buffer (messages-buffer) (buffer-string))))
    (kill-emacs (if ok 0 1))))

(defmacro gui-check (name &rest body)
  "Run BODY as the check NAME and exit.
BODY returns non-nil if the check passed.  An error fails it."
  (declare (indent 1))
  `(let ((ok (condition-case err
                 (progn ,@body)
               (error (gui-check-log "ERROR %S" err) nil))))
     (gui-check-finish ,name ok)))

(defun gui-check-settle ()
  "Redisplay, and wait until no page is waiting for its render."
  (redisplay t)
  (let ((n 0))
    (while (and (< n 500)
                (or pdf-view--render-queue pdf-view--render-in-flight))
      (accept-process-output nil 0.01)
      (cl-incf n)))
  (sit-for 0.05)
  (redisplay t))

(defun gui-check-document (name)
  "Return a PDF built from test/gui/fixtures/NAME.tex with pdflatex.
It is built once, into `gui-check-out-dir'."
  (let ((pdf (expand-file-name (concat name ".pdf") gui-check-out-dir))
        (tex (expand-file-name (concat "test/gui/fixtures/" name ".tex")
                               gui-check-root)))
    (unless (file-exists-p pdf)
      (unless (executable-find "pdflatex")
        (error "pdflatex is needed to build %s" name))
      (let ((default-directory gui-check-out-dir))
        (call-process "pdflatex" nil nil nil
                      "-interaction=batchmode" tex))
      (unless (file-exists-p pdf)
        (error "pdflatex did not build %s" pdf)))
    pdf))

(defun gui-check-copy (file name)
  "Copy FILE to NAME in `gui-check-out-dir' and return the copy.
For checks that change the file they view."
  (let ((copy (expand-file-name name gui-check-out-dir)))
    (copy-file file copy t)
    copy))

(defun gui-check-open (file)
  "Visit FILE in the selected window and return its buffer."
  (switch-to-buffer (find-file-noselect file)))

(defun gui-check-test-pdf ()
  "Return the test document of the ert tests."
  (expand-file-name "test/test.pdf" gui-check-root))

(provide 'gui-helper)
;;; gui-helper.el ends here

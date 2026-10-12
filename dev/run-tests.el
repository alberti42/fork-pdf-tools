;;; run-tests.el --- Run the ert tests without Cask  -*- lexical-binding: t; -*-

;;; Commentary:

;; The Makefile runs the tests through Cask and ert-runner, with
;; pdf-tools installed from a package tar.  This runs them against the
;; working tree instead, which is quicker while working on the code:
;;
;;   emacs -Q -batch -l dev/run-tests.el test/pdf-view-test.el ...
;;
;; It evaluates test/test-helper.el without the part that installs the
;; package and loads undercover.  `tablist' is found with
;; `locate-library', or in the directory named by the environment
;; variable PDF_TOOLS_TABLIST_DIR.  The epdfinfo built in server/ is used.
;; Load dev/no-png.el first to run as on an Emacs without PNG support.

;;; Code:

(require 'ert)
(require 'cl-lib)

(defvar pdf-tools-root
  (file-name-as-directory
   (expand-file-name ".." (file-name-directory load-file-name))))

(add-to-list 'load-path (expand-file-name "lisp" pdf-tools-root))
(add-to-list 'load-path (expand-file-name "test" pdf-tools-root))
(let ((dir (getenv "PDF_TOOLS_TABLIST_DIR")))
  (when dir (add-to-list 'load-path dir)))

;; test-helper.el resolves the test documents relative to the test
;; directory.
(cd (expand-file-name "test" pdf-tools-root))
(with-temp-buffer
  (insert-file-contents (expand-file-name "test/test-helper.el" pdf-tools-root))
  (setq-local lexical-binding t)
  (goto-char (point-min))
  (re-search-forward "^;; FIXME: Move functions")
  (delete-region (point-min) (line-beginning-position))
  (goto-char (point-min))
  (when (re-search-forward "^(require 'undercover)\n(undercover .*\n" nil t)
    (replace-match ""))
  (eval-buffer))
(setq pdf-info-epdfinfo-program
      (expand-file-name "server/epdfinfo" pdf-tools-root))

(dolist (file command-line-args-left)
  (load (expand-file-name file pdf-tools-root) nil t))
(setq command-line-args-left nil)
(ert-run-tests-batch-and-exit)

;;; run-tests.el ends here

;;; no-png.el --- Pretend Emacs has no PNG support  -*- lexical-binding: t; -*-

;;; Commentary:

;; The Emacs builds on CI have no PNG support, so `pdf-view-image-type'
;; signals there.  Load this before dev/run-tests.el to see a test fail
;; as it would on CI:
;;
;;   emacs -Q -batch -l dev/no-png.el -l dev/run-tests.el test/pdf-view-test.el

;;; Code:

(advice-add 'image-type-available-p :override (lambda (&rest _) nil))

;;; no-png.el ends here

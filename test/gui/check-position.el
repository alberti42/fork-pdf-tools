;;; check-position.el --- Registers and bookmarks restore the position  -*- lexical-binding: t; -*-

;;; Commentary:

;; In the continuous and in the single-page view, zooms test.pdf to 2.0,
;; goes to page 3, scrolls 400 pixels down and 20 columns to the right,
;; stores the position in a register (`pdf-view-position-to-register')
;; and a bookmark, moves to page 5 and back to the left, and restores it
;; from each.  Passes if each restores the page, the vscroll and the
;; hscroll stored.  Needs a graphical frame.

;;; Code:

(load (expand-file-name "gui-helper" (file-name-directory load-file-name)) nil t)
(require 'bookmark)

(setq bookmark-save-flag nil
      bookmark-default-file (expand-file-name "bookmarks" gui-check-out-dir))

(defun check-position ()
  "Return the page, the vscroll and the hscroll of the selected window."
  (list (pdf-view-current-page) (window-vscroll nil t) (window-hscroll)))

(defun check-move-away ()
  "Go to page 5 and scroll back to the left."
  (pdf-view-goto-page 5)
  (image-set-window-hscroll 0)
  (gui-check-settle))

(gui-check "check-position"
  (gui-check-open (gui-check-test-pdf))
  (let ((ok t))
    (dolist (single '(nil t))
      (pdf-view-single-page-mode (if single 1 -1))
      (setq-local pdf-view-display-size 2.0)
      (pdf-view-redisplay t)
      (gui-check-settle)
      (pdf-view-goto-page 3)
      (gui-check-settle)
      (pdf-roll-set-vscroll 400 (selected-window))
      (image-set-window-hscroll 20)
      (gui-check-settle)
      (let ((stored (check-position)))
        (pdf-view-position-to-register ?a)
        (bookmark-set "check-position")
        (check-move-away)
        (pdf-view-jump-to-register ?a)
        (gui-check-settle)
        (let ((register (check-position)))
          (check-move-away)
          (bookmark-jump "check-position")
          (gui-check-settle)
          (let ((bookmark (check-position)))
            (gui-check-log "%s: stored %S, register %S, bookmark %S"
                           (if single "single-page view" "continuous view")
                           stored register bookmark)
            (unless (and (equal stored '(3 400 20))
                         (equal register stored)
                         (equal bookmark stored))
              (setq ok nil))))))
    ok))

;;; check-position.el ends here

;;; check-isearch-wrap.el --- Isearch wraps to the same place in both modes  -*- lexical-binding: t; -*-

;;; Commentary:

;; When isearch wraps around the document, `pdf-isearch-wrap-function'
;; shows the top of the first page or the end of the last.  In roll mode
;; the last page may still show a placeholder, which `image-scroll-up'
;; cannot measure.  Passes if wrapping forward and backward leaves the
;; same page and vscroll in roll mode as in plain mode, without an error.
;; Needs a graphical frame.

;;; Code:

(load (expand-file-name "gui-helper" (file-name-directory load-file-name)) nil t)

(defun check-wrap (roll forward from)
  "Wrap isearch FORWARD from page FROM, in roll mode if ROLL.
Return (PAGE VSCROLL), or the error."
  (pdf-view-roll-minor-mode (if roll 1 -1))
  (gui-check-settle)
  (pdf-view-goto-page from)
  (gui-check-settle)
  (condition-case err
      (let ((isearch-forward forward))
        (pdf-isearch-wrap-function)
        (gui-check-settle)
        (list (pdf-view-current-page) (window-vscroll nil t)))
    (error err)))

(gui-check "check-isearch-wrap"
  (gui-check-open (gui-check-test-pdf))
  (let ((ok t))
    (dolist (case '((t 4) (nil 2)))
      (let ((plain (check-wrap nil (car case) (cadr case)))
            (roll (check-wrap t (car case) (cadr case))))
        (gui-check-log "wrapping %s from page %d: plain %S, roll %S"
                       (if (car case) "forward" "backward") (cadr case) plain roll)
        (unless (and (integerp (car-safe plain)) (equal plain roll))
          (setq ok nil))))
    ok))

;;; check-isearch-wrap.el ends here

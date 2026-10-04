;;; check-hscroll.el --- Horizontal scrolling of a page wider than the window  -*- lexical-binding: t; -*-

;;; Commentary:

;; Zooms test.pdf to 2.0, wider than the window, in the continuous and
;; in the single-page view, and presses the horizontal keys through the
;; keymaps.  Passes if C-f moves one column, C-e reaches the right edge
;; of the page to within a column, SPC, DEL and n keep the horizontal
;; position, zooming out to 1.5 brings it within the page's new
;; overflow, and fit-width, where the page fits, brings it back to 0.
;; Needs a graphical frame.

;;; Code:

(load (expand-file-name "gui-helper" (file-name-directory load-file-name)) nil t)

(defun check-overflow ()
  "Return how many pixels the current page overflows the window by."
  (max 0 (- (car (pdf-view-displayed-page-size)) (window-body-width nil t))))

(gui-check "check-hscroll"
  (gui-check-open (gui-check-test-pdf))
  (let ((ok t)
        (column (frame-char-width)))
    (cl-flet ((press (keys)
                (call-interactively (key-binding (kbd keys)))
                (gui-check-settle)
                (window-hscroll))
              (expect (what ok-p)
                (gui-check-log "%-34s hscroll %d columns, %d px; page overflows by %d px: %s"
                               what (window-hscroll) (* (window-hscroll) column)
                               (check-overflow) (if ok-p "ok" "WRONG"))
                (unless ok-p (setq ok nil))))
      (dolist (single '(nil t))
        (pdf-view-single-page-mode (if single 1 -1))
        (gui-check-log "--- %s" (if single "single-page view" "continuous view"))
        (setq-local pdf-view-display-size 2.0)
        (pdf-view-redisplay t)
        (gui-check-settle)
        (expect "zoom 2.0" (= (window-hscroll) 0))
        (expect "C-f" (= (press "C-f") 1))
        (press "C-e")
        (expect "C-e"
                (<= (abs (- (* (window-hscroll) column) (check-overflow))) column))
        (let ((edge (window-hscroll)))
          (press "SPC")
          (expect "SPC" (= (window-hscroll) edge))
          (press "DEL")
          (expect "DEL" (= (window-hscroll) edge))
          (press "n")
          (expect "n" (= (window-hscroll) edge)))
        (setq-local pdf-view-display-size 1.5)
        (pdf-view-redisplay t)
        (gui-check-settle)
        (expect "zoom 1.5"
                (<= (* (window-hscroll) column) (+ (check-overflow) column)))
        (setq-local pdf-view-display-size 'fit-width)
        (pdf-view-redisplay t)
        (gui-check-settle)
        (expect "fit-width" (= (window-hscroll) 0))
        (press "p")))
    ok))

;;; check-hscroll.el ends here

;;; check-mode-line.el --- The size indication draws no page  -*- lexical-binding: t; -*-

;;; Commentary:

;; The mode line is evaluated while Emacs is displaying, where drawing a
;; page means waiting for the server.  With roll mode and
;; `pdf-misc-size-indication-minor-mode' on, changes pages in one window
;; and then in two, redisplaying after each, and passes if the size
;; indication was evaluated and never drew a page.  Needs a graphical
;; frame.

;;; Code:

(load (expand-file-name "gui-helper" (file-name-directory load-file-name)) nil t)

(defvar check-in-indication nil)
(defvar check-evaluations 0)
(defvar check-drawn nil)

(advice-add 'pdf-misc-size-indication :around
            (lambda (f &rest args)
              (cl-incf check-evaluations)
              (let ((check-in-indication t)) (apply f args))))
(advice-add 'pdf-view-create-page :before
            (lambda (page &rest _)
              (when check-in-indication (push page check-drawn))))

(gui-check "check-mode-line"
  (gui-check-open (gui-check-test-pdf))
  (pdf-misc-size-indication-minor-mode 1)
  (gui-check-settle)
  (dolist (page '(4 2 6 1 5 3 6 2))
    (pdf-view-goto-page page)
    (redisplay t))
  (split-window-right)
  (redisplay t)
  (dolist (page '(5 1 6 3))
    (pdf-view-goto-page page)
    (redisplay t)
    (other-window 1)
    (pdf-view-goto-page (- 7 page))
    (redisplay t))
  (gui-check-settle)
  (gui-check-log "size indication evaluated %d times; pages it drew: %S"
                 check-evaluations (reverse check-drawn))
  (and (> check-evaluations 0) (null check-drawn)))

;;; check-mode-line.el ends here

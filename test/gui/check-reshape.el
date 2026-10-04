;;; check-reshape.el --- A page changing size keeps a picture of the right size  -*- lexical-binding: t; -*-

;;; Commentary:

;; In roll mode, after a rotation, a zoom, fitting the width, a slice and
;; its removal, a revert that keeps the page sizes and one that changes
;; them, records each page in view on the first redisplay, before any
;; reply from the server is read, and again once rendered.  Passes if
;; every page that showed an image before the change shows one at the
;; size `pdf-view-displayed-page-size' computes on the first redisplay --
;; reshaped from the old image, or the old image itself -- and every page
;; shows its new image at that size once rendered.  Needs a graphical
;; frame.

;;; Code:

(load (expand-file-name "gui-helper" (file-name-directory load-file-name)) nil t)

(defun check-states (window)
  "Return (PAGE STATE SIZE-OK) for each page WINDOW has drawn."
  (mapcar (lambda (page)
            (let* ((display (overlay-get (pdf-roll-page-overlay page window) 'display))
                   (image (if (eq (car-safe display) 'image) display (assq 'image display)))
                   (size (if (eq (car-safe display) 'space)
                             (cons (car (plist-get (cdr display) :width))
                                   (car (plist-get (cdr display) :height)))
                           (image-display-size display t))))
              (list page
                    (cond ((eq (car-safe display) 'space) 'placeholder)
                          ((not (image-property image :map)) 'reshaped)
                          ((pdf-view-page-stale-p window page) 'stale)
                          (t 'drawn))
                    (equal size (pdf-view-displayed-page-size page window)))))
          (sort (copy-sequence (image-mode-window-get 'displayed-pages window)) #'<)))

(gui-check "check-reshape"
  (let* ((file (gui-check-copy (gui-check-test-pdf) "reshape-me.pdf"))
         (window (progn (gui-check-open file) (selected-window)))
         (ok t))
    (pdf-view-roll-minor-mode 1)
    (gui-check-settle)
    (pdf-roll-scroll-forward 900 window t)
    (gui-check-settle)
    (cl-flet ((step (what change)
                (let ((had-image (mapcar #'car (cl-remove 'placeholder (check-states window)
                                                          :key #'cadr))))
                  (funcall change)
                  (redisplay t)
                  (let ((first (check-states window)))
                    (gui-check-log "%-20s first redisplay: %S" what first)
                    (dolist (state first)
                      (unless (and (nth 2 state)
                                   (or (not (memq (car state) had-image))
                                       (memq (cadr state) '(reshaped stale drawn))))
                        (setq ok nil))))
                  (gui-check-settle)
                  (let ((after (check-states window)))
                    (gui-check-log "%-20s once rendered:   %S" what after)
                    (unless (cl-every (lambda (s) (and (eq (cadr s) 'drawn) (nth 2 s))) after)
                      (setq ok nil))))))
      (step "rotate 90" (lambda () (pdf-view-rotate 90)))
      (step "rotate back" (lambda () (pdf-view-rotate -90)))
      (step "zoom 1.5" (lambda () (setq-local pdf-view-display-size 1.5) (pdf-view-redisplay t)))
      (step "fit width" (lambda () (setq-local pdf-view-display-size 'fit-width) (pdf-view-redisplay t)))
      (step "slice" (lambda () (setf (pdf-view-current-slice window) '(0.1 0.2 0.5 0.6))
                      (pdf-view-redisplay t)))
      (step "unslice" (lambda () (setf (pdf-view-current-slice window) nil) (pdf-view-redisplay t)))
      (step "revert, same size" (lambda () (set-file-times file (time-add (current-time) 2))
                                  (revert-buffer t t)))
      (step "revert, A4 pages" (lambda () (copy-file (gui-check-document "a4-six") file t)
                                 (set-file-times file (time-add (current-time) 4))
                                 (revert-buffer t t))))
    ok))

;;; check-reshape.el ends here

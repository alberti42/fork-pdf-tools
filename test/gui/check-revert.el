;;; check-revert.el --- A revert keeps the pages on screen  -*- lexical-binding: t; -*-

;;; Commentary:

;; Reverts a copy of test.pdf in roll mode through `revert-buffer', the
;; way AUCTeX does after a compilation.  Passes if, on the first
;; redisplay after the revert, every page drawn before still shows its
;; old image, now stale, and none a placeholder; if, once rendered, every
;; page shows a current image and the buffer is unmodified and in step
;; with its file; and if a revert to a document with another number of
;; pages makes the overlays anew.  Needs a graphical frame.

;;; Code:

(load (expand-file-name "gui-helper" (file-name-directory load-file-name)) nil t)

(defun check-states (window)
  "Return (PAGE STATE) for each page WINDOW has drawn."
  (mapcar (lambda (page)
            (let* ((overlay (pdf-roll-page-overlay page window))
                   (display (and overlay (overlay-get overlay 'display))))
              (list page
                    (cond ((null overlay) 'no-overlay)
                          ((eq (car-safe display) 'space) 'placeholder)
                          ((pdf-view-page-stale-p window page) 'stale)
                          (t 'image)))))
          (sort (copy-sequence (image-mode-window-get 'displayed-pages window)) #'<)))

(defun check-all (states state)
  "Return non-nil if STATES is not empty and every page in it is in STATE."
  (and states (cl-every (lambda (s) (eq (cadr s) state)) states)))

(gui-check "check-revert"
  (let* ((file (gui-check-copy (gui-check-test-pdf) "revert-me.pdf"))
         (window (progn (gui-check-open file) (selected-window)))
         (ok t))
    (gui-check-settle)
    (pdf-roll-scroll-forward 900 window t)
    (gui-check-settle)
    (let ((before (check-states window)))
      (gui-check-log "before the revert: %S" before)
      (unless (check-all before 'image) (setq ok nil)))
    (set-file-times file (time-add (current-time) 2))
    (revert-buffer t t)
    (redisplay t)
    (let ((first (check-states window)))
      (gui-check-log "first redisplay after the revert: %S" first)
      (unless (check-all first 'stale) (setq ok nil)))
    (gui-check-settle)
    (let ((after (check-states window)))
      (gui-check-log "once rendered: %S, in step with the file: %S, modified: %S"
                     after (verify-visited-file-modtime) (buffer-modified-p))
      (unless (and (check-all after 'image)
                   (verify-visited-file-modtime)
                   (not (buffer-modified-p)))
        (setq ok nil)))
    (copy-file (gui-check-document "a4-two") file t)
    (set-file-times file (time-add (current-time) 4))
    (revert-buffer t t)
    (gui-check-settle)
    (gui-check-log "after a revert to 2 pages: %d pages, buffer size %d, %S"
                   (pdf-cache-number-of-pages) (buffer-size) (check-states window))
    (unless (and (= (pdf-cache-number-of-pages) 2)
                 ;; Two characters, each with an overlay, for every page
                 ;; and its margin, and a newline after each but the last.
                 (= (buffer-size) (1- (* 4 2))))
      (setq ok nil))
    ok))

;;; check-revert.el ends here

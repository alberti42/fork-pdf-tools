;;; check-scroll-trace.el --- Rendering asynchronously changes no layout  -*- lexical-binding: t; -*-

;;; Commentary:

;; Scrolls test.pdf and an A4 document in roll mode through 42 steps
;; each -- pixel scrolls forward and back, a screen, fit-page, a slice,
;; a rotation and back -- and records after each step, once every page
;; is rendered, the page, the vscroll, the window start, the pages drawn
;; and their sizes.  It does so with `pdf-view-render-asynchronously' nil
;; and then t, and passes if the two traces are identical and
;; `pdf-roll-pre-redisplay' made no synchronous query to the server in
;; the second.  Needs a graphical frame.

;;; Code:

(load (expand-file-name "gui-helper" (file-name-directory load-file-name)) nil t)

(defvar check-in-pre-redisplay nil)
(defvar check-sync-queries 0)

(advice-add 'pdf-roll-pre-redisplay :around
            (lambda (f &rest args)
              (let ((check-in-pre-redisplay t)) (apply f args))))
(advice-add 'pdf-info-query :before
            (lambda (&rest _)
              (when (and check-in-pre-redisplay (not pdf-info-asynchronous))
                (cl-incf check-sync-queries))))

(defun check-trace (asynchronously)
  "Return the trace of the scroll steps, rendering ASYNCHRONOUSLY or not."
  (setq-default pdf-view-render-asynchronously asynchronously)
  (setq check-sync-queries 0)
  (let (trace)
    (dolist (file (list (gui-check-test-pdf) (gui-check-document "a4-two")))
      (let ((buffer (gui-check-open file))
            (window (selected-window))
            (step 0))
        (cl-flet ((record (what)
                    (gui-check-settle)
                    (let ((pages (sort (copy-sequence
                                        (image-mode-window-get 'displayed-pages window))
                                       #'<)))
                      (push (format "%s %d %s page=%S vscroll=%S start=%S pages=%S sizes=%S"
                                    (file-name-nondirectory file) (cl-incf step) what
                                    (pdf-view-current-page window)
                                    (window-vscroll window t) (window-start window) pages
                                    (mapcar (lambda (p)
                                              (let ((d (overlay-get (pdf-roll-page-overlay p window)
                                                                    'display)))
                                                (and (eq (car-safe d) 'image)
                                                     (image-display-size d t))))
                                            pages))
                            trace))))
          (record "start")
          (dotimes (_ 12) (pdf-roll-scroll-forward 250 window t) (record "forward 250"))
          (dotimes (_ 5) (pdf-roll-scroll-backward 400 window t) (record "backward 400"))
          (pdf-roll-scroll-screen-forward 1) (record "screen forward")
          (pdf-view-goto-page 1) (record "page 1")
          (let ((pdf-view-display-size 'fit-page))
            (pdf-view-redisplay t) (record "fit-page")
            (dotimes (_ 6) (pdf-roll-scroll-forward 300 window t) (record "forward 300")))
          (pdf-view-goto-page 1)
          (setf (pdf-view-current-slice window) '(0.1 0.2 0.5 0.6))
          (pdf-view-redisplay t) (record "slice")
          (dotimes (_ 6) (pdf-roll-scroll-forward 300 window t) (record "forward 300"))
          (setf (pdf-view-current-slice window) nil)
          (pdf-view-rotate 90) (record "rotate 90")
          (dotimes (_ 6) (pdf-roll-scroll-forward 300 window t) (record "forward 300"))
          (pdf-view-rotate -90) (record "rotate back"))
        (kill-buffer buffer)))
    (nreverse trace)))

(gui-check "check-scroll-trace"
  (let* ((synchronous (check-trace nil))
         (asynchronous (check-trace t))
         (sync-queries check-sync-queries)
         (identical (equal synchronous asynchronous)))
    (gui-check-log "%d steps; traces %s; synchronous queries in pdf-roll-pre-redisplay while rendering asynchronously: %d"
                   (length synchronous) (if identical "identical" "DIFFER") sync-queries)
    (unless identical
      (cl-mapc (lambda (s a)
                 (unless (equal s a)
                   (gui-check-log "synchronous:  %s" s)
                   (gui-check-log "asynchronous: %s" a)))
               synchronous asynchronous))
    (and identical (= sync-queries 0))))

;;; check-scroll-trace.el ends here

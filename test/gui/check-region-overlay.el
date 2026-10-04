;;; check-region-overlay.el --- No page lands on the region's overlay  -*- lexical-binding: t; -*-

;;; Commentary:

;; Upstream issue #345.  Redisplay highlights the region with an overlay
;; that carries a `window' property, as the page overlays of pdf-roll do;
;; when pdf-roll looked its overlays up by that property alone, it drew
;; pages onto the region's overlay, and Emacs moved that overlay on to
;; the next region, in whatever buffer.  With `global-hl-line-mode' on, a
;; selection drawn, and Emacs's region active from page 2 to page 3,
;; scrolls test.pdf with the mouse wheel.  Passes if no overlay other
;; than pdf-roll's own ever holds an image, in this buffer or in another
;; whose region the same window then shows, and every page drawn shows
;; its image.  On upstream master, before the fix of #361, the region's
;; overlay held page 2 after eight scrolls.  Needs a graphical frame.

;;; Code:

(load (expand-file-name "gui-helper" (file-name-directory load-file-name)) nil t)

(defun check-foreign-image-overlays ()
  "Return the overlays, in any buffer, that hold an image but are not pdf-roll's."
  (let (found)
    (dolist (buffer (buffer-list))
      (with-current-buffer buffer
        (dolist (overlay (overlays-in (point-min) (point-max)))
          (let ((display (overlay-get overlay 'display)))
            (when (and (or (eq (car-safe display) 'image)
                           (and (consp display) (assq 'image display)))
                       (not (memq (overlay-get overlay 'category)
                                  '(pdf-roll pdf-roll-margin))))
              (push (list (buffer-name) (overlay-start overlay)
                          (overlay-get overlay 'face))
                    found))))))
    found))

(defun check-pages-drawn (window)
  "Return non-nil if every page WINDOW has drawn shows an image."
  (cl-every (lambda (page)
              (let ((display (overlay-get (pdf-roll-page-overlay page window) 'display)))
                (or (eq (car-safe display) 'image) (assq 'image display))))
            (image-mode-window-get 'displayed-pages window)))

(gui-check "check-region-overlay"
  (global-hl-line-mode 1)
  (let* ((buffer (gui-check-open (gui-check-test-pdf)))
         (window (selected-window))
         (ok t))
    (gui-check-settle)
    (setq pdf-view-active-region (list 1 '(0.1 0.1 0.5 0.3)))
    (pdf-view-display-region)
    (goto-char (pdf-roll-page-to-pos 2))
    (set-mark (point))
    (goto-char (pdf-roll-page-to-pos 3))
    (activate-mark)
    (gui-check-settle)
    (dotimes (i 30)
      (funcall mwheel-scroll-up-function 5)
      (gui-check-settle)
      (unless (and (null (check-foreign-image-overlays)) (check-pages-drawn window))
        (setq ok nil)
        (gui-check-log "after scroll %d: foreign overlays %S, pages drawn %S"
                       (1+ i) (check-foreign-image-overlays) (check-pages-drawn window))))
    (switch-to-buffer (get-buffer-create "*other*"))
    (insert "some text\nmore text\n")
    (set-mark 1)
    (goto-char 10)
    (activate-mark)
    (gui-check-settle)
    (when (check-foreign-image-overlays)
      (setq ok nil)
      (gui-check-log "in another buffer: %S" (check-foreign-image-overlays)))
    (switch-to-buffer buffer)
    (gui-check-settle)
    (dotimes (_ 10)
      (funcall mwheel-scroll-down-function 5)
      (gui-check-settle))
    (gui-check-log "30 scrolls down, 10 up: foreign overlays %S, pages drawn %S"
                   (check-foreign-image-overlays) (check-pages-drawn window))
    (and ok (null (check-foreign-image-overlays)) (check-pages-drawn window))))

;;; check-region-overlay.el ends here

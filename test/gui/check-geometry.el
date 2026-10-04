;;; check-geometry.el --- The computed size of a page is the size shown  -*- lexical-binding: t; -*-

;;; Commentary:

;; `pdf-view-displayed-page-size' computes the size at which a window
;; shows a page, before the page is drawn; placeholders and the layout of
;; roll mode rely on it.  This draws two pages each of test.pdf and of an
;; A4 document under every combination of slice, rotation, width cap,
;; display size, relief and image cache state, and compares the computed
;; size with what `image-display-size' measures on the image roll mode
;; shows.  Needs a graphical frame.

;;; Code:

(load (expand-file-name "gui-helper" (file-name-directory load-file-name)) nil t)

(gui-check "check-geometry"
  (let ((total 0) (differ 0))
    (dolist (file (list (gui-check-test-pdf) (gui-check-document "a4-two")))
      (gui-check-open file)
      (redisplay t)
      (dolist (clear '(t nil))
        (dolist (page '(1 2))
          (dolist (slice '(nil (0.1 0.2 0.5 0.6) (0.05 0.07 0.83 0.77)))
            (dolist (rotation '(0 90 180 270))
              (dolist (cap '(nil 300 777))
                (dolist (display-size '(fit-width fit-page fit-height 1.5 0.73))
                  (dolist (relief '(0 3))
                    (let ((pdf-view-max-image-width cap)
                          (pdf-view-display-size display-size)
                          (pdf-view-image-relief relief)
                          (pdf-view--current-rotation rotation)
                          (window (selected-window)))
                      (setf (pdf-view-current-slice window) slice)
                      (when clear (pdf-cache-clear-images))
                      (let ((shown (image-display-size
                                    (pdf-roll-maybe-slice-image
                                     (pdf-view-create-page page window) window)
                                    t))
                            (computed (pdf-view-displayed-page-size page window)))
                        (cl-incf total)
                        (unless (equal shown computed)
                          (cl-incf differ)
                          (gui-check-log
                           "%s page %d clear=%S slice=%S rotation=%d cap=%S size=%S relief=%d: shown %S, computed %S"
                           (file-name-nondirectory file) page clear slice rotation
                           cap display-size relief shown computed)))))))))))
      (setf (pdf-view-current-slice (selected-window)) nil))
    (gui-check-log "%d combinations, %d differ" total differ)
    (= differ 0)))

;;; check-geometry.el ends here

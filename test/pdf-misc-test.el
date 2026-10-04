;; -*- lexical-binding: t -*-

(require 'pdf-misc)

(ert-deftest pdf-misc-size-indication-draws-no-page ()
  "The mode-line construct may not draw a page: it runs during redisplay.

`pdf-view-image-size' draws the page when the window has not drawn it,
and a draw waits for the server."
  (pdf-test-with-test-pdf
    (let (drawn queried)
      (cl-letf (((symbol-function 'image-mode-window-get)
                 (lambda (prop &optional _w) (when (eq prop 'page) 1)))
                ;; Gone, as it is while the overlays a revert collapsed are
                ;; being rebuilt.
                ((symbol-function 'pdf-roll-page-overlay) (lambda (&rest _) nil))
                ((symbol-function 'pdf-view-display-page)
                 (lambda (&rest _) (setq drawn t)))
                ((symbol-function 'pdf-info-query)
                 (lambda (cmd &rest _) (setq queried cmd))))
        (should (equal "" (pdf-misc-size-indication)))
        (should-not drawn)
        (should-not queried)))))

(ert-deftest pdf-misc-size-indication-measures-a-drawn-page ()
  "A page the window already shows is measured, and nothing is drawn."
  (pdf-test-with-test-pdf
    (let ((overlay (make-overlay 1 1))
          drawn)
      (overlay-put overlay 'display '(image :type png :width 10 :height 400))
      (cl-letf (((symbol-function 'pdf-view-display-page)
                 (lambda (&rest _) (setq drawn t)))
                ((symbol-function 'image-mode-window-get)
                 (lambda (prop &optional _w) (when (eq prop 'page) 1)))
                ((symbol-function 'pdf-roll-page-overlay) (lambda (&rest _) overlay))
                ((symbol-function 'image-display-size) (lambda (&rest _) '(10 . 400))))
        (should (pdf-view-page-displayed-p))
        (should-not (equal "" (pdf-misc-size-indication)))
        (should-not drawn)))))

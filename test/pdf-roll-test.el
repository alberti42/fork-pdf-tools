;; -*- lexical-binding: t -*-

(require 'pdf-roll)
(require 'ert)

;; Tests for pdf-roll.el - continuous scroll functionality.
;; Many pdf-roll functions require window context, so these tests focus on
;; utility functions and basic mode setup that can be tested in batch mode.

;;; Utility function tests

(ert-deftest pdf-roll-page-to-pos-basic ()
  "Test pdf-roll-page-to-pos returns correct buffer positions."
  ;; Page 1 should be at position 1
  (should (= (pdf-roll-page-to-pos 1) 1))
  ;; Page 2 should be at position 5
  (should (= (pdf-roll-page-to-pos 2) 5))
  ;; Page 3 should be at position 9
  (should (= (pdf-roll-page-to-pos 3) 9))
  ;; Page 10 should be at position 37
  (should (= (pdf-roll-page-to-pos 10) 37)))

(ert-deftest pdf-roll-page-at-current-pos-basic ()
  "Test pdf-roll-page-at-current-pos returns correct page numbers."
  (with-temp-buffer
    ;; Position 1 (page 1)
    (goto-char 1)
    (insert " ")  ; Need content at position
    (goto-char 1)
    (should (= (pdf-roll-page-at-current-pos) 1)))
  (with-temp-buffer
    ;; Position 5 (page 2)
    (insert "    X")  ; 5 chars, point at 5 is page 2
    (goto-char 5)
    (should (= (pdf-roll-page-at-current-pos) 2)))
  (with-temp-buffer
    ;; Position 9 (page 3)
    (insert "        X")  ; 9 chars
    (goto-char 9)
    (should (= (pdf-roll-page-at-current-pos) 3))))

(ert-deftest pdf-roll-page-at-current-pos-error-on-even ()
  "Test pdf-roll-page-at-current-pos errors on even positions."
  (with-temp-buffer
    (insert "  ")
    (goto-char 2)
    (should-error (pdf-roll-page-at-current-pos))))

;;; Customization tests

(ert-deftest pdf-roll-vertical-margin-default ()
  "Test pdf-roll-vertical-margin has correct default value."
  (should (= pdf-roll-vertical-margin 2)))

(ert-deftest pdf-roll-margin-color-default ()
  "Test pdf-roll-margin-color has correct default value."
  (should (equal pdf-roll-margin-color "gray")))

;;; Symbol property tests

(ert-deftest pdf-roll-symbol-properties ()
  "Test that pdf-roll symbol has correct properties set."
  ;; Display property for placeholder
  (should (equal (get 'pdf-roll 'display) '(space :width 25 :height 1000)))
  ;; Evaporate property
  (should (get 'pdf-roll 'evaporate))
  (should (get 'pdf-roll-margin 'evaporate)))

;;; Face tests

(ert-deftest pdf-roll-default-face-exists ()
  "Test that pdf-roll-default face is defined."
  (should (facep 'pdf-roll-default)))

;;; Minor mode keymap tests

(ert-deftest pdf-roll-minor-mode-keymap-exists ()
  "Test that pdf-view-roll-minor-mode-map is defined with remappings."
  (should (keymapp pdf-view-roll-minor-mode-map))
  ;; Check that scroll commands are remapped
  (should (lookup-key pdf-view-roll-minor-mode-map
                      [remap pdf-view-previous-line-or-previous-page]))
  (should (lookup-key pdf-view-roll-minor-mode-map
                      [remap pdf-view-next-line-or-next-page])))

;;; Redisplay tests

(ert-deftest pdf-roll-pre-redisplay-moves-point-to-the-page ()
  "Test that point is put back on the page when nothing else changed.
A window configuration restored after a revert brings point back at 1,
and redisplay would then scroll the window to page 1."
  (let ((pdf (generate-new-buffer "pdf")))
    (unwind-protect
        (save-window-excursion
          (delete-other-windows)
          (let ((win (selected-window)))
            (set-window-buffer win pdf)
            (with-current-buffer pdf
              (insert " \n \n \n ")
              (dotimes (i 4)
                (let ((ov (make-overlay (1+ (* 2 i)) (+ 2 (* 2 i)))))
                  (overlay-put ov 'category (if (cl-evenp i) 'pdf-roll 'pdf-roll-margin))
                  (overlay-put ov 'window win)))
              (setq-local image-mode-winprops-alist nil)
              (image-mode-window-put 'page 2 win)
              (image-mode-window-put 'vscroll 0 win)
              (setq-local pdf-roll--state
                          (list (list win 2 (window-pixel-height win)
                                      (window-pixel-width win) 0 nil)))
              (set-window-point win 1)
              (pdf-roll-pre-redisplay win)
              (should (= (window-point win) (pdf-roll-page-to-pos 2))))))
      (kill-buffer pdf))))

;;; Provide

(provide 'pdf-roll-test)

;;; pdf-roll-test.el ends here

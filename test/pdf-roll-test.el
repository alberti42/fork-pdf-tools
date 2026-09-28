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

(ert-deftest pdf-roll-redisplay-t-reaches-every-window ()
  "Test that WINDOW t redisplays every window showing the buffer.
The selected window shows another buffer."
  (let ((pdf (generate-new-buffer "pdf"))
        (other (generate-new-buffer "other")))
    (unwind-protect
        (save-window-excursion
          (delete-other-windows)
          ;; The batch frame of Emacs 26 and 27 is too short for three
          ;; windows of the default minimum height.
          (let* ((window-min-height 1)
                 (win-a (selected-window))
                 (win-b (split-window win-a))
                 (win-c (split-window win-b)))
            (set-window-buffer win-a pdf)
            (set-window-buffer win-b pdf)
            (set-window-buffer win-c other)
            (select-window win-c)
            (with-current-buffer pdf
              (insert "    ")
              (setq-local pdf-roll--state
                          (list t (list win-a 'state) (list win-b 'state)))
              (dolist (win (list win-a win-b))
                (let ((ov (make-overlay 1 2)))
                  (overlay-put ov 'category 'pdf-roll)
                  (overlay-put ov 'window win)))
              (pdf-roll-redisplay t)
              (should-not (alist-get win-a pdf-roll--state))
              (should-not (alist-get win-b pdf-roll--state)))))
      (kill-buffer pdf)
      (kill-buffer other))))

;;; Provide

(provide 'pdf-roll-test)

;;; pdf-roll-test.el ends here

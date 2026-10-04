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

;;; Key bindings

(ert-deftest pdf-roll-space-scrolls-a-screen ()
  "SPC, S-SPC and DEL scroll a screen, C-n a line."
  (with-temp-buffer
    (use-local-map pdf-view-mode-map)
    (should (eq 'pdf-roll-scroll-screen-forward (key-binding (kbd "SPC"))))
    (should (eq 'pdf-roll-scroll-screen-backward (key-binding (kbd "S-SPC"))))
    (should (eq 'pdf-roll-scroll-screen-backward (key-binding (kbd "DEL"))))
    (should (eq 'pdf-roll-scroll-forward (key-binding (kbd "C-n"))))
    (should (eq 'undefined (key-binding (kbd "RET"))))))

(ert-deftest pdf-roll-obsolete-mode-only-warns ()
  "`pdf-view-roll-minor-mode' warns once per session and does nothing else."
  (let ((pdf-roll--obsolete-mode-warned nil)
        warnings)
    (cl-letf (((symbol-function 'display-warning)
               (lambda (&rest args) (push args warnings))))
      (with-temp-buffer
        (let ((text (buffer-string)))
          (pdf-view-roll-minor-mode 1)
          (pdf-view-roll-minor-mode -1)
          (should (equal text (buffer-string)))))
      (should (equal 1 (length warnings)))
      (should (eq 'pdf-tools (car (car warnings)))))))

;;; Overlay lookup tests

(defun pdf-roll-test--fake-region-overlay (start end window)
  "Return an overlay imitating Emacs's region highlight over START..END.
`redisplay--highlight-overlay-function' tags it with WINDOW and the
`region' face, and gives it no `category'."
  (let ((ov (make-overlay start end)))
    (overlay-put ov 'window window)
    (overlay-put ov 'face 'region)
    (overlay-put ov 'priority '(nil . 100))
    ov))

(ert-deftest pdf-roll-pos-overlay-skips-region-overlay ()
  "Test that a region overlay at a page position is not taken for a page.
Emacs's region highlight carries the same `window' property as a page
overlay.  Both creation orders are checked, since `overlays-at' makes no
promise about the order it returns overlays in."
  (dolist (region-first '(t nil))
    (with-temp-buffer
      (insert " \n \n")
      (let* ((window (selected-window))
             (region (and region-first
                          (pdf-roll-test--fake-region-overlay 1 2 window)))
             (page (make-overlay 1 2)))
        (overlay-put page 'window window)
        (overlay-put page 'category 'pdf-roll)
        (unless region-first
          (setq region (pdf-roll-test--fake-region-overlay 1 2 window)))
        (should (overlayp region))
        (should (eq (pdf-roll--pos-overlay 1 window 'pdf-roll) page))
        (should (eq (pdf-roll-page-overlay 1 window) page))))))

(ert-deftest pdf-roll-pos-overlay-nil-without-own-overlay ()
  "Test that an overlay without a `pdf-roll' category is never returned."
  (with-temp-buffer
    (insert " \n \n")
    (let ((window (selected-window)))
      (pdf-roll-test--fake-region-overlay 1 2 window)
      (should-not (pdf-roll--pos-overlay 1 window 'pdf-roll)))))

(ert-deftest pdf-roll-pos-overlay-finds-margin-overlay ()
  "Test that a margin overlay is found under its own category."
  (with-temp-buffer
    (insert " \n \n")
    (let ((window (selected-window))
          (margin (make-overlay 3 4)))
      (overlay-put margin 'window window)
      (overlay-put margin 'category 'pdf-roll-margin)
      (should (eq (pdf-roll--pos-overlay 3 window 'pdf-roll-margin) margin)))))

(ert-deftest pdf-roll-own-overlay-p-basic ()
  "Test `pdf-roll--own-overlay-p' against both categories and a foreign overlay."
  (with-temp-buffer
    (insert "  ")
    (let ((page (make-overlay 1 2))
          (margin (make-overlay 1 2))
          (foreign (make-overlay 1 2)))
      (overlay-put page 'category 'pdf-roll)
      (overlay-put margin 'category 'pdf-roll-margin)
      (should (pdf-roll--own-overlay-p page))
      (should (pdf-roll--own-overlay-p margin))
      (should-not (pdf-roll--own-overlay-p foreign)))))


(defun pdf-roll-test--page-overlay (page window)
  "Return a new page overlay for PAGE in WINDOW in the current buffer."
  (let* ((pos (pdf-roll-page-to-pos page))
         (ov (make-overlay pos (1+ pos))))
    (overlay-put ov 'category 'pdf-roll)
    (overlay-put ov 'window window)
    ov))

(ert-deftest pdf-roll-undisplay-pages-skips-missing-overlay ()
  "Test that undisplaying a page without an overlay is a no-op.
The `displayed-pages' a window remembers outlive its overlays, which
`pdf-roll-initialize' recreates whenever the buffer is reverted, so the
list can name a page the buffer no longer holds an overlay for -- one
inside the buffer as well as one past its end."
  (with-temp-buffer
    (insert " \n \n \n ")                 ; two pages
    (let* ((window (selected-window))
           (first (pdf-roll-test--page-overlay 1 window)))
      (should-not (pdf-roll-page-overlay 2 window))
      (should-not (pdf-roll-page-overlay 3 window))
      (pdf-roll-undisplay-pages '(1 2 3) window)
      (should (equal (overlay-get first 'display) (get 'pdf-roll 'display))))))

(ert-deftest pdf-roll-initialize-postpones-during-a-render ()
  "Test that a revert arriving during a render leaves the buffer alone.
`pdf-roll-initialize' is what a revert runs.  While `pdf-roll--delay-revert'
is set a page render is waiting on the server, and erasing the buffer would
take away the overlay that render is about to write to, so the work has to
be queued instead."
  (with-temp-buffer
    (insert " \n \n")
    (let ((overlay (make-overlay 1 2))
          (timers (length timer-list))
          (queued nil))
      (unwind-protect
          (let ((pdf-roll--delay-revert t))
            (pdf-roll-initialize)
            (setq queued (- (length timer-list) timers))
            ;; The buffer is untouched.
            (should (= (point-max) 5))
            (should (overlay-buffer overlay))
            ;; And the work was put on a timer.
            (should (= queued 1)))
        (dotimes (_ queued) (cancel-timer (car (last timer-list))))))))


(ert-deftest pdf-roll-window-start-follows-current-page ()
  "Test that `pdf-roll-window-start' reports the page, not `window-start'.
`pdf-roll-scroll-forward' and `pdf-roll-scroll-backward' record where they
arrive in `pdf-view-current-page' and leave `window-start' to
`pdf-roll-pre-redisplay', which runs once per redisplay.  A command that
scrolls more than once therefore has to ask for the page, or its second
scroll starts from the page the first one left."
  (with-temp-buffer
    (insert " \n \n \n \n \n \n \n ")        ; four pages
    ;; What `image-mode-setup-winprops' does; `image-mode-window-put' needs
    ;; the alist to be a list rather than the not-an-image-buffer sentinel.
    (setq-local image-mode-winprops-alist nil)
    (let ((window (selected-window)))
      (setf (pdf-view-current-page window) 1)
      (should (= (pdf-roll-window-start window) 1))
      (setf (pdf-view-current-page window) 3)
      (should (= (pdf-roll-window-start window) 9))
      ;; `window-start' still names page one here, which is exactly the
      ;; disagreement the scroll commands used to read.
      (should (= (window-start window) 1)))))


(ert-deftest pdf-roll-forget-displayed-pages-covers-every-window ()
  "Test that every window on the buffer forgets its displayed pages.
`image-mode-window-put' with no window argument reaches the selected window
only, so a second window on the same buffer kept a `displayed-pages' list
naming pages the buffer no longer holds an overlay for."
  (with-temp-buffer
    (setq-local image-mode-winprops-alist
                (list (cons t (list (cons 'displayed-pages '(1 2))))
                      (cons 'window-a (list (cons 'displayed-pages '(3 4))))
                      (cons 'window-b (list (cons 'displayed-pages '(5 6))))))
    (pdf-roll--forget-displayed-pages)
    (dolist (winprops image-mode-winprops-alist)
      (should-not (cdr (assq 'displayed-pages (cdr winprops)))))))


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

(ert-deftest pdf-roll-display-page-height-does-not-come-from-the-image ()
  "The height a page takes is computed, not measured on its image.

The image functions are replaced before the buffer is shown, because
showing it draws the first page, and an image cannot be measured in
batch."
  (pdf-test-with-test-pdf
    (let ((window (selected-window))
          ;; The page is drawn while waiting.
          (pdf-view-render-asynchronously nil)
          drawn)
      (cl-letf (((symbol-function 'pdf-view-displayed-page-size)
                 (lambda (&rest _) '(500 . 700)))
                ((symbol-function 'pdf-view-create-page)
                 (lambda (&rest _) (setq drawn t) '(image :type png)))
                ((symbol-function 'image-display-size)
                 (lambda (&rest _) '(10 . 20)))
                ((symbol-function 'image-size)
                 (lambda (&rest _) '(10 . 20))))
        (set-window-buffer window (current-buffer))
        (pdf-view-mode)
        (pdf-roll-new-window-function window)
        (setq drawn nil)
        (should (equal 700 (pdf-roll-display-page 1 window)))
        (should drawn)
        (setq drawn nil)
        ;; Already displayed: nothing is drawn, the height is the same.
        (should (equal 700 (pdf-roll-display-page 1 window)))
        (should-not drawn)))))

(defmacro pdf-roll-test-with-async-render (&rest body)
  "Run BODY in test.pdf with pages rendered asynchronously.
`requests' is the list of (PAGE . CALLBACK) sent to the server, newest
first, and `drawn' the pages drawn.  The server answers when BODY calls
a CALLBACK.  Timers run at once.  Images and pages measure 10x20."
  (declare (indent 0) (debug t))
  `(pdf-test-with-test-pdf
     (let ((window (selected-window))
           (pdf-view-render-asynchronously t)
           requests drawn)
       (cl-letf (((symbol-function 'pdf-info-renderpage)
                  (lambda (page _width &rest _)
                    (push (cons page pdf-info-asynchronous) requests)))
                 ((symbol-function 'pdf-view-create-page)
                  (lambda (page &rest _)
                    (push page drawn)
                    '(image :type png :data "old png" :map (hotspots))))
                 ((symbol-function 'image-display-size)
                  (lambda (&rest _) '(10 . 20)))
                 ((symbol-function 'image-size)
                  (lambda (&rest _) '(10 . 20)))
                 ((symbol-function 'pdf-view-displayed-page-size)
                  (lambda (&rest _) '(10 . 20)))
                 ;; Emacs on CI has no PNG support.
                 ((symbol-function 'pdf-view-image-type) (lambda () 'png))
                 ((symbol-function 'create-image)
                  (lambda (data type _data-p &rest props)
                    `(image :type ,type :data ,data ,@props)))
                 ((symbol-function 'run-at-time)
                  (lambda (_time _repeat fn &rest args) (apply fn args))))
         (set-window-buffer window (current-buffer))
         (pdf-view-mode)
         (pdf-roll-new-window-function window)
         (pdf-cache-clear-images)
         (setq drawn nil)
         ,@body))))

(ert-deftest pdf-roll-async-render-draws-a-placeholder-then-the-page ()
  "Displaying a page asks for it once and draws it when the reply comes."
  (pdf-roll-test-with-async-render
    (let ((size (pdf-view-displayed-page-size 2 window)))
      (should (equal (cdr size) (pdf-roll-display-page 2 window)))
      (should (equal `(space :width (,(car size)) :height (,(cdr size)))
                     (overlay-get (pdf-roll-page-overlay 2 window) 'display)))
      (should (equal '(2) (mapcar #'car requests)))
      (should-not drawn)
      ;; A second redisplay before the reply asks nothing more.
      (pdf-roll-display-page 2 window)
      (should (equal '(2) (mapcar #'car requests)))
      (funcall (cdar requests) nil "png data")
      (should (equal '(2) drawn))
      (should (pdf-view-page-displayed-p window 2)))))

(ert-deftest pdf-roll-async-render-drops-a-reply-from-before-a-revert ()
  "A reply for a document closed since is not drawn, nor cached."
  (pdf-roll-test-with-async-render
    (pdf-roll-display-page 2 window)
    (run-hooks 'pdf-info-close-document-hook)
    (funcall (cdar requests) nil "png data")
    (should-not drawn)
    (should-not (pdf-cache-lookup-image 2 1))))

(ert-deftest pdf-roll-async-render-sends-one-at-a-time ()
  "A page undisplayed before its request is sent is never asked for."
  (pdf-roll-test-with-async-render
    (pdf-roll-display-page 2 window)
    (pdf-roll-display-page 3 window)
    (pdf-roll-display-page 4 window)
    (should (equal '(2) (mapcar #'car requests)))
    (pdf-roll-undisplay-pages '(3) window)
    (funcall (cdar requests) nil "png data")
    (should (equal '(4 2) (mapcar #'car requests)))
    (funcall (cdar requests) nil "png data")
    (should (equal '(4 2) drawn))))

(ert-deftest pdf-roll-revert-keeps-the-pages-until-drawn-anew ()
  "A revert leaves the buffer text, the overlays and the images alone.
The pages are stale until their new renders arrive."
  (pdf-roll-test-with-async-render
    (pdf-roll-display-page 2 window)
    (funcall (cdar requests) nil "png data")
    (let ((text (buffer-string))
          (overlay (pdf-roll-page-overlay 2 window))
          (image (overlay-get (pdf-roll-page-overlay 2 window) 'display)))
      (pdf-view-revert-buffer nil t)
      (should (equal text (buffer-string)))
      (should (eq overlay (pdf-roll-page-overlay 2 window)))
      (should (eq image (overlay-get overlay 'display)))
      (should (pdf-view-page-stale-p window 2))
      ;; The redisplay after the revert asks for the page again and keeps
      ;; showing the old one meanwhile.
      (setq requests nil drawn nil)
      (pdf-roll-display-page 2 window t)
      (should (eq image (overlay-get overlay 'display)))
      (should (equal '(2) (mapcar #'car requests)))
      (funcall (cdar requests) nil "png data")
      (should (equal '(2) drawn))
      (should-not (pdf-view-page-stale-p window 2)))))

(ert-deftest pdf-roll-revert-rebuilds-the-overlays-if-the-pages-changed ()
  "A revert to a document with another number of pages starts afresh."
  (pdf-roll-test-with-async-render
    (let ((overlay (pdf-roll-page-overlay 1 window)))
      (cl-letf (((symbol-function 'pdf-cache-number-of-pages) (lambda () 7))
                ((symbol-function 'pdf-cache-read-pagesizes) #'ignore))
        (pdf-view-revert-buffer nil t)
        (should (equal (1- (* 4 7)) (buffer-size)))
        (should-not (eq overlay (pdf-roll-page-overlay 1 window)))))))

(ert-deftest pdf-roll-async-render-reshapes-an-image-of-another-size ()
  "A page whose image no longer has its size shows it reshaped meanwhile.
An image of another size would move the window off the layout."
  (pdf-roll-test-with-async-render
    (pdf-roll-display-page 2 window)
    (funcall (cdar requests) nil "png data")
    ;; Otherwise the page is drawn again at once, from the cache.
    (pdf-cache-clear-images)
    (let ((pdf-view--current-rotation 90)
          (size (pdf-view-desired-image-size 2 window)))
      (cl-letf (((symbol-function 'pdf-view-displayed-page-size)
                 (lambda (&rest _) '(20 . 10))))
        (pdf-roll-display-page 2 window t)
        (let ((image (overlay-get (pdf-roll-page-overlay 2 window) 'display)))
          (should (equal "old png" (image-property image :data)))
          (should (equal (car size) (image-property image :width)))
          (should (equal (cdr size) (image-property image :height)))
          (should (equal 90 (image-property image :rotation)))
          (should-not (image-property image :map)))
        ;; It is still drawn anew.
        (should (equal '(2 2) (mapcar #'car requests)))))))

(ert-deftest pdf-roll-isearch-wraps-backward-to-the-end-of-the-last-page ()
  "Wrapping backward shows the end of the last page, placeholder or not."
  (require 'pdf-isearch)
  (pdf-roll-test-with-async-render
    (cl-letf (((symbol-function 'pdf-view-displayed-page-size)
               (lambda (&rest _) '(10 . 5000))))
      (pdf-view-goto-page 2 window)
      (let ((isearch-forward nil))
        (pdf-isearch-wrap-function))
      (should (equal 6 (pdf-view-current-page window)))
      (should (equal (- 5000 (window-text-height window t))
                     (image-mode-window-get 'vscroll window))))))

(defmacro pdf-roll-test-with-single-page (&rest body)
  "Run BODY in test.pdf in `pdf-view-single-page-mode', pages 1000 pixels high."
  (declare (indent 0) (debug t))
  `(pdf-roll-test-with-async-render
     (cl-letf (((symbol-function 'pdf-view-displayed-page-size)
                (lambda (&rest _) '(10 . 1000))))
       (setq-local pdf-view-single-page-mode t)
       (pdf-view-goto-page 2 window)
       ,@body)))

(defun pdf-roll-test-bottom (window)
  "The vscroll of WINDOW with the bottom of a 1000 pixel page in view."
  (- 1000 (window-text-height window t)))

(ert-deftest pdf-view-single-page-hides-the-other-pages ()
  "Only the current page of the window is visible."
  (pdf-roll-test-with-single-page
    (pdf-roll-pre-redisplay window)
    (let ((pos (pdf-roll-page-to-pos 2)))
      (should (invisible-p (1- pos)))
      (should-not (invisible-p pos))
      (should (invisible-p (1+ pos)))
      (should (equal '(2) (image-mode-window-get 'displayed-pages window))))))

(ert-deftest pdf-view-single-page-line-scrolling-turns-at-the-bottom ()
  "C-n scrolls within the page, and at its bottom turns the page."
  (pdf-roll-test-with-single-page
    (let ((pdf-view-turn-page-at-top-and-bottom t))
      (pdf-view-single-page--scroll 5000 pdf-view-turn-page-at-top-and-bottom)
      (should (equal 2 (pdf-view-current-page window)))
      (should (equal (pdf-roll-test-bottom window) (image-mode-window-get 'vscroll window)))
      (pdf-view-single-page-next-line)
      (should (equal 3 (pdf-view-current-page window)))
      (should (equal 0 (image-mode-window-get 'vscroll window))))))

(ert-deftest pdf-view-single-page-line-scrolling-stops-at-the-bottom ()
  "With `pdf-view-turn-page-at-top-and-bottom' nil, C-n stops at the bottom."
  (pdf-roll-test-with-single-page
    (let ((pdf-view-turn-page-at-top-and-bottom nil))
      (dotimes (_ 3) (pdf-view-single-page-next-line 2000))
      (should (equal 2 (pdf-view-current-page window)))
      (should (equal (pdf-roll-test-bottom window) (image-mode-window-get 'vscroll window)))
      ;; SPC still turns the page.
      (pdf-view-single-page-scroll-up)
      (should (equal 3 (pdf-view-current-page window))))))

(ert-deftest pdf-view-single-page-scrolling-up-turns-to-the-bottom ()
  "At the top of the page, DEL shows the previous page from its bottom."
  (pdf-roll-test-with-single-page
    (pdf-view-single-page-scroll-down)
    (should (equal 1 (pdf-view-current-page window)))
    (should (equal (pdf-roll-test-bottom window) (image-mode-window-get 'vscroll window)))))

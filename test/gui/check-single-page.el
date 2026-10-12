;;; check-single-page.el --- The single-page view behaves as plain mode  -*- lexical-binding: t; -*-

;;; Commentary:

;; Presses keys in `pdf-view-single-page-mode' on test.pdf -- SPC,
;; DEL, C-n, C-p, the mouse wheel, n, p, M->, M-<, at fit-width and at
;; fit-page, and line scrolling with
;; `pdf-view-turn-page-at-top-and-bottom' nil -- looking each key up
;; through the keymaps, and records the page and the vscroll after each.
;; Passes if every step gives what plain `pdf-view-mode' gave, as
;; recorded in fixtures/plain-mode.eld before plain mode was removed,
;; except C-n and C-p at fit-page: there plain mode scrolled the page,
;; which already fits, up into blank space, and the single-page view
;; instead turns the page, since no line is left to scroll.  Skips if
;; the window is not as high as when the reference was recorded.  Needs
;; a graphical frame.

;;; Code:

(load (expand-file-name "gui-helper" (file-name-directory load-file-name)) nil t)

(defun check-keys ()
  "Return the trace of the keys in the single-page view."
  (let ((buffer (gui-check-open (gui-check-test-pdf)))
        (step 0)
        trace)
    (pdf-view-single-page-mode 1)
    (gui-check-settle)
    (cl-flet ((press (what thunk)
                (condition-case err
                    (funcall thunk)
                  (error (push (list (cl-incf step) what 'error err) trace)))
                (gui-check-settle)
                (push (list (cl-incf step) what
                            (pdf-view-current-page) (window-vscroll nil t))
                      trace))
              (key (keys)
                (lambda () (call-interactively (key-binding (kbd keys))))))
      (dotimes (_ 5) (press "SPC" (key "SPC")))
      (dotimes (_ 4) (press "DEL" (key "DEL")))
      (dotimes (_ 12) (press "C-n" (key "C-n")))
      (dotimes (_ 14) (press "C-p" (key "C-p")))
      (dotimes (_ 6) (press "wheel down" (lambda () (funcall mwheel-scroll-up-function 5))))
      (dotimes (_ 3) (press "wheel up" (lambda () (funcall mwheel-scroll-down-function 5))))
      (press "n" (key "n"))
      (press "n" (key "n"))
      (press "p" (key "p"))
      (press "M->" (key "M->"))
      (press "SPC" (key "SPC"))
      (press "DEL" (key "DEL"))
      (press "M-<" (key "M-<"))
      (setq-local pdf-view-display-size 'fit-page)
      (pdf-view-redisplay t)
      (press "fit-page" #'ignore)
      (dotimes (_ 2) (press "SPC" (key "SPC")))
      (dotimes (_ 2) (press "C-n at fit-page" (key "C-n")))
      (dotimes (_ 2) (press "C-p at fit-page" (key "C-p")))
      (setq-local pdf-view-display-size 'fit-width)
      (pdf-view-redisplay t)
      (press "fit-width" #'ignore)
      (let ((pdf-view-turn-page-at-top-and-bottom nil))
        (dotimes (_ 40) (press "C-n, no turning" (key "C-n")))
        (press "SPC, no turning" (key "SPC"))))
    (kill-buffer buffer)
    (nreverse trace)))

(gui-check "check-single-page"
  (let* ((reference (gui-check-plain-mode-reference))
         (single (check-keys))
         (height (progn (gui-check-open (gui-check-test-pdf))
                        (pdf-view-single-page-mode 1)
                        (gui-check-settle)
                        (window-text-height nil t)))
         (ok t)
         previous)
    (if (/= height (plist-get reference :window-text-height))
        (progn
          (gui-check-log "the window is %d pixels high, the reference was recorded at %d"
                         height (plist-get reference :window-text-height))
          'skip)
      (cl-mapc
       (lambda (p s)
         (if (string-suffix-p "at fit-page" (nth 1 s))
             ;; No line is left to scroll, so the page turns.
             (unless (and (integerp (nth 2 s)) (integerp (nth 2 previous))
                          (= (abs (- (nth 2 s) (nth 2 previous))) 1)
                          (= (nth 3 s) 0))
               (setq ok nil)
               (gui-check-log "the page did not turn: %S after %S" s previous))
           (unless (equal p s)
             (setq ok nil)
             (gui-check-log "plain mode: %S\nsingle-page: %S" p s)))
         (setq previous s))
       (plist-get reference :keys) single)
      (gui-check-log "%d steps" (length single))
      ok)))

;;; check-single-page.el ends here

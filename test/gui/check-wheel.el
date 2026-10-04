;;; check-wheel.el --- The wheel scrolls by what the trackpad reports  -*- lexical-binding: t; -*-

;;; Commentary:

;; Sends test.pdf wheel events as the macOS port makes them -- a count of
;; lines and a pixel delta, the count 0 for a gentle gesture -- through
;; the keymaps, with `pixel-scroll-precision-mode' off and on.  Passes if
;; the wheel runs `pdf-roll-wheel-scroll' in both cases, also over the
;; fringe, PageDown runs `pdf-view-page-down' and `touch-end' nothing;
;; without the mode, 20 gentle events of 2 pixels move the page by whole
;; lines rather than not at all; with it, each event scrolls its pixels
;; exactly; in
;; both, scrolling 40 events down across pages and 40 back up returns to
;; where it started; and in `pdf-view-single-page-mode' the wheel turns
;; the page.  Before `pdf-roll-wheel-scroll', gentle events did nothing,
;; and with the mode on, scrolling up across a page went to the top of
;; the document.  Needs a graphical frame.

;;; Code:

(load (expand-file-name "gui-helper" (file-name-directory load-file-name)) nil t)
(require 'pixel-scroll)

(defun check-wheel-event (down pixels lines)
  "Return a wheel event DOWN or up, of PIXELS and LINES, over the window."
  (list (if down 'wheel-down 'wheel-up)
        (posn-at-x-y 300 300 (selected-window))
        1 lines (cons 0 (if down (- pixels) pixels))))

(defun check-wheel (down pixels lines n)
  "Send N wheel events through the keymaps, and return the position."
  (dotimes (_ n)
    (let* ((event (check-wheel-event down pixels lines))
           (command (key-binding (vector (car event)))))
      (setq this-command command)
      (funcall command event)
      (setq last-command command)
      (gui-check-settle)))
  ;; The next call is another gesture.
  (setq last-command nil)
  (list (pdf-view-current-page) (window-vscroll nil t)))

(gui-check "check-wheel"
  (gui-check-open (gui-check-test-pdf))
  (gui-check-settle)
  (let ((ok t))
    (cl-flet ((expect (what ok-p &optional value)
                (gui-check-log "%-58s %S: %s" what value (if ok-p "ok" "WRONG"))
                (unless ok-p (setq ok nil))))
      (dolist (precision '(nil t))
        (pixel-scroll-precision-mode (if precision 1 -1))
        (pdf-view-goto-page 1)
        (gui-check-settle)
        (gui-check-log "--- pixel-scroll-precision-mode %s" (if precision "on" "off"))
        (expect "the wheel runs" (eq (key-binding [wheel-down]) 'pdf-roll-wheel-scroll)
                (key-binding [wheel-down]))
        (expect "over the fringe, the wheel runs"
                (eq (key-binding [left-fringe wheel-down]) 'pdf-roll-wheel-scroll)
                (key-binding [left-fringe wheel-down]))
        (expect "PageDown runs" (eq (key-binding [next]) 'pdf-view-page-down)
                (key-binding [next]))
        (expect "touch-end runs" (memq (key-binding [touch-end]) '(nil ignore))
                (key-binding [touch-end]))
        (let ((gentle (check-wheel t 2.0 0 20)))
          (expect "20 gentle events of 2 px, 0 lines"
                  (if precision
                      (equal gentle '(1 40))
                    (and (> (cadr gentle) 0)
                         (= (mod (cadr gentle) (frame-char-height)) 0)))
                  gentle))
        (pdf-view-goto-page 1)
        (gui-check-settle)
        (let* ((down (check-wheel t 30.0 1 40))
               (back (check-wheel nil 30.0 1 40)))
          (expect "40 events of 30 px down" (> (car down) 1) down)
          (expect "and 40 back up" (equal back '(1 0)) back)))
      (pixel-scroll-precision-mode -1)
      (pdf-view-single-page-mode 1)
      (pdf-view-goto-page 1)
      (gui-check-settle)
      (gui-check-log "--- single-page view")
      (let ((pdf-view-turn-page-at-top-and-bottom t))
        (let ((down (check-wheel t 30.0 1 80)))
          (expect "80 events of 30 px down" (> (car down) 1) down))))
    ok))

;;; check-wheel.el ends here

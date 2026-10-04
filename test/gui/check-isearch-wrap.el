;;; check-isearch-wrap.el --- Isearch wraps to the same place in both modes  -*- lexical-binding: t; -*-

;;; Commentary:

;; When isearch wraps around the document, `pdf-isearch-wrap-function'
;; shows the top of the first page or the end of the last.  In roll mode
;; the last page may still show a placeholder, which `image-scroll-up'
;; cannot measure.  Passes if wrapping forward and backward leaves the
;; same page and vscroll in roll mode as in plain mode, without an error.
;; Needs a graphical frame.

;;; Code:

(load (expand-file-name "gui-helper" (file-name-directory load-file-name)) nil t)

(defun check-wrap (single forward from)
  "Wrap isearch FORWARD from page FROM, in the single-page view if SINGLE.
Return (PAGE VSCROLL), or the error."
  (pdf-view-single-page-mode (if single 1 -1))
  (gui-check-settle)
  (pdf-view-goto-page from)
  (gui-check-settle)
  (condition-case err
      (let ((isearch-forward forward))
        (pdf-isearch-wrap-function)
        (gui-check-settle)
        (list (pdf-view-current-page) (window-vscroll nil t)))
    (error err)))

(gui-check "check-isearch-wrap"
  (gui-check-open (gui-check-test-pdf))
  (gui-check-settle)
  (let ((reference (gui-check-plain-mode-reference))
        (height (window-text-height nil t))
        (ok t))
    (if (/= height (plist-get reference :window-text-height))
        (progn
          (gui-check-log "the window is %d pixels high, the reference was recorded at %d"
                         height (plist-get reference :window-text-height))
          'skip)
      (dolist (case (plist-get reference :isearch-wraps))
        (let* ((forward (car (car case)))
               (from (cadr (car case)))
               (plain (cdr case))
               (continuous (check-wrap nil forward from))
               (single (check-wrap t forward from)))
          (gui-check-log "wrapping %s from page %d: plain mode %S, continuous %S, single page %S"
                         (if forward "forward" "backward") from plain continuous single)
          (unless (and (equal plain continuous) (equal plain single))
            (setq ok nil))))
      ok)))

;;; check-isearch-wrap.el ends here

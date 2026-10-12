;;; check-nested-query.el --- A query may wait inside a reply handler  -*- lexical-binding: t; -*-

;;; Commentary:

;; The reply to an asynchronous query is handled in the filter of the
;; server process.  The handler of `pdf-cache-prefetch-minor-mode' draws
;; the page there, and the annotation hotspot function then asks the
;; server synchronously.  Passes if such a nested synchronous query
;; returns what the same query returns outside the handler.  Runs in
;; batch as well.

;;; Code:

(load (expand-file-name "gui-helper" (file-name-directory load-file-name)) nil t)

(gui-check "check-nested-query"
  (let ((buffer (find-file-noselect (gui-check-test-pdf)))
        nested)
    (with-current-buffer buffer
      (let ((pdf-info-asynchronous
             (lambda (_status _data)
               (let ((start (float-time)))
                 (setq nested
                       (condition-case err
                           (list (length (with-current-buffer buffer
                                           (pdf-info-getannots 2)))
                                 (- (float-time) start))
                         (error err)))))))
        (pdf-info-renderpage 2 300))
      (let ((start (float-time)))
        (while (and (not nested) (< (- (float-time) start) 10))
          (accept-process-output nil 0.05)))
      (let ((outside (length (pdf-info-getannots 2))))
        (gui-check-log "annotations of page 2: %S nested, in %S s; %d outside"
                       (car-safe nested) (cadr nested) outside)
        (and (integerp (car-safe nested))
             (= (car nested) outside)
             (> outside 0))))))

;;; check-nested-query.el ends here

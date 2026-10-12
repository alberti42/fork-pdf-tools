;;; check-long-document.el --- A long document opens, and how fast  -*- lexical-binding: t; -*-

;;; Commentary:

;; Opens a document of 2000 pages.  Sending the requests for all its page
;; sizes at once exceeded `max-lisp-eval-depth', because
;; `tq-process-buffer' calls itself once for each reply waiting.  Passes
;; if the document opens with every page size cached, and reports how
;; long `pdf-cache-read-pagesizes' takes, against one wait per page.
;; Runs in batch as well.

;;; Code:

(load (expand-file-name "gui-helper" (file-name-directory load-file-name)) nil t)

(gui-check "check-long-document"
  (with-current-buffer (find-file-noselect (gui-check-document "long"))
    (let ((pages (pdf-cache-number-of-pages)))
      (dotimes (_ 3)
        (pdf-cache-clear-data)
        (let ((start (float-time)))
          (pdf-cache-read-pagesizes)
          (gui-check-log "pdf-cache-read-pagesizes: %.3f s" (- (float-time) start))))
      (let ((start (float-time)))
        (dotimes (i pages) (pdf-info-pagesize (1+ i)))
        (gui-check-log "one wait per page:        %.3f s" (- (float-time) start)))
      (gui-check-log "%d pages" pages)
      (and (= pages 2000)
           (car (pdf-cache--data-get 'pagesize 2000))))))

;;; check-long-document.el ends here

;;; check-page-sizes.el --- Every page size is read, onto its page  -*- lexical-binding: t; -*-

;;; Commentary:

;; `pdf-cache-read-pagesizes' reads the size of every page in batches.
;; Opens a document of 250 pages, each of a width of its own, and passes
;; if the cached size of every page is the size the server reports for
;; it.  Runs in batch as well.

;;; Code:

(load (expand-file-name "gui-helper" (file-name-directory load-file-name)) nil t)

(gui-check "check-page-sizes"
  (with-current-buffer (find-file-noselect (gui-check-document "mixed-widths"))
    (let ((pages (pdf-cache-number-of-pages))
          (wrong 0))
      (dotimes (i pages)
        (unless (equal (pdf-cache-pagesize (1+ i)) (pdf-info-pagesize (1+ i)))
          (cl-incf wrong)))
      (gui-check-log "%d pages, %d with a wrong size; widths of pages 1, 100, 101 and 250: %S"
                     pages wrong
                     (mapcar (lambda (page) (car (pdf-cache-pagesize page))) '(1 100 101 250)))
      (and (= pages 250) (= wrong 0)))))

;;; check-page-sizes.el ends here

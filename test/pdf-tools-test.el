;; -*- lexical-binding: t; -*-

;; * ================================================================== *
;; * Tests not fitting anywhere else
;; * ================================================================== *

(require 'ert)

(ert-deftest pdf-tools-semantic-workaround ()
  (let (python-mode-hook)
    (require 'tablist)
    (should (null python-mode-hook))))

(ert-deftest pdf-tools-hotspots-do-not-act-on-a-stale-page ()
  "A link or an annotation of a page since closed does nothing when clicked."
  (require 'pdf-links)
  (require 'pdf-annot)
  (with-temp-buffer
    (use-local-map (make-sparse-keymap))
    (let ((stale t)
          acted)
      (cl-letf (((symbol-function 'pdf-view-page-stale-p) (lambda (&rest _) stale))
                ((symbol-function 'pdf-cache-pagelinks)
                 (lambda (_) '(((edges 0.1 0.1 0.2 0.2) (type . goto-dest) (page . 2)))))
                ((symbol-function 'pdf-links-action-to-string) (lambda (_) "link"))
                ((symbol-function 'pdf-links-action-perform)
                 (lambda (_) (push 'link acted)))
                ((symbol-function 'pdf-annot-activate-annotation)
                 (lambda (_) (push 'annotation acted)))
                ((symbol-function 'pdf-annot-get) (lambda (&rest _) 1)))
        (pdf-links-hotspots-function 1 '(100 . 100))
        (pdf-annot-create-hotspot-binding 'annot-1-1 nil '((page . 1)))
        (dolist (id '(link-1-1 annot-1-1))
          (funcall (lookup-key (current-local-map) (vector id 'mouse-1))))
        (should-not acted)
        (setq stale nil)
        (dolist (id '(link-1-1 annot-1-1))
          (funcall (lookup-key (current-local-map) (vector id 'mouse-1))))
        (should (equal '(annotation link) acted))))))

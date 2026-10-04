;; -*- lexical-binding: t; -*-

;; * ================================================================== *
;; * Tests for pdf-cache.el
;; * ================================================================== *

(require 'pdf-cache)
(require 'ert)

(ert-deftest pdf-cache-get-image ()
  (let (pdf-cache--image-cache)
    (should-not (pdf-cache-get-image 1 1))
    (setq pdf-cache--image-cache
          (list
           (pdf-cache--make-image 1 1 "1" nil)
           (pdf-cache--make-image 2 1 "2" nil)
           (pdf-cache--make-image 3 1 "3" nil)))
    (should (equal (pdf-cache-get-image 1 1) "1"))
    (should (equal pdf-cache--image-cache
                   (list
                    (pdf-cache--make-image 1 1 "1" nil)
                    (pdf-cache--make-image 2 1 "2" nil)
                    (pdf-cache--make-image 3 1 "3" nil))))
    (should (equal (pdf-cache-get-image 2 1) "2"))
    (should (equal pdf-cache--image-cache
                   (list
                    (pdf-cache--make-image 2 1 "2" nil)
                    (pdf-cache--make-image 1 1 "1" nil)
                    (pdf-cache--make-image 3 1 "3" nil))))
    (should-not (pdf-cache-get-image 4 1))))

(ert-deftest pdf-cache-annotations-keep-the-page-size ()
  "Changing an annotation clears what it may change, not the page size."
  (with-temp-buffer
    (pdf-cache--data-put 'pagesize '(612 . 792) 2)
    (pdf-cache--data-put 'boundingbox '(0 0 1 1) 2)
    (pdf-cache--data-put 'boundingbox '(0 0 1 1) 3)
    (pdf-cache--clear-data-of-annotations
     (lambda (&rest _) '(((page . 2)) ((page . 3)))))
    (should (equal '(t 612 . 792) (pdf-cache--data-get 'pagesize 2)))
    (should-not (car (pdf-cache--data-get 'boundingbox 2)))
    (should-not (car (pdf-cache--data-get 'boundingbox 3)))))

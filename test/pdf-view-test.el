;; -*- lexical-binding: t -*-

(require 'pdf-view)
(require 'ert)

;; Tests for pdf-view-register struct and cl-defmethod implementations.
;; These tests use mock bookmark data because the actual pdf-view-registerv-make
;; function requires a window context which isn't available in batch mode.

(ert-deftest pdf-view-register-struct-creation ()
  "Test that pdf-view-register struct can be created."
  (let* ((mock-bookmark '("test.pdf"
                          (filename . "/path/to/test.pdf")
                          (page . 1)
                          (origin . (0.0 . 0.0))
                          (handler . pdf-view-bookmark-jump-handler)))
         (reg (pdf-view-register--make mock-bookmark)))
    ;; Should return non-nil
    (should reg)
    ;; Should be a pdf-view-register struct
    (should (pdf-view-register-p reg))
    ;; Should store the bookmark
    (should (equal (pdf-view-register-bookmark reg) mock-bookmark))))

(ert-deftest pdf-view-register-val-describe ()
  "Test that register-val-describe works for PDF register entries."
  (let* ((mock-bookmark '("test.pdf"
                          (filename . "/path/to/test.pdf")
                          (page . 5)
                          (origin . (0.0 . 0.5))
                          (handler . pdf-view-bookmark-jump-handler)))
         (reg (pdf-view-register--make mock-bookmark)))
    ;; register-val-describe should return a non-empty string
    (should (stringp
             (with-output-to-string
               (register-val-describe reg nil))))
    ;; The description should mention the page number
    (should (string-match-p "page 5"
             (with-output-to-string
               (register-val-describe reg nil))))))

(ert-deftest pdf-view-register-val-insert ()
  "Test that register-val-insert works for PDF register entries."
  (let* ((mock-bookmark '("test.pdf"
                          (filename . "/path/to/test.pdf")
                          (page . 1)
                          (handler . pdf-view-bookmark-jump-handler)))
         (reg (pdf-view-register--make mock-bookmark)))
    ;; register-val-insert should insert text without error
    (with-temp-buffer
      (register-val-insert reg)
      (should (> (buffer-size) 0)))))

(ert-deftest pdf-view-handle-archived-file ()
  :expected-result :failed
  (skip-unless (executable-find "gzip"))
  (let ((tramp-verbose 0)
        (temp
         (make-temp-file "pdf-test")))
    (unwind-protect
        (progn
          (copy-file "test.pdf" temp t)
          (call-process "gzip" nil nil nil temp)
          (setq temp (concat temp ".gz"))
          (should (numberp (pdf-info-number-of-pages temp)))))
    (when (file-exists-p temp)
      (delete-file temp))))

(defun pdf-test-mode-line-position ()
  "Return `mode-line-position' as redisplay would render it.
`format-mode-line' returns the empty string in batch, so the construct is
evaluated here instead."
  (mapconcat (lambda (element)
               (cond
                ((and (consp element) (eq (car element) :eval))
                 (format "%s" (eval (cadr element) t)))
                ((and (symbolp element) (boundp element))
                 (format "%s" (symbol-value element)))
                (t (format "%s" element))))
             mode-line-position ""))

(ert-deftest pdf-view-mode-line-asks-the-server-nothing ()
  "The mode line is evaluated during redisplay, so it may not query.

A query waits in `accept-process-output', which runs timers and other
processes' filters and sentinels in the middle of that redisplay."
  (pdf-test-with-test-pdf
    ;; `find-file-noselect' alone does not enter the mode in batch.
    (pdf-view-mode)
    (should (equal 6 pdf-view--mode-line-number-of-pages))
    (should (equal '("1" "2" "3" "4" "5" "6") pdf-view--mode-line-pagelabels))
    (let (queried)
      (cl-letf (((symbol-function 'pdf-info-query)
                 (lambda (cmd &rest _) (setq queried cmd)))
                ((symbol-function 'image-mode-window-get)
                 (lambda (prop &optional _w) (when (eq prop 'page) 3))))
        (should (equal " P3/6" (pdf-test-mode-line-position)))
        (let ((pdf-view-mode-line-position-use-labels t))
          (should (equal " P3/6" (pdf-test-mode-line-position)))))
      (should-not queried))))

(ert-deftest pdf-view-mode-line-answers-without-the-data ()
  "The construct reports the states it used to signal in."
  (pdf-test-with-test-pdf
    (pdf-view-mode)
    (cl-letf (((symbol-function 'image-mode-window-get) (lambda (&rest _) nil)))
      ;; No page in the window yet.
      (should (equal " P?/6" (pdf-test-mode-line-position))))
    (let ((pdf-view--mode-line-number-of-pages nil))
      (cl-letf (((symbol-function 'image-mode-window-get)
                 (lambda (prop &optional _w) (when (eq prop 'page) 3))))
        (should (equal " P3/???" (pdf-test-mode-line-position)))))))

;; -*- lexical-binding: t -*-

(require 'pdf-loader)
(require 'ert)
(require 'cl-lib)

(ert-deftest pdf-loader-activation ()
  :expected-result :failed ;; Until someone figures out how to run the
                           ;; tests w/o loading all of the package.
  (should-not (memq 'pdf-tools features))
  (pdf-loader-install)
  (with-current-buffer (find-file "test.pdf")
    (should (eq major-mode 'pdf-view-mode))))

(ert-deftest pdf-loader-install/uninstall-alists ()
  (cl-labels ((alists-installed-p ()
                (and (assoc pdf-loader--auto-mode-alist-item
                            auto-mode-alist)
                     (assoc pdf-loader--magic-mode-alist-item
                            magic-mode-alist))))
    (pdf-loader--install #'ignore)
    (should (alists-installed-p))
    (pdf-loader--uninstall)
    (should-not (alists-installed-p))))

(ert-deftest pdf-loader-skip-large-file-warning ()
  (let* ((dir (make-temp-file "pdf-loader-test" t))
         (pdf (expand-file-name "a.pdf" dir))
         (unnamed-pdf (expand-file-name "a-pdf-without-suffix" dir))
         (text (expand-file-name "a.txt" dir))
         asked)
    (unwind-protect
        (cl-flet ((ask-p (op-type filename)
                    (setq asked nil)
                    (pdf-loader--skip-large-file-warning
                     (lambda (&rest _) (setq asked t) nil)
                     100000000 op-type filename t)
                    asked))
          (with-temp-file unnamed-pdf (insert "%PDF-1.4\n"))
          (with-temp-file text (insert "text\n"))
          (let ((pdf-tools-warn-about-large-files nil))
            (should-not (ask-p "open" pdf))
            (should-not (ask-p "open" unnamed-pdf))
            (should (ask-p "open" text))
            (should (ask-p "insert" pdf)))
          (let ((pdf-tools-warn-about-large-files t))
            (should (ask-p "open" pdf))))
      (delete-directory dir t))))

(ert-deftest pdf-loader-install-adds-large-file-advice ()
  (unwind-protect
      (cl-letf (((symbol-function 'pdf-loader--install) #'ignore)
                ((symbol-function 'pdf-tools-install) #'ignore))
        (pdf-loader--remove-large-file-advice)
        (pdf-loader-install)
        (should (advice-member-p #'pdf-loader--skip-large-file-warning
                                 'abort-if-file-too-large)))
    (pdf-loader--remove-large-file-advice)))

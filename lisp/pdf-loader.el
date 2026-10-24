;;; pdf-loader.el --- Minimal PDF Tools loader       -*- lexical-binding: t; -*-

;; Copyright (C) 2017  Andreas Politz

;; Author: Andreas Politz <politza@hochschule-trier.de>
;; Keywords:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;

;;; Code:

(defconst pdf-loader--auto-mode-alist-item
  (copy-sequence "\\.[pP][dD][fF]\\'")
  "The item used in `auto-mode-alist'.")

(defconst pdf-loader--magic-mode-alist-item
  (copy-sequence "%PDF")
  "The item used in`magic-mode-alist'.")

(defcustom pdf-tools-warn-about-large-files nil
  "Whether Emacs asks before opening a large PDF file.

Emacs asks for confirmation before opening a file larger than
`large-file-warning-threshold'.  If this is nil, it does not ask
for a PDF file that PDF Tools displays: one whose name ends in
\".pdf\", or whose content starts with \"%PDF\".  Other files are
not affected."
  :group 'pdf-tools
  :type 'boolean)

(defun pdf-loader--pdf-file-p (filename)
  "Return non-nil if FILENAME is a PDF file PDF Tools displays."
  (or (string-match-p pdf-loader--auto-mode-alist-item filename)
      (and (not (file-remote-p filename))
           (ignore-errors
             (with-temp-buffer
               (set-buffer-multibyte nil)
               (insert-file-contents-literally
                filename nil 0 (length pdf-loader--magic-mode-alist-item))
               (equal (buffer-string) pdf-loader--magic-mode-alist-item))))))

(defun pdf-loader--skip-large-file-warning
    (orig-fun size op-type filename &rest args)
  "`:around' advice for `abort-if-file-too-large'.

Do not ask before opening FILENAME if it is a PDF file and
`pdf-tools-warn-about-large-files' is nil.  Otherwise call
ORIG-FUN with SIZE, OP-TYPE, FILENAME and ARGS."
  (unless (and (not pdf-tools-warn-about-large-files)
               (equal op-type "open")
               (pdf-loader--pdf-file-p filename))
    (apply orig-fun size op-type filename args)))

(defun pdf-loader--add-large-file-advice ()
  "Install `pdf-loader--skip-large-file-warning'."
  (advice-add 'abort-if-file-too-large :around
              #'pdf-loader--skip-large-file-warning))

(defun pdf-loader--remove-large-file-advice ()
  "Remove `pdf-loader--skip-large-file-warning'."
  (advice-remove 'abort-if-file-too-large
                 #'pdf-loader--skip-large-file-warning))


(declare-function pdf-tools-install "pdf-tools.el")

;;;###autoload
(defun pdf-loader-install (&optional no-query-p skip-dependencies-p
                                     no-error-p force-dependencies-p)
  "Prepare Emacs for using PDF Tools.

This function acts as a replacement for `pdf-tools-install' and
makes Emacs load and use PDF Tools as soon as a PDF file is
opened, but not sooner.

The arguments are passed verbatim to `pdf-tools-install', which
see."
  (let ((args (list no-query-p skip-dependencies-p
                    no-error-p force-dependencies-p)))
    ;; Emacs asks about a large file before the file loads PDF Tools.
    (pdf-loader--add-large-file-advice)
    (if (featurep 'pdf-tools)
        (apply #'pdf-tools-install args)
      (pdf-loader--install
       (lambda ()
         (apply #'pdf-loader--load args))))))

(defun pdf-loader--load (&rest args)
  (pdf-loader--uninstall)
  (save-selected-window
    (apply #'pdf-tools-install args)))

(defun pdf-loader--install (loader)
  (pdf-loader--uninstall)
  (push (cons pdf-loader--auto-mode-alist-item loader)
        auto-mode-alist)
  (push (cons pdf-loader--magic-mode-alist-item loader)
        magic-mode-alist))

(defun pdf-loader--uninstall ()
  (let ((elt (assoc pdf-loader--auto-mode-alist-item
                    auto-mode-alist)))
    (when elt
      (setq auto-mode-alist (remove elt auto-mode-alist))))
  (let ((elt (assoc pdf-loader--magic-mode-alist-item
                    magic-mode-alist)))
    (when elt
      (setq magic-mode-alist (remove elt magic-mode-alist)))))

(provide 'pdf-loader)
;;; pdf-loader.el ends here

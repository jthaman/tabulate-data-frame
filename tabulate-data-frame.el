;;;; tabulate-data-frame.el --- Tabulated list view for data.frames in ESS-R sessions  -*- lexical-binding: t; -*-

;; Copyright (C) 2022 Free Software Foundation, Inc.

;; Author: John Haman
;; Maintainer: John Haman <mail@johnhaman.org>
;; Created: 2022
;; Version: 0.1
;; Package-Requires: ((emacs "27.1") (ess "19.03"))
;; Homepage: https://github.com/jthaman/tabulate-data-frame

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.


;;; Commentary:

;; Experimental library to display R data.frames in a new buffer using
;; `tabulated-list-mode'.

;;; Code:

(eval-when-compile
  (require 'cl-lib))
(require 'tabulated-list)
(require 'ess-r-mode)

(defgroup tabulate-data-frame ()
  "Customization group for Tabulate Data Frame."
  :group 'tabulate-data-frame
  :prefix "tabulate-data-frame-")

(defvar viewer-buf-name "*R data.frame*"
  "Buffer for R data.frame viewing")

(defvar ess-command-buffer " *ess-command-output*"
  "Name of the ESS command output buffer, as it is defined in the
ess-inf.el source code.")

(defvar list-data-frames-cmd
  "Filter(function(x) is.data.frame(get(x)), ls(envir = .GlobalEnv))"
  "R command to get a list of data.frames from the R global environment.")

(defun get-data-frames ()
  "Determine the list of data.frame names in the R .GlobalEnv and
put that in a buffer."
  (ess-command list-data-frames-cmd))

(defun df-name-p (string)
  "Match STRINGs like [1] or [15]."
  (string-match (rx (or "[" "]"))
                string))

(defun buffer-to-list (buf)
  "Convert BUF containing the data.frame names into a
list of data.frame names."
  (with-current-buffer buf
    (let ((initial-list (split-string
                         (buffer-substring (point-min) (point-max)))))
      (setq initial-list
            (mapcar
             #'(lambda (x) (replace-regexp-in-string (rx "\"") "" x)) ; remove quotes
             initial-list))
      (cl-delete-if #'df-name-p initial-list))))


(defun get-df-cmd (df-name)
  "Generate R code to get the value of the data.frame DF-NAME."
  (concat "get(deparse(substitute(" df-name ")))"))

;; Need function to create tabulated-list-format from the colnames

(defun get-df-col-names-cmd (df-name)
  "Return a list of the column names of DF-NAME."
  (let ((cmd (concat "colnames(" df-name ")")))
    (ess-force-buffer-current)
    (ess-command cmd)
    (buffer-to-list ess-command-buffer)))

(defun make-header (df-name)
  "Create the input to tabulated-list-format, the columns and
spacing for the tabulated-list."
  (let ((header (get-df-col-names-cmd df-name)))
    (vconcat
     (cl-loop for name being each element of header
              collect (list name 15 t))
     nil)))


;; Need function to create tabulated-list-entries from the rows of df

(defun get-df-row-names-cmd (df-name)
  "Return a list of the row names of DF-NAME."
  (let ((cmd (concat "rownames(" df-name ")")))
    (ess-force-buffer-current)
    (ess-command cmd)
    (buffer-to-list ess-command-buffer)))

(defun get-df-data-cmd (df-name)
  "Read the print out of the data.frame DF-NAME and construct a
list of vectors: one vector for each row in DF-NAME."
  (let ((cmd (concat
              "write.table(" df-name ", row.names = FALSE, col.names = FALSE, quote = FALSE)")))
    (ess-force-buffer-current)
    (ess-command cmd)
    (with-current-buffer ess-command-buffer
      (cl-loop until (eobp)
               collect (vconcat ; convert list to vector
                        (split-string ; split line on the space and remove newline
                         (thing-at-point 'line t) ; take each line of buffer
                         " " nil (rx "\n"))
                        nil)
               do (forward-line 1)))))


(defun data-for-table (df-name)
  "Zip the row names and the data.frame data together for
`tabulated-list-entries'."
  (let ((row-names (get-df-row-names-cmd df-name))
        (df-data (get-df-data-cmd df-name)))
    (cl-mapcar #'list row-names df-data)))


(define-derived-mode tabulate-data-frame-mode tabulated-list-mode "Tabulated Data.frame"
  "Mode for inspecting data.frames in the R session."
  :group 'tabulate-data-frame)

(defun tabulate-data-frame (df-name)
  "Select a data.frame DF-NAME interactively from the list of
data.frames and view it."

  (interactive
   (progn
     (get-data-frames)
     (list
      (completing-read "data.frame> " (buffer-to-list ess-command-buffer)))))

  (with-current-buffer (get-buffer-create viewer-buf-name)

    (let ((tabulated-list-entries (data-for-table df-name))
          (tabulated-list-format (make-header df-name))
          (tabulated-list-sort-key nil))

      (setq tabulated-list-padding 2)
      (tabulate-data-frame-mode)
      (tabulated-list-init-header)
      (tabulated-list-print t))
    (display-buffer (current-buffer))))

(provide 'tabulate-data-frame)

;;; tabulate-data-frame.el ends here

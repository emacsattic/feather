;;; feather-polyfill.el ---                          -*- lexical-binding: t; -*-

;; Copyright (C) 2018  Naoya Yamashita

;; Author: Naoya Yamashita <conao@conao-imac.local>
;; Keywords: lisp, abbrev

;; This program is free software; you can redistribute it and/or modify
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

;; 

;;; Code:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  For legacy Emacs
;;

(unless (fboundp 'gnutls-available-p)
  (defun gnutls-available-p ()
    "Available status for gnutls.
(It is quite difficult to implement, so always return nil when not defined.
see `gnutls-available-p'.)"
    nil))

(unless (boundp 'user-emacs-directory)
  (defvar user-emacs-directory
    (if load-file-name
        (expand-file-name (file-name-directory load-file-name))
      "~/.emacs.d/")))

(unless (fboundp 'locate-user-emacs-file)
  (defun locate-user-emacs-file (name)
    "Simple implementation of `locate-user-emacs-file'."
    (format "%s%s" user-emacs-directory name)))

(defmacro leaf-case (fn var &rest conds)
  "Switch case macro with FN.
Emacs-22 doesn't support `pcase'."
  (declare (indent 2))
  (let ((lcond var))
    `(cond
      ,@(mapcar (lambda (x)
                  (let ((rcond (car x))
                        (form (cadr x)))
                    (if (eq rcond '_)
                        `(t ,form)
                      `((funcall ,fn ,lcond ,rcond) ,form))))
                conds)
      (t nil))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Anaphoric macros
;;

(defmacro feather-asetq (sym* &optional body)
  "Anaphoric setq macro.
\(fn (ASYM SYM) &optional BODY)"
  (declare (indent 1))
  `(let ((,(car sym*) ,(cadr sym*)))
     (setq ,(cadr sym*) ,body)))

(defmacro feather-alet (varlist* &rest body)
  "Anaphoric let macro. Return first arg value.
CAUTION:
`it' has first var value, it is NOT updated if var value changed.

(macroexpand
 '(leaf-alet (it ((result t)))
  (princ it)))
=> (let* ((result t)
          (it result))
     (progn (princ it))
     result)

\(fn (ASYM (VARLIST...)) &rest BODY)"
  (declare (debug t) (indent 1))
  `(let* (,@(cadr varlist*)
          (,(car varlist*) ,(caar (cadr varlist*))))
     (progn ,@body)
     ,(caar (cadr varlist*))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  General functions
;;

(defsubst feather-truep (var)
  "Return t if var is non-nil."
  (not (not var)))

(defsubst feather-message (from-fn msg &optional level)
  "Show message.
LEVEL is one of :emargency, :error, :warning, :debug."
  (if level
      (display-warning 'feather (format "%s: %s" from-fn msg) level)
    (message (format "[feather] %s: %s" from-fn msg))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  General hash table functions
;;

(defun feather-ht-update! (table from-table)
  "Update TABLE according to every key-value pair in FROM-TABLE."
  (maphash
   (lambda (key value) (puthash key value table))
   from-table)
  nil)

(defun feather-ht-merge (&rest tables)
  "Crete a new tables that includes all the key-value pairs from TABLES.
If multiple have tables have the same key, the value in the last
table is used."
  (let ((merged (make-hash-table :test 'eq)))
    (mapc (lambda (table) (feather-ht-update! merged table)) tables)
    merged))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  General path functions
;;

(defun feather-path-parent (path)
  "Return parent path of PATH"
  (file-name-directory (directory-file-name path)))

(provide 'feather-polyfill)
;;; feather-polyfill.el ends here
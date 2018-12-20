;;; feather.el ---                                   -*- lexical-binding: t; -*-

;; Copyright (C) 2018  Naoya Yamashita

;; Author: Naoya Yamashita
;; Keywords: .emacs

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

(defgroup feather nil
  "Emacs package manager with parallel processing."
  :group 'lisp)

(defconst feather-version "0.0.1"
  "feather.el version")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Customizable variables
;;

(defcustom feather-fetcher-list '(melpa)
  "A list of sites to fetch.
If there are multiple download destinations,
priority is given to the site located at the head of the list

[TODO]: Now, support melpa only."
  ;; :type '(sexp
  ;;         (symbol
  ;;          ;; (const :tag "Elpa"         'elpa)
  ;;          (const :tag "Melpa"        'melpa)))
  ;;          ;; (const :tag "Melpa-stable" 'melpa-stable)
  ;;          ;; (const :tag "el-get"       'el-get)
  ;;          ;; (const :tag "cask"         'cask)))
  :type 'sexp
  :group 'feather)

(defcustom feather-fetcher-url-alist
  '((melpa . "https://raw.githubusercontent.com/conao3/feather-recipes/master/recipe-melpa.el"))
  "Fetcher URL alist. see `feather-fetcher-list'."
  :type 'alist
  :group 'feather)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Directory paths
;;

(defcustom feather-repos-dir (locate-user-emacs-file "feather/repos/")
  "Directory where the download Emacs Lisp packages is placed."
  :type 'directory
  :group 'feather)

(defcustom feather-recipes-dir (locate-user-emacs-file "feather/recipes/")
  "Directory where the recipes is placed."
  :type 'directory
  :group 'feather)

(defcustom feather-build-dir (locate-user-emacs-file "feather/build/")
  "Directory where byte-compiled Emacs Lisp files is placed"
  :type 'directory
  :group 'feather)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Package configuration
;;

(defcustom feather-user-recipes nil
 "User defined package recipes. Overrides recipes.
Recipe need `:url', [`:commit'], `:deps', `:ver'. see `feather-recipes'.
If you omit `:commit', install HEAD.

Sample:
(:0blayout
   (:props
    (:url \"https://github.com/etu/0blayout\"
     :maintainer \"Elis \"etu\" Axelsson\"
     :authors (\"Elis \"etu\" Axelsson\")
     :keywords (\"convenience\" \"window-management\")
     :commit \"873732ddb99a3ec18845a37467ee06bce4e61d87\")
    :type \"single\"
    :desc \"Layout grouping with ease\"
    :deps nil
    :ver (20161008 607))
 :0xc
  (:props
   (:url \"http://github.com/AdamNiederer/0xc\"
    :commit \"12c2c6118c062a49594965c69e6a17bb46339eb2\")
   :deps (:s (1 11 0)
          :emacs (24 4))
   :ver (20170126 353))
 :2048-game
  (:props
   (:url \"https://bitbucket.org/zck/2048.el\")
   :ver (20151026 1933)))"
  :type 'sexp
  :group 'feather)

(defcustom feather-selected-packages nil
  "Store here packages installed explicitly by user.
This variable is fed automatically by feather.el when installing a new package.
This variable is used by `feather-autoremove' to decide
which packages are no longer needed.

You can use it to (re)install packages on other machines
by running `feather-install-selected-packages'.

To check if a package is contained in this list here,
use `feather-user-selected-p'."
  :type '(repeat symbol)
  :group 'feather)

;; (defcustom feather-pinned-packages nil
;;   "An alist of packages that are pinned to specific archives.
;; This can be useful if you have multiple package archives enabled,
;; and want to control which archive a given package gets installed from.
;; 
;; Each element of the alist has the form (PACKAGE . ARCHIVE), where:
;;  PACKAGE is a symbol representing a package
;;  ARCHIVE is a string representing an archive (it should be the car of
;; an element in `package-archives', e.g. \"gnu\").
;; 
;; Adding an entry to this variable means that only ARCHIVE will be
;; considered as a source for PACKAGE.  If other archives provide PACKAGE,
;; they are ignored (for this package).  If ARCHIVE does not contain PACKAGE,
;; the package will be unavailable."
;;   :type '(alist :key-type (symbol :tag "Package")
;;                 :value-type (string :tag "Archive name"))
;;   :group 'feather)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Inner variables - DON'T change!
;;

(defvar feather-initialized nil
  "Manage `feather' initialization state.
This variable is set automatically by `feather-initialize'.")

;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Manage Process

(defvar feather-process-state-alist nil
  "Manage `feather' process state.
When change process state changed, pushed new state.")

;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Manage recipes
;;

(defvar feather-recipes nil
  "Package recipes.
Stored ordered by `feather-fetcher-list'.
This variable is set automatically by `feather-initialize'.")

;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Manage packages

(defvar feather-installed-plist nil
  "List of all packages user installed.
This variable is controlled by `feather-install' and `feather-remove'.")

(defvar feather-user-installed-plist nil
  "List of all packages user specifyed installed (without dependencies).")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Support functions
;;

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Shell controllers
;;

(defun feather-command-queue (pkg cmdlst)
  "Execute cmdlst(string-list) queue with `start-process'.

CMDLST is like ((\"pwd\") (\"echo\" \"$(whoami)\")).
CMDLST will be escaped (\"pwd\" \"echo \\\\$\\\\(whoami\\\\)\").

The arguments passed in are properly escaped, so address vulnerabilities
like OS command injection.
The case, user can't get user-name (just get \\$(shoami)).

If CMDLST is (A B C), if A fails, B and subsequent commands will not execute."
  (let* ((safe-cmdlst (mapcar
                       (lambda (x)
                         (mapconcat #'shell-quote-argument x " "))
                       cmdlst))
         (command     (mapconcat #'identity safe-cmdlst " && "))
         (buffer-name (format "*feather-async-%s-%s*" pkg (gensym)))
         (buffer      (get-buffer-create buffer-name))
         (directory   default-directory)
         (proc        (get-buffer-process buffer)))

    (when (get-buffer-process buffer)
      (setq buffer (generate-new-buffer buffer-name)))
    
    (with-current-buffer buffer
      (shell-command-save-pos-or-erase)
      (setq default-directory directory)
      (setq proc (start-process buffer-name
                                buffer
                                shell-file-name      ; /bin/bash (default)
				shell-command-switch ; -c (default)
                                command))
      (setq mode-line-process '(":%s"))
      (require 'shell) (shell-mode)
      (set-process-sentinel proc 'shell-command-sentinel)
      ;; Use the comint filter for proper handling of
      ;; carriage motion (see comint-inhibit-carriage-motion).
      (set-process-filter proc 'comint-output-filter)
      (display-buffer buffer '(nil (allow-no-window . t))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Git controllers
;;

;; (feather-git-clone-head "melpa" "https://github.com/melpa/melpa" feather-recipes-dir)
(defun feather-git-clone-head (pkg remote-url destdir)
  "Clone REMOTE-URL repository HEAD to DESTDIR. (shallow-clone)"
  (let ((destpath (concat destdir (file-name-nondirectory remote-url))))
    (if (file-directory-p destpath)
        (feather-git-pull-head pkg destpath)
      (let ((default-directory (expand-file-name destdir)))
        (feather-command-queue
         pkg
         `(("pwd")
           ("git" "clone" "-depth" "1" ,remote-url)))))))

;; (feather-git-clone-specific "https://github.com/conao3/cort.el"
;;                             "v0.1" feather-repos-dir)
(defun feather-git-clone-specific (pkg remote-url spec destdir)
  "Clone REMOTE-URL repository SPEC only to DESTDIR. (shallow-clone)"
  (let* ((repo-name (file-name-nondirectory remote-url))
         (destpath  (concat destdir repo-name)))
    (if (file-directory-p destpath)
        (let ((default-directory (expand-file-name destpath)))
          (feather-command-queue
           pkg
           `(("pwd")
             ("echo" "Repostory is already existed.")
             ("echo")
             ("echo" "If you want to check out to another commit,")
             ("echo" "first delete repository by `remove-package'."))))
      (let ((default-directory (expand-file-name destdir)))
        (feather-command-queue
         pkg
         `(("pwd")
           ("mkdir" ,repo-name)
           ("cd" ,repo-name)
           ("git" "init")
           ("git" "remote" "add" "origin" ,remote-url)
           ("git" "fetch" "-depth" "1" "origin" ,spec)
           ("git" "reset" "-hard" "FETCH_HEAD")))))))

;; (feather-git-pull-head (concat feather-recipes-dir "melpa"))
(defun feather-git-pull-head (pkg destpath)
  "Pull repository"
  (let ((default-directory (expand-file-name destpath)))
    (feather-command-queue
     pkg
     `(("pwd")
       ("git" "pull" "origin" "master")))))

(defun feather-git-unshalow (pkg destpath)
  "Unshallow repository to fetch whole repository."
  (let ((default-directory (expand-file-name destpath)))
    (feather-command-queue
     pkg
     `(("pwd")
       ("git" "fetch" "-unshallow")
       ("git" "checkout" "master")))))
  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Package contorollers
;;

(defun feather-activate (pkg)
  "Activate PKG with dependencies packages."
  )

(defun feather-generate-autoloads (pkg)
  "Generate autoloads .el file"
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Interactive functions
;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Remove packages
;;

;;;###autoload
(defun feather-autoremove ()
  "Remove packages that are no more needed.
Packages that are no more needed by other packages in
`feather-selected-packages' and their dependencies will be deleted."
  (interactive)
  (let ((lst (feather-install-selected-packages)))
    (mapc (lambda (x) (delq x lst) feather-selected-packages))
    (mapc (lambda (x) (feather-remove x)) lst)))

;;;###autoload
(defun feather-remove (pkg)
  "Remove specified package named PKG.
If you want to remove packages no more needed, call `feather-autoremove'."
  (interactive)
  )

;;;###autoload
(defun feather-clean ()
  "Clean feather working directory and build directory."
  (interactive)
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Install packages
;;

;;;###autoload
(defun feather-install-selected-packages ()
  "Install `feather-selected-packages' listed packages."
  (interactive)
  (mapc (lambda (x) (feather-install x)) feather-selected-packages))

;;;###autoload
(defun feather-install (pkg)
  "Install specified package named PKG."
  (interactive)
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Manage recipes
;;

;;;###autoload
(defun feather-refresh ()
  "Reflesh package recipes specified `feather-fetcher-list'.
The URL corresponding to the symbol is managed with `feather-fetcher-url-alist'."
  (interactive)

  ;; clear all recipes.
  (setq feather-recipes nil)

  ;; download recipe files, read, append, save it.
  (mapc (lambda (x)
          (with-current-buffer
              (url-retrieve-synchronously (cdr (assoc x feather-fetcher-url-alist)))
            (delete-region (point-min)
                           (1+ (marker-position url-http-end-of-headers)))

            (feather-asetq (it feather-recipes)
              (append it (read (buffer-string))))

            (write-file (format "%srecipe-%s.el" feather-recipes-dir x))
            (kill-buffer)))
        feather-fetcher-list))

;;;###autoload
(defun feather-list-packages ()
  "Show available packages list."
  (interactive)
  )

;;;###autoload
(defun feather-package-info (pkg)
  "Show package info."
  (interactive)
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Initialize feather
;;

;;;###autoload
(defun feather-initialize ()
  "Initialize selected packages."
  (interactive)
  (unless feather-initialized
    ;; create dir
    (mapc (lambda (x) (make-directory x t)) `(,feather-repos-dir
                                              ,feather-recipes-dir
                                              ,feather-build-dir))

    ;; initialize recipes
    (feather-refresh)
    )
  )

(provide 'feather)
;;; feather.el ends here

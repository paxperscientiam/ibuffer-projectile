;;; ibuffer-projectile.el --- Group ibuffer's list by projectile root
;;
;; Copyright (C) 2011-2014 Steve Purcell
;;
;; Author: Steve Purcell <steve@sanityinc.com>
;; Keywords: themes
;; Package-Requires: ((projectile "0.11.0"))
;; URL: http://github.com/purcell/ibuffer-projectile
;; Package-Version: 0
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;
;;; Commentary:
;;
;; Adds functionality to ibuffer for grouping buffers by their projectile
;; root directory.
;;
;;; Use:
;;
;; To group buffers by projectile root dir:
;;
;;   M-x ibuffer-projectile-set-filter-groups
;;
;; or, make this the default:
;;
;;   (add-hook 'ibuffer-hook
;;     (lambda ()
;;       (ibuffer-projectile-set-filter-groups)
;;       (unless (eq ibuffer-sorting-mode 'alphabetic)
;;         (ibuffer-do-sort-by-alphabetic))))
;;
;; Alternatively, use `ibuffer-projectile-generate-filter-groups'
;; to programmatically obtain a list of filter groups that you can
;; combine with your own custom groups.
;;
;;; Code:

(require 'ibuffer)
(require 'ibuf-ext)
(require 'projectile)


(defgroup ibuffer-projectile nil
  "Group ibuffer entries according to their projectile root directory."
  :prefix "ibuffer-projectile-"
  :group 'convenience)

(defcustom ibuffer-projectile-skip-if-remote t
  "If non-nil, don't query the status of remote files."
  :type 'boolean
  :group 'ibuffer-projectile)

(defcustom ibuffer-projectile-include-function 'identity
  "A function which tells whether a given file should be grouped.

The function is passed a filename, and should return non-nil if the file
is to be grouped.

This option can be used to exclude certain files from the grouping mechanism."
  :type 'function
  :group 'ibuffer-projectile)

(defcustom ibuffer-projectile-prefix "Projectile:"
  "Prefix string for generated filter groups."
  :type 'string
  :group 'ibuffer-projectile)

(defcustom ibuffer-projectile-group-name-function 'ibuffer-projectile-default-group-name
  "Function used to produce the name for a group.
The function is passed two arguments: the projectile project
name, and the root directory path."
  :type 'function
  :group 'ibuffer-projectile)

(defun ibuffer-projectile-default-group-name (project-name root-dir)
  "Produce an ibuffer group name string for PROJECT-NAME and ROOT-DIR."
  (format "%s%s" ibuffer-projectile-prefix project-name))

(defun ibuffer-projectile--include-file-p (file)
  "Return t iff FILE should be included in ibuffer-projectile's filtering."
  (and file
       (or (null ibuffer-projectile-skip-if-remote)
           (not (file-remote-p file)))
       (funcall ibuffer-projectile-include-function file)))

(defun ibuffer-projectile-root (buf)
  "Return a cons cell (project-name . root-dir) for BUF.
If the file is not in a project, then nil is returned instead."
  (with-current-buffer buf
    (let ((file-name (ibuffer-buffer-file-name))
          (root (ignore-errors (projectile-project-root))))
      (when (and file-name
                 root
                 (ibuffer-projectile--include-file-p file-name))
        (cons (projectile-project-name) root)))))

(define-ibuffer-filter projectile-root
    "Toggle current view to buffers with projectile root dir QUALIFIER."
  (:description "projectile root dir"
                :reader (read-regexp "Filter by projectile root dir (regexp): "))
  (ibuffer-awhen (ibuffer-projectile-root buf)
    (equal qualifier it)))

;;;###autoload (autoload 'ibuffer-make-column-project-name "ibuffer-projectile")
(define-ibuffer-column project-name
  (:name "Project")
  (projectile-project-name))

;;;###autoload (autoload 'ibuffer-do-sort-by-project-name "ibuffer-projectile")
(define-ibuffer-sorter project-name
  "Sort the buffers by their project name."
  (:description "project")
  (let ((project1 (with-current-buffer (car a)
                    (projectile-project-name)))
        (project2 (with-current-buffer (car b)
                    (projectile-project-name))))
    (if (and project1 project2)
        (string-lessp project1 project2)
      (not (null project1)))))

(define-ibuffer-column project-file
  (:name "🚀Filename")
  (format "%s" (if (and buffer-file-name (projectile-project-root))
                   (dired-replace-in-string (projectile-project-root) "::" (buffer-file-name))
                 (buffer-name))))

;;;###autoload
(defun ibuffer-projectile-generate-filter-groups ()
  "Create a set of ibuffer filter groups based on the projectile root dirs of buffers."
  (let ((roots (ibuffer-remove-duplicates
                (delq nil (mapcar 'ibuffer-projectile-root (buffer-list))))))
    (mapcar (lambda (root)
              (cons (funcall ibuffer-projectile-group-name-function (car root) (cdr root))
                    `((projectile-root . ,root))))
            roots)))

;;;###autoload
(defun ibuffer-projectile-set-filter-groups ()
  "Set the current filter groups to filter by vc root dir."
  (interactive)
  (setq ibuffer-filter-groups (ibuffer-projectile-generate-filter-groups))
  (message "ibuffer-projectile: groups set")
  (let ((ibuf (get-buffer "*Ibuffer*")))
    (when ibuf
      (with-current-buffer ibuf
        (pop-to-buffer ibuf)
        (ibuffer-update nil t)))))


(provide 'ibuffer-projectile)
;;; ibuffer-projectile.el ends here

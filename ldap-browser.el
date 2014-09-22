;;; ldap-browser.el --- LDAP utility based on ldapsearch
;;
;; Copyright(c) 2014 Sylvain Chouleur <sylvain.chouleur@gmail.com>
;; Authors: Sylvain Chouleur <sylvain.chouleur@gmail.com>
;; Keywords: code
;; Licence: GPLv2
;; Version 0.1

;; Requires: ldapsearch

;; Usage:
;;   - customize 'ldap-username and 'ldap-password variables
;;   - load this script using (require 'ldap-browser)
;;   - M-x ldap-browser-search
;;       Provide a name to search with wildcard *
;;       Results will be displayed in *ldap-browser* buffer
;;
;; *ldap-browser* navigation:
;;    Use "v" to open contact card and see all LDAP fields available

;; This file is *NOT* part of GNU Emacs.
;; This file is distributed under the same terms as GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2 of
;; the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be
;; useful, but WITHOUT ANY WARRANTY; without even the implied
;; warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
;; PURPOSE.  See the GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public
;; License along with this program; if not, write to the Free
;; Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
;; MA 02111-1307 USA
;;
;; http://www.fsf.org/copyleft/gpl.html

(defvar ldap-username "username@example.com")
(defvar ldap-password (netrc-get-password "example.com"))
(defvar ldap-servers '(("ldap1.example.com" . "ou=Workers,dc=ldap1,dc=example,dc=com")
		       ("ldap1.example.com" . "ou=Workers,dc=ldap2,dc=example,dc=com")))
(defvar ldap-search-args "-LLL -t -o ldif-wrap=no -z none")
(defvar ldap-result-buffer-format "*ldap-result<%s>*")
(defvar ldap-contact-buffer "*ldap-contact<%s>*")
(defvar ldap-browser-buffer "*ldap-browser*")
(defvar ldap-browser-cols '(("cn" . ("Name" 29 t))
			    ("title" . ("ID" 10 t))
			    ("mail" . ("Email" 40 t))
			    ("mailNickname" . ("Nickname" 10 t))))

(define-derived-mode ldap-browser-mode tabulated-list-mode "Ldap Browser"
  "Major mode for ldap browser."
  (use-local-map ldap-browser-mode-map))

(defun ldap-browser-view ()
  "View contact details in a dedicated buffer"
  (interactive)
  (let ((id (tabulated-list-get-id))
	(entries ldap-browser-entries))
    (pop-to-buffer (get-buffer-create (format ldap-contact-buffer id)))
    (let ((inhibit-read-only t))
      (erase-buffer)
      (mapcar (lambda(x)(insert (format "%s = %s\n" (car x) (cdr x))))
	      (find id entries :key (lambda(x)(assoc-default "dn" x)) :test 'equal))
      (align-regexp (point-min) (point-max) "\\(\\s-*\\) = " 1 1)
      (goto-char (point-min))
      (view-mode))))

(defvar ldap-browser-mode-map
  (let ((map (make-sparse-keymap))
	(menu-map (make-sparse-keymap)))
    (set-keymap-parent map tabulated-list-mode-map)
    (define-key map "v" 'ldap-browser-view)
    map))

(defun ldap-browser-clear ()
  "Flush ldap-browser entries"
  (interactive)
  (with-current-buffer (get-create-ldap-browser-buffer)
    (setq ldap-browser-entries nil)
    (ldap-browser-update)))

(defun ldap-browser-update ()
  "Populates browser with found entries"
  (interactive)
  (with-current-buffer (get-create-ldap-browser-buffer)
    (setq tabulated-list-format (vconcat (mapcar 'cdr ldap-browser-cols)))
    (funcall tabulated-list-entries)
    (tabulated-list-print)
    (tabulated-list-init-header)))

(defun ldap-browser-entry-to-tab-entry (entry)
  "Output a tabulated-list-entries format of entry"
  (list (assoc-default "dn" entry)
	(vconcat (mapcar (lambda(col)(or (assoc-default (car col) entry) "-")) ldap-browser-cols))))

(defun ldap-browser-fill-entries ()
  "Populate tabulated-list-entries variable"
  (mapcar 'ldap-browser-entry-to-tab-entry ldap-browser-entries))

(defun get-create-ldap-browser-buffer ()
  (unless (get-buffer ldap-browser-buffer)
    (with-current-buffer (get-buffer-create ldap-browser-buffer)
      (ldap-browser-mode)
      (setq-local tabulated-list-entries 'ldap-browser-fill-entries)
      (make-local-variable 'ldap-browser-entries)
      (setq tabulated-list-format (vconcat (mapcar 'cdr ldap-browser-cols)))
      (tabulated-list-init-header)))
  (get-buffer ldap-browser-buffer))

(defun ldap-browser-add-entry (entry)
  "Add entry to ldap browser"
  (with-current-buffer (get-create-ldap-browser-buffer)
    (or (and ldap-browser-entries (nconc ldap-browser-entries (list entry)))
	(setq ldap-browser-entries (list entry)))))

(defun ldap-parse-results (add-func)
  "Parse ldapsearch output to find entries and call add-func for each found entry"
  (goto-char (point-min))
  (while (search-forward-regexp "^dn: " nil t)
    (let ((entry `(("dn" . ,(buffer-substring-no-properties (point) (point-at-eol)))))
	  (bound (save-excursion (search-forward-regexp "^$"))))
      (while (search-forward-regexp "^\\(\\w+\\):<? \\(.*\\)" bound t)
	(nconc entry (list (cons (match-string 1) (match-string 2)))))
      (funcall add-func entry))))

(defun ldap-search-sentinel (process change)
  (with-current-buffer (process-buffer process)
    (ldap-parse-results 'ldap-browser-add-entry)
    (ldap-browser-update)
    (pop-to-buffer ldap-browser-buffer)
    (unless (equal change "finished\n")
      (error "ldapsearch: %s" change))))

(defun ldap-browser-search-fields (pattern fields)
  "Fetch ldap entries filtered by FILTER on displayName.
You can use * as wildcard, but ensure that it's placed at the end of the string.
For obscure reasons, with a star at the beginning of the string the ldap query fails with a timeout..."
  (ldap-browser-clear)
  (dolist (server ldap-servers)
    (with-current-buffer (get-buffer-create (format ldap-result-buffer-format (car server)))
      (erase-buffer)
      (let* ((filter (mapconcat (lambda(x)(format "(%s=%s)" x pattern)) fields ""))
	     (cmd (format "%s -h %s -D %s -b %s -w %s (|%s)" ldap-search-args (car server) ldap-username (cdr server) ldap-password filter)))
	(message "cmd=%s" cmd)
	(set-process-sentinel (apply 'start-process "ldapsearch" (current-buffer) "ldapsearch" (split-string cmd)) 'ldap-search-sentinel))
      )))

(defun ldap-browser-search-name (name)
  "Search pattern in fields \"displayName\" and \"mail\""
  (interactive "sName: ")
  (ldap-browser-search-fields name '("displayName" "mail")))

(provide 'ldap-browser)

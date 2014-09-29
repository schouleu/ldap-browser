;;; ldap-browser.el --- LDAP utility based on ldapsearch
;;
;; Copyright(c) 2014 Sylvain Chouleur <sylvain.chouleur@gmail.com>
;; Authors: Sylvain Chouleur <sylvain.chouleur@gmail.com>
;; Keywords: code
;; Licence: GPLv2
;; Version 0.1

;; Requires: ldapsearch

;; Usage:
;;   - customize 'ldap-servers variable
;;   - Be sure to populate your ~/.authinfo file to provide login and
;;     password for each of the servers in 'ldap-servers
;;   - load this script using (require 'ldap-browser)
;;   - M-x ldap-browser-search-name
;;       Provide a name to search, using regexp syntax (e.g: *name*)
;;       Results will be displayed in *ldap-browser* buffer
;;   - M-x ldap-browser-insert-mail
;;       Provide a name to search, the result's mail will be inserted
;;       in current buffer if unique. If case of multiple results,
;;       *ldap-browser* buffer is opened to let the user select the
;;       good one. Hit RET to insert the email of selected contact.
;;
;; *ldap-browser* navigation:
;;    - "v"   : open contact card and see all LDAP fields available
;;    - "g"   : refresh buffer
;;    - "a"   : add contact to purple buddies
;;    - "RET" : apply current action on contact. If no action available, do as "v"

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

(defsubst curry (function &rest arguments)
  (lexical-let ((function function)
		(arguments arguments))
    (lambda (&rest more) (apply function (append arguments more)))))

(defsubst icurry (function &rest arguments)
  (lexical-let ((function function)
		(arguments arguments))
    (lambda (&rest more) (interactive) (apply function (append arguments more)))))

(defvar ldap-browser-mode-map
  (let ((map (make-sparse-keymap))
	(menu-map (make-sparse-keymap)))
    (set-keymap-parent map tabulated-list-mode-map)
    (define-key map "v" (icurry 'ldap-browser-action 'ldap-browser-view-contact))
    (define-key map "g" 'ldap-browser-update)
    (define-key map "a" (icurry 'ldap-browser-action 'ldap-browser-add-purple-buddy-callback))
    (define-key map (kbd "RET") 'ldap-browser-action)
    map))

(define-derived-mode ldap-browser-mode tabulated-list-mode "Ldap Browser"
  "Major mode for ldap browser."
  (use-local-map ldap-browser-mode-map))

(defun ldap-browser-get-contact (&optional id)
  "Return specified contact, or current one if not specified"
  (with-current-buffer (get-buffer ldap-browser-buffer)
    (let ((id (or id (tabulated-list-get-id)))
	  (entries ldap-browser-entries))
      (find id entries :key (lambda(x)(assoc-default "dn" x)) :test 'equal))))

(defun ldap-browser-view-contact (contact)
  "View contact details in a dedicated buffer"
    (pop-to-buffer (get-buffer-create (format ldap-contact-buffer (assoc-default "dn" contact))))
    (let ((inhibit-read-only t))
      (erase-buffer)
      (mapcar (lambda(x)(insert (format "%s = %s\n" (car x) (cdr x)))) contact)
      (align-regexp (point-min) (point-max) "\\(\\s-*\\) = " 1 1)
      (goto-char (point-min))
      (view-mode)))

(defun ldap-browser-action (&optional action)
  "Try to call in order (first existing wins)
 - action if non-nil
 - `ldap-browser-callback' if a valid function
 - `ldap-browser-view'"
  (interactive)
  (let ((action (or action
		    (and (functionp ldap-browser-callback) ldap-browser-callback)
		    'ldap-browser-view-contact)))
    (funcall action (ldap-browser-get-contact))))

(defun ldap-browser-clear ()
  "Flush ldap-browser entries"
  (interactive)
  (with-current-buffer (get-create-ldap-browser-buffer)
    (setq-local progress (make-progress-reporter "LDAP searching:" 0 (length ldap-servers)))
    (setq ldap-browser-entries nil)
    (ldap-browser-update)))

(defun ldap-browser-set-callback (callback)
  "set variable ldap-browser-callback"
  (with-current-buffer (get-create-ldap-browser-buffer)
    (setq-local ldap-browser-callback callback)))

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

(defun ldap-browser-remaining-requests ()
  "Return the amount of on-going requests"
  (let ((ongoing 0))
    (dolist (server ldap-servers ongoing)
      (let ((buf (get-buffer (format ldap-result-buffer-format (car server)))))
	(and buf (get-buffer-process buf) (setq ongoing (+ ongoing 1)))))))

(defun ldap-browser-may-callback ()
  "Call the `ldap-browser-callback' function if not nil and no more ldap requests remaining"
  (with-current-buffer (get-buffer ldap-browser-buffer)
    (when (functionp ldap-browser-callback)
      (if (= 1 (length ldap-browser-entries))
	  (funcall ldap-browser-callback (ldap-browser-get-contact))
	(pop-to-buffer ldap-browser-buffer)))))

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
      (ldap-parse-results 'ldap-browser-add-entry))
  (with-current-buffer (get-buffer ldap-browser-buffer)
    (let ((remaining (ldap-browser-remaining-requests)))
      (progress-reporter-update progress (- (length ldap-servers) remaining))
      (ldap-browser-update)
      (when (= 0 remaining)
	(ldap-browser-may-callback)
	(when (= 0 (length ldap-browser-entries))
	  (error "ldap-browser: No results")))
      (unless ldap-browser-callback
	(pop-to-buffer ldap-browser-buffer))
      (unless (equal change "finished\n")
	(error "ldapsearch: %s\n See buffer %s for details" change (process-buffer process))))))

(defun ldap-browser-search-fields (pattern fields &optional callback)
  "Fetch ldap entries filtered by FILTER on displayName.
You can use * as wildcard, but ensure that it's placed at the end of the string.
For obscure reasons, with a star at the beginning of the string the ldap query fails with a timeout..."
  (ldap-browser-clear)
  (ldap-browser-set-callback callback)
  (dolist (server ldap-servers)
    (with-current-buffer (get-buffer-create (format ldap-result-buffer-format (car server)))
      (erase-buffer)
      (let* ((filter (mapconcat (lambda(x)(format "(%s=%s)" x pattern)) fields ""))
	     (ldap-username (auth-source-user-or-password "login" server "ldap"))
	     (ldap-password (auth-source-user-or-password "password" server "ldap"))
	     (cmd (format "%s -h %s -D %s -b %s -w %s (|%s)" ldap-search-args (car server) ldap-username (cdr server) ldap-password filter)))
	(set-process-sentinel (apply 'start-process "ldapsearch" (current-buffer) "ldapsearch" (split-string cmd)) 'ldap-search-sentinel))
      )))

(defun ldap-browser-search-name (name &optional callback)
  "Search pattern in fields \"displayName\" and \"mail\""
  (interactive "sName: ")
  (ldap-browser-search-fields name '("displayName" "mail") callback))

(defun ldap-browser-insert-mail-callback (buffer contact)
  "To be used as a search callback to insert result's email in current buffer"
  (when contact
    (with-current-buffer buffer
      (insert (concat (assoc-default "mail" contact) " ")))))

(defun ldap-browser-insert-formatted-mail-callback (buffer contact)
  "To be used as a search callback to insert result's formatted email in current buffer"
  (when contact
    (with-current-buffer buffer
      (insert (format "\"%s\" <%s> " (assoc-default "displayName" contact) (assoc-default "mail" contact))))))

(defun ldap-browser-insert-mail (name)
  "Get a contact's email
If multiple results are found, ldap-browser buffer is opened to choose the right one by typing <Enter>"
  (interactive "sName: ")
  (ldap-browser-search-name name (curry 'ldap-browser-insert-mail-callback (current-buffer))))

(defun ldap-browser-insert-formatted-mail (name)
  "Insert mailer formatted contact's email
If multiple results are found, ldap-browser buffer is opened to choose the right one by typing <Enter>"
  (interactive "sName: ")
  (ldap-browser-search-name name (curry 'ldap-browser-insert-formatted-mail-callback (current-buffer))))

(defun def-ldap-browser-purple ()
  "Load purple plugins"
  (defun ldap-browser-add-purple-buddy-callback (contact)
    "Add selected contact to purple buddy list"
    (message "bla")
    (purple-buddy-add
     (purple-account-completing-read)
     (concat "sip:" (assoc-default "mail" contact))
     (read-string "Alias: " (assoc-default "displayName" contact))
     (purple-group-completing-read "Add into group: ")))
  (defun ldap-browser-add-purple-buddy (name)
    "Add selected contact to purple buddy list"
    (interactive "sName: ")
    (ldap-browser-search-name name 'ldap-browser-add-purple-buddy-callback)))
(eval-after-load "purple" '(def-ldap-browser-purple))

(provide 'ldap-browser)

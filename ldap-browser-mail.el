;;; ldap-browser-mail.el --- Mail completion with LDAP-browser

;; Copyright (C) 2014 Sylvain Chouleur

;; Author: Sylvain Chouleur <sylvain.chouleur@gmail.com>
;; Version: 0.1
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

(require 'ldap-browser)

(defun ldap-browser-insert-mail-callback (buffer contact)
  "To be used as a search callback to insert result's email in current buffer"
  (when contact
    (with-current-buffer buffer
      (insert (concat (assoc-default "mail" contact) " ")))))

(defun ldap-browser-insert-formatted-mail-callback (buffer contact)
  "To be used as a search callback to insert result's formatted email in current buffer"
  (when contact
    (with-current-buffer buffer
      (insert (format "\"%s\" <%s> " (assoc-default "cn" contact) (assoc-default "mail" contact))))))

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

(defun gnus-ldap-complete()
  (interactive)
  (let* ((bounds (bounds-of-thing-at-point 'word))
	 (pattern (concat (buffer-substring-no-properties (car bounds) (cdr bounds)) "*")))
    (delete-region (car bounds) (cdr bounds))
    (ldap-browser-insert-formatted-mail pattern)))

(eval-after-load "message"
  '(define-key message-mode-map (kbd "TAB") 'gnus-ldap-complete))

(provide 'ldap-browser-mail)

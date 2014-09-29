;;; ldap-browser-purple.el --- Purple interactions with LDAP

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

(provide 'ldap-browser-purple)

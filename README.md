LDAP browser
============

Overview
--------

This is an emacs tool to browse, or bind with other tools, one or more LDAP servers.

It uses [ldapsearch](http://www.openldap.org/software/man.cgi?query=ldapsearch&apropos=0&sektion=0&manpath=OpenLDAP+2.0-Release&format=html) to make asynchrone requests to LDAP servers and
agregate results to one interactive buffer `*ldap-browser*`

A callback can be set to execute specific action when search is done
and then bind the tool with others

Usage
-----
### Setup your ldap
  - `'ldap-username` is the binddn to bind to the LDAP directory
  - `'ldap-password` is the password corresponding to the binddn
  - `'ldap-servers` is a list of ldap servers with their base. Each
	  item of the list is a tuple composed of:
    - the ldap host
    - the ldap base to be used

### Search for contacts
  - <kbd>M-x ldap-browser-search-name</kbd> This will search for a given name
      on fields **displayName** and **mail**

Give a pattern containing eventually wildcards. The results will be
displayed in `*ldap-browser*` buffer.

### Navigate in the results
`*ldap-browser*` buffer is a tabulated list of contacts displaying
some fields determined by the variable `'ldap-browser-cols`.  
In this buffer you can do some interactions:

  - <kbd>g</kbd> : update buffer
  - <kbd>v</kbd> : view contact details in a dedicated buffer
  - <kbd>RET</kbd> : execute callback on contact (see next section)

### Interact with other tools
LDAP browser can be used by other tools by specifying a callback with a request which will be called when all queries are terminated and if there is only one result.  
If there is no result, an error is thrown.  
If there is more than one result, the `*ldap-browser*` buffer is opened to let the user select the appropriate contact by hitting <kbd>RET</kbd>.  
The function `ldap-browser-insert-mail` is an example which can be used by email clients.

TODO list
---------
  - Columns auto-resizing
  - Display on-going queries
  - Dynamic columns selector
  - Multi-results callbacks (to be bound with ido-mode)

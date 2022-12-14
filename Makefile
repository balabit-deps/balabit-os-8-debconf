MUNGE=xargs perl -i.bak -ne ' \
		print $$_."\# This file was preprocessed, do not edit!\n" \
			if m:^\#!/usr/bin/perl:; \
		$$cutting=1 if /^=/; \
		$$cutting="" if /^=cut/; \
		next if /use lib/; \
		next if $$cutting || /^(=|\s*\#)/; \
		print $$_ \
	'

all:
	$(MAKE) -C doc
	$(MAKE) -C po

clean:
	find . \( -name \*~ -o -name \*.pyc -o -name \*.pyo \) | xargs rm -f
	rm -rf __pycache__
	$(MAKE) -C doc clean
	$(MAKE) -C po clean

# Does not attempt to install documentation, as that can be fairly system
# specific.
install: install-utils install-python3 install-rest

# Anything that goes in the debconf-utils package.
install-utils:
	install -d $(prefix)/usr/bin
	find . -maxdepth 1 -perm /100 -type f -name 'debconf-*' | grep -v debconf-set-selections | grep -v debconf-show | grep -v debconf-copydb | grep -v debconf-communicate | grep -v debconf-apt-progress | grep -v debconf-escape | \
		xargs -i install {} $(prefix)/usr/bin

# Anything that goes in the debconf-i18n package.
install-i18n:
	$(MAKE) -C po install

PERL := perl
PERL_VENDORLIB := $(shell $(PERL) -MConfig -e 'print $$Config{vendorlib}')

# The Python 3 package.
install-python3:
	install -d $(prefix)/usr/lib/python3/dist-packages
	install -m 0644 debconf.py $(prefix)/usr/lib/python3/dist-packages/

# Install all else.
install-rest:
	install -d $(prefix)/etc \
		$(prefix)/var/cache/debconf \
		$(prefix)/usr/share/debconf \
		$(prefix)/usr/share/pixmaps
	install -m 0644 debconf.conf $(prefix)/etc/
	install -m 0644 debian-logo.png $(prefix)/usr/share/pixmaps/
	# This one is the ultimate backup copy.
	grep -v '^#' debconf.conf > $(prefix)/usr/share/debconf/debconf.conf
	# Make module directories.
	find Debconf -type d |grep -v CVS | \
		xargs -i install -d $(prefix)/$(PERL_VENDORLIB)/{}
	# Install modules.
	find Debconf -type f -name '*.pm' |grep -v CVS | \
		xargs -i install -m 0644 {} $(prefix)/$(PERL_VENDORLIB)/{}
	# Special case for back-compatability.
	install -d $(prefix)/$(PERL_VENDORLIB)/Debian/DebConf/Client
	cp Debconf/Client/ConfModule.stub \
		$(prefix)/$(PERL_VENDORLIB)/Debian/DebConf/Client/ConfModule.pm
	# Other libs and helper stuff.
	install -m 0644 confmodule.sh confmodule $(prefix)/usr/share/debconf/
	install frontend $(prefix)/usr/share/debconf/
	install -m 0755 transition_db.pl fix_db.pl $(prefix)/usr/share/debconf/
	# Install essential programs.
	install -d $(prefix)/usr/sbin $(prefix)/usr/bin
	find . -maxdepth 1 -perm /100 -type f -name 'dpkg-*' | \
		xargs -i install {} $(prefix)/usr/sbin
	find . -maxdepth 1 -perm /100 -type f -name debconf -or -name debconf-show -or -name debconf-copydb -or -name debconf-communicate -or -name debconf-set-selections -or -name debconf-apt-progress -or -name debconf-escape | \
		xargs -i install {} $(prefix)/usr/bin
	# Now strip all pod documentation from all .pm files and scripts.
	find $(prefix)/$(PERL_VENDORLIB)/ $(prefix)/usr/sbin		\
	     $(prefix)/usr/share/debconf/frontend 			\
	     $(prefix)/usr/share/debconf/*.pl $(prefix)/usr/bin		\
	     -name '*.pl' -or -name '*.pm' -or -name 'dpkg-*' -or	\
	     -name 'debconf-*' -or -name 'frontend' | 			\
	     grep -v Client/ConfModule | $(MUNGE)
	find $(prefix) -name '*.bak' | xargs rm -f

demo:
	PERL5LIB=. ./frontend samples/demo

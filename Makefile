SUBDIRS = po src shtml lib bin linbo
EXTRA_DIST = config/config.guess config/config.rpath config/config.sub \
	config/depcomp config/install-sh config/missing config/mkinstalldirs \
	m4/ChangeLog \
	doc/etc/schulkonsole/permissions.conf \
	doc/etc/apache2/sites-available/schulkonsole

ACLOCAL_AMFLAGS = -I m4

include ../../common.mk

BUILDDIR = build
SOURCEDIR = .
EXECDIR = $(LIBDIR)/bin

SCRIPTS = $(wildcard $(SOURCEDIR)/*.pl)
SOURCES = $(wildcard $(SOURCEDIR)/*.c)
OBJECTS = $(patsubst $(SOURCEDIR)/%.c, $(BUILDDIR)/%.o, $(SOURCES))
BINARIES= $(patsubst $(SOURCEDIR)/%.c, $(BUILDDIR)/%, $(SOURCES))

build: setup $(BINARIES)

$(BUILDDIR)/%: $(BUILDDIR)/%.o
	$(CC) $(CFLAGS) -I$(SOURCEDIR) $< -o $@
	chmod -f 4755 $@

$(BUILDDIR)/%.o: $(SOURCEDIR)/%.c setup
	$(CC) $(CFLAGS) -c $< -o $@

setup:
	$(MKDIR) -p $(BUILDDIR)
	$(MKDIR) -p $(DESTDIR)$(EXECDIR)

install_bin: build
	for datei in $(patsubst $(BUILDDIR)/%,%,$(BINARIES)) ; do \
	    $(INSTALL) -m 4755 -o 0 -g 0 $(BUILDDIR)/$$datei $(DESTDIR)$(EXECDIR)/$$datei ; \
	done

install_script: $(SCRIPTS)
	for datei in $(SCRIPTS) ; do \
	    $(INSTALL) -m 755 -o 0 -g 0 $$datei $(DESTDIR)$(EXECDIR)/$$datei ; \
	done

install: install_bin install_script

clean:
	$(RM) $(BINARIES) $(OBJECTS)
	$(RM) -r $(BUILDDIR)

distclean: clean

help:
	@$(ECHO) "Targets:"
	@$(ECHO) "all     - buildcompile what is necessary"
	@$(ECHO) "clean   - cleanup old .o and binaries"
	@$(ECHO) "install - not yet fully supported"

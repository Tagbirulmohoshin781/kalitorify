PROGRAM_NAME = kalitorify
VERSION = 1.30.0

DESTDIR ?=
PREFIX ?= /usr
BINDIR ?= $(PREFIX)/bin
DATADIR ?= $(PREFIX)/share/$(PROGRAM_NAME)
DOCDIR ?= $(PREFIX)/share/doc/$(PROGRAM_NAME)
LIBDIR ?= /var/lib/$(PROGRAM_NAME)

.PHONY: all install uninstall reinstall check clean

all:
	@echo "Nothing to compile. Run 'sudo make install' to install $(PROGRAM_NAME)."

install:
	install -d $(DESTDIR)$(BINDIR)
	install -d $(DESTDIR)$(DATADIR)/data
	install -d $(DESTDIR)$(DOCDIR)
	install -d $(DESTDIR)$(LIBDIR)/backups
	install -m 755 kalitorify.sh $(DESTDIR)$(BINDIR)/$(PROGRAM_NAME)
	install -m 644 README.md $(DESTDIR)$(DOCDIR)/README.md
	install -m 644 data/* $(DESTDIR)$(DATADIR)/data/

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/$(PROGRAM_NAME)
	rm -rf $(DESTDIR)$(DATADIR)
	rm -rf $(DESTDIR)$(DOCDIR)
	rm -rf $(DESTDIR)$(LIBDIR)

reinstall: uninstall install

check:
	bash -n kalitorify.sh

clean:
	@echo "Clean completed."

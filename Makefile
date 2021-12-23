
DESTDIR ?= $(HOME)/bin
APPLICATIONS=\
	fillipo mactoip translight whatsip git-crew git-fuse git-save

help:
	@echo "Usage:"
	@echo " make help"
	@echo "  print this usage"
	@echo " make install [DESTDIR=PATH]"
	@echo "  install applications and their bash completions into DESTDIR (default: $(DESTDIR))"

install:
	@echo "Creating directories..."
	@mkdir -v -p $(DESTDIR)/core
	@echo
	@echo "Installing core components..."
	@find $(CURDIR)/core -maxdepth 1 -type f -exec install -v {} $(DESTDIR)/core/ ';'
	@echo
	@echo "Installing applications..."
	@for app in $(APPLICATIONS); do \
		install -v $(CURDIR)/$$app $(DESTDIR)/; \
	done
	@echo
	@echo "Installing bash completions..."
	@for app in $(APPLICATIONS); do \
		$(DESTDIR)/$$app complement; \
	done
	@echo
	@echo "Done."

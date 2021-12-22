
DESTDIR ?= $(HOME)/bin

help:
	@echo "Usage:"
	@echo " make help"
	@echo "  print this usage"
	@echo " make install [DESTDIR=PATH]"
	@echo "  install utilities and their bash completions into DESTDIR (default: $(DESTDIR))"

install:
	@echo "Creating directories..."
	@mkdir -v -p $(DESTDIR)/core
	@echo
	@echo "Installing core components..."
	@find $(CURDIR)/core -maxdepth 1 -type f -exec install -v {} $(DESTDIR)/core/ ';'
	@echo
	@echo "Installing utilities..."
	@for app in fillipo mactoip translight whatsip git-review git-save; do \
		install -v $(CURDIR)/$$app $(DESTDIR)/; \
	done
	@echo
	@echo "Installing bash completions..."
	@for app in fillipo mactoip translight git-review git-save; do \
		$(DESTDIR)/$$app complement; \
	done
	@echo
	@echo "Done."

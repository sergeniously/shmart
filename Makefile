
SHMART_APPS=\
	locale \
	mactoip \
	translight \
	whatsip \

GIT_APPS=\
	git-crew \
	git-fuse \
	git-save \

help:
	@echo "Usage:"
	@echo " make help"
	@echo "  print this usage"
	@echo " make install"
	@echo "  symbolically link applications into PATH"
	@echo "  and setup their auto completions"

install:
	@echo "Installing shmart applications ..."
	@for app in $(SHMART_APPS); do \
		$(CURDIR)/$$app.sh setup shmart-$$app; \
	done
	@echo
	@echo "Installing git applications ..."
	@for app in $(GIT_APPS); do \
		$(CURDIR)/$$app.sh setup $$app; \
	done
	@echo
	@echo "Done."

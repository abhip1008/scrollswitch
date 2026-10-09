# ScrollSwitch build. See docs/ScrollSwitch-Spec.md for what this app does.

SHELL     := /bin/bash
SWIFT     ?= swift
CONFIG    ?= release
APP       := dist/ScrollSwitch.app
BUNDLE_ID := com.abhirampurohit.ScrollSwitch
BIN       := .build/$(CONFIG)/ScrollSwitch
INSTALLED := /Applications/ScrollSwitch.app

.PHONY: all help build test spike status app bundle install uninstall clean

all: app

help:
	@echo "make build      compile everything"
	@echo "make test       run the unit tests"
	@echo "make spike      Milestone 0: flip scrolling live, then restore"
	@echo "make status     report whether the private API resolved"
	@echo "make app        build dist/ScrollSwitch.app"
	@echo "make install    install into /Applications and launch"
	@echo "make uninstall  quit and remove the installed app"
	@echo "make clean      discard build products"

build:
	$(SWIFT) build -c $(CONFIG)

test:
	$(SWIFT) test

# Milestone 0. Scroll something during the 5 second window.
spike:
	$(SWIFT) run scrollswitch-spike

status:
	$(SWIFT) run scrollswitch-spike --status

app: build bundle

# SwiftPM emits a bare Mach-O binary. A menu bar app needs a real bundle so that
# LSUIElement, the bundle identifier (UserNotifications, SMAppService) and the code
# signature are all in place.
bundle:
	@mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp $(BIN) $(APP)/Contents/MacOS/ScrollSwitch
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	printf "APPL????" > $(APP)/Contents/PkgInfo
	plutil -lint $(APP)/Contents/Info.plist
	codesign --force --options runtime --identifier $(BUNDLE_ID) --sign - $(APP)
	codesign --verify --verbose=2 $(APP)
	@echo "built $(APP)"

# Replaces the copy in /Applications and relaunches it.
install: app
	-pkill -x ScrollSwitch
	$(RM) -r $(INSTALLED)
	cp -R $(APP) $(INSTALLED)
	open $(INSTALLED)

uninstall:
	-pkill -x ScrollSwitch
	$(RM) -r $(INSTALLED)

clean:
	$(RM) -r .build dist

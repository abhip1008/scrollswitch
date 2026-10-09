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
	@echo "make doctor     check everything a terminal can check"
	@echo "make agent      also install a LaunchAgent that restarts it after a crash"
	@echo "make unagent    remove that LaunchAgent"

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
bundle: build
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
	-launchctl bootout gui/$(shell id -u)/com.abhirampurohit.ScrollSwitch
	$(RM) $(HOME)/Library/LaunchAgents/com.abhirampurohit.ScrollSwitch.plist
	-pkill -x ScrollSwitch
	$(RM) -r $(INSTALLED)

clean:
	$(RM) -r .build dist

# One command that checks everything a terminal can check. Dock/undock and the five-second
# scroll test are yours -- see docs/TESTING.md.
doctor: build test
	@echo ""
	@echo "== Milestone 0: the private scroll API =="
	-$(SWIFT) run scrollswitch-spike --status
	@echo ""
	@echo "== Stored system value =="
	@printf "com.apple.swipescrolldirection = "
	@defaults read -g com.apple.swipescrolldirection || echo "unset (macOS default is natural)"
	@echo ""
	@echo "== Installed app =="
	@test -d $(INSTALLED) && echo "present at $(INSTALLED)" || echo "NOT installed -- run: make install"
	@echo ""
	@echo "== Running right now =="
	@pgrep -x ScrollSwitch > /dev/null && echo "yes, ScrollSwitch is running" || echo "no, ScrollSwitch is not running"
	@echo ""
	@echo "== Launch at login =="
	@echo "Open the menu bar icon, Preferences..., Status tab. It must read Enabled."
	@echo "If it reads Waiting for approval, approve it in"
	@echo "System Settings > General > Login Items and Extensions."

# Optional belt-and-braces autostart. The SMAppService login item only starts the app at
# login; this LaunchAgent also relaunches it within a second if it ever crashes.
# Turn OFF Launch at login in Preferences first, or both will try to start it.
AGENT_LABEL := com.abhirampurohit.ScrollSwitch
AGENT_PLIST := $(HOME)/Library/LaunchAgents/$(AGENT_LABEL).plist

.PHONY: agent unagent doctor

agent: install
	@mkdir -p $(HOME)/Library/LaunchAgents
	cp Resources/$(AGENT_LABEL).plist $(AGENT_PLIST)
	plutil -lint $(AGENT_PLIST)
	-launchctl bootout gui/$(shell id -u)/$(AGENT_LABEL)
	launchctl bootstrap gui/$(shell id -u) $(AGENT_PLIST)
	@echo "LaunchAgent loaded. Turn OFF Launch at login in Preferences to avoid a double start."

unagent:
	-launchctl bootout gui/$(shell id -u)/$(AGENT_LABEL)
	$(RM) $(AGENT_PLIST)
	@echo "LaunchAgent removed."

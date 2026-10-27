# ScrollSwitch build. SwiftPM builds the binaries; this assembles and signs the .app.
#
#   make app        build/ScrollSwitch.app (release, ad-hoc signed)
#   make install    copy to /Applications and launch it
#   make test       unit tests
#   make spike      Phase 0 live-toggle spike (flips Natural scrolling once)
#   make cli        build scrollswitch-cli
#   make uninstall  quit, remove the login item and /Applications/ScrollSwitch.app

APP_NAME     := ScrollSwitch
BUNDLE_ID    := com.abhirampurohit.scrollswitch
CONFIG       ?= release
BUILD_DIR    := build
APP          := $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR  ?= /Applications
SIGN_ID      ?= -
BIN_DIR       = $(shell swift build -c $(CONFIG) --show-bin-path)

.PHONY: all build app install uninstall run test cli spike icon clean

all: app

build:
	swift build -c $(CONFIG) --product $(APP_NAME)

app: build
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp "$(BIN_DIR)/$(APP_NAME)" "$(APP)/Contents/MacOS/$(APP_NAME)"
	cp Resources/Info.plist "$(APP)/Contents/Info.plist"
	cp Resources/AppIcon.icns "$(APP)/Contents/Resources/AppIcon.icns"
	printf 'APPL????' > "$(APP)/Contents/PkgInfo"
	codesign --force --sign "$(SIGN_ID)" --options runtime \
		--entitlements Resources/ScrollSwitch.entitlements --identifier $(BUNDLE_ID) "$(APP)"
	codesign --verify --strict "$(APP)"
	@echo "Built $(APP)"

install: app
	-osascript -e 'tell application id "$(BUNDLE_ID)" to quit' >/dev/null 2>&1
	-pkill -x $(APP_NAME) ; sleep 1
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	ditto "$(APP)" "$(INSTALL_DIR)/$(APP_NAME).app"
	open "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME).app"

uninstall:
	-"$(INSTALL_DIR)/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" --unregister-login-item >/dev/null 2>&1
	-pkill -x $(APP_NAME)
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Removed. Settings remain in ~/Library/Preferences/$(BUNDLE_ID).plist"

run: app
	open "$(APP)"

test:
	swift test

cli:
	swift build -c $(CONFIG) --product scrollswitch-cli
	@echo "$(BIN_DIR)/scrollswitch-cli"

spike:
	mkdir -p Spike/bin
	swiftc Spike/toggle-test.swift -o Spike/bin/toggle-test
	swiftc Spike/display-watch.swift -o Spike/bin/display-watch
	swiftc Spike/backup-a-test.swift -o Spike/bin/backup-a-test
	Spike/bin/toggle-test

icon:
	rm -rf $(BUILD_DIR)/AppIcon.iconset
	swift scripts/make-icon.swift $(BUILD_DIR)/AppIcon.iconset
	iconutil -c icns $(BUILD_DIR)/AppIcon.iconset -o Resources/AppIcon.icns

clean:
	rm -rf .build $(BUILD_DIR) Spike/bin

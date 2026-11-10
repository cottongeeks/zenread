# Build and install mac-reader: the Mac Reader app, with its binary also on PATH as a CLI.
PREFIX ?= $(HOME)/bin
APPDIR ?= /Applications
VERSION ?= 0.1.0
BUILD_NUMBER ?= $(shell git rev-list --count HEAD 2>/dev/null || echo 1)
# A Developer ID identity signs for distribution; "-" signs ad hoc, which is enough for this Mac.
SIGN_IDENTITY ?= -
# Built one architecture at a time and joined with lipo, which needs no more than the
# Command Line Tools.
ARCHS ?= arm64 x86_64

APP_NAME = Mac Reader
APP = build/$(APP_NAME).app

.PHONY: build debug app install uninstall icon test fmt lint clean

build:
	swift build -c release

debug:
	swift build

# A universal, signed build/Mac Reader.app. Each architecture builds into the same products
# folder, so its binary is copied out before the next one builds.
app:
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	for arch in $(ARCHS); do \
		swift build -c release --arch $$arch && \
		cp "$$(swift build -c release --arch $$arch --show-bin-path)/mac-reader" \
			"build/mac-reader-$$arch" || exit 1; \
	done
	lipo -create $(foreach arch,$(ARCHS),build/mac-reader-$(arch)) \
		-output "$(APP)/Contents/MacOS/mac-reader"
	rm -f $(foreach arch,$(ARCHS),build/mac-reader-$(arch))
	cp App/Info.plist "$(APP)/Contents/Info.plist"
	plutil -replace CFBundleShortVersionString -string "$(VERSION)" "$(APP)/Contents/Info.plist"
	plutil -replace CFBundleVersion -string "$(BUILD_NUMBER)" "$(APP)/Contents/Info.plist"
	printf 'APPL????' > "$(APP)/Contents/PkgInfo"
	cp App/Assets.car App/AppIcon.icns "$(APP)/Contents/Resources/"
	codesign --force --options runtime $(if $(filter -,$(SIGN_IDENTITY)),,--timestamp) \
		--sign "$(SIGN_IDENTITY)" "$(APP)"
	codesign --verify --strict "$(APP)"

# The app goes in APPDIR, and PREFIX gets a mac-reader command for the terminal. That is a
# script that execs the app's binary rather than a symlink to it: macOS only treats the
# process as the app (its name, icon and bundle ID) when the binary runs from its real path.
# The old file is removed first, so writing the script never follows a symlink into the app.
install: app
	mkdir -p "$(APPDIR)" "$(PREFIX)"
	rm -rf "$(APPDIR)/$(APP_NAME).app"
	ditto "$(APP)" "$(APPDIR)/$(APP_NAME).app"
	rm -f "$(PREFIX)/mac-reader"
	printf '#!/bin/sh\nexec "%s" "$$@"\n' "$(APPDIR)/$(APP_NAME).app/Contents/MacOS/mac-reader" \
		> "$(PREFIX)/mac-reader"
	chmod 755 "$(PREFIX)/mac-reader"

uninstall:
	rm -rf "$(APPDIR)/$(APP_NAME).app"
	rm -f "$(PREFIX)/mac-reader"

# Recompiles App/Assets.car and App/AppIcon.icns from App/AppIcon.icon. Needs Xcode 26 or
# later; the results are committed so `make app` does not. actool resolves relative paths
# against its daemon's directory, so every path is absolute.
icon:
	mkdir -p build
	xcrun actool "$(CURDIR)/App/AppIcon.icon" --compile "$(CURDIR)/App" \
		--app-icon AppIcon --include-all-app-icons --platform macosx --target-device mac \
		--minimum-deployment-target 14.0 --enable-on-demand-resources NO \
		--development-region en --output-format human-readable-text --errors --warnings \
		--output-partial-info-plist "$(CURDIR)/build/icon-partial.plist"
	rm -f build/icon-partial.plist

test:
	swift test

fmt:
	swift format -i -r Sources Tests Package.swift

lint:
	swift format lint -r -s Sources Tests Package.swift

clean:
	rm -rf .build build

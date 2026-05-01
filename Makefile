APP_NAME = Apple Mail AI Plugin
BUNDLE_NAME = AIMailComposer
BUNDLE_ID = com.aiMailComposer
VERSION = 0.1.0
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
EXECUTABLE = $(APP_BUNDLE)/Contents/MacOS/$(BUNDLE_NAME)
# Set to your Developer ID for distribution, or leave empty for ad-hoc
SIGNING_IDENTITY ?=
# Set to your Apple ID for notarization
APPLE_ID ?=
TEAM_ID ?=

.PHONY: build run clean release dmg sign notarize release-dmg install uninstall

# Development build
build:
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	xcodebuild -scheme $(BUNDLE_NAME) \
		-configuration Debug \
		-destination 'platform=macOS' \
		-derivedDataPath $(BUILD_DIR)/DerivedData \
		build
	@cp $(BUILD_DIR)/DerivedData/Build/Products/Debug/$(BUNDLE_NAME) "$(EXECUTABLE)"
	@cp AIMailComposer/Resources/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/"
	@cp AIMailComposer/App/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	@# Merge additional keys into Info.plist
	@/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $(BUNDLE_ID)" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $(BUNDLE_NAME)" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :CFBundleName string $(APP_NAME)" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $(APP_NAME)" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $(VERSION)" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :NSPrincipalClass string NSApplication" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@echo "\n✅ Built: $(APP_BUNDLE)"

# Release build (optimized)
release:
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	xcodebuild -scheme $(BUNDLE_NAME) \
		-configuration Release \
		-destination 'platform=macOS' \
		-derivedDataPath $(BUILD_DIR)/DerivedData \
		build
	@cp $(BUILD_DIR)/DerivedData/Build/Products/Release/$(BUNDLE_NAME) "$(EXECUTABLE)"
	@cp AIMailComposer/Resources/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/"
	@cp AIMailComposer/App/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	@/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $(BUNDLE_ID)" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $(BUNDLE_NAME)" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :CFBundleName string $(APP_NAME)" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $(APP_NAME)" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $(VERSION)" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :NSPrincipalClass string NSApplication" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@echo "\n✅ Release built: $(APP_BUNDLE)"

# Code sign (for distribution outside App Store)
sign: release
	@if [ -z "$(SIGNING_IDENTITY)" ]; then \
		echo "⚠️  No SIGNING_IDENTITY set. Ad-hoc signing..."; \
		codesign --force --deep --sign - \
			--entitlements AIMailComposer/Entitlements/AIMailComposer.entitlements \
			"$(APP_BUNDLE)"; \
	else \
		echo "Signing with: $(SIGNING_IDENTITY)"; \
		codesign --force --deep --options runtime \
			--sign "$(SIGNING_IDENTITY)" \
			--entitlements AIMailComposer/Entitlements/AIMailComposer.entitlements \
			"$(APP_BUNDLE)"; \
	fi
	@echo "✅ Signed: $(APP_BUNDLE)"

# Notarize (requires Apple Developer account)
notarize: sign
	@if [ -z "$(APPLE_ID)" ] || [ -z "$(TEAM_ID)" ]; then \
		echo "❌ Set APPLE_ID and TEAM_ID for notarization"; \
		echo "   make notarize SIGNING_IDENTITY='Developer ID Application: ...' APPLE_ID=you@example.com TEAM_ID=ABC123"; \
		exit 1; \
	fi
	@echo "Creating ZIP for notarization..."
	@ditto -c -k --keepParent "$(APP_BUNDLE)" "$(BUILD_DIR)/$(BUNDLE_NAME).zip"
	@if [ -n "$(KEYCHAIN_PROFILE)" ]; then \
		xcrun notarytool submit "$(BUILD_DIR)/$(BUNDLE_NAME).zip" \
			--keychain-profile "$(KEYCHAIN_PROFILE)" --wait; \
	elif [ -n "$(APP_PASSWORD)" ]; then \
		xcrun notarytool submit "$(BUILD_DIR)/$(BUNDLE_NAME).zip" \
			--apple-id "$(APPLE_ID)" --team-id "$(TEAM_ID)" \
			--password "$(APP_PASSWORD)" --wait; \
	else \
		echo "❌ Set KEYCHAIN_PROFILE (recommended) or APP_PASSWORD"; \
		echo "   Recommended: xcrun notarytool store-credentials AC_PASSWORD --apple-id ... --team-id ... --password ..."; \
		echo "   Then: make notarize SIGNING_IDENTITY='...' APPLE_ID=... TEAM_ID=... KEYCHAIN_PROFILE=AC_PASSWORD"; \
		exit 1; \
	fi
	xcrun stapler staple "$(APP_BUNDLE)"
	@echo "✅ Notarized and stapled: $(APP_BUNDLE)"

# Create DMG for distribution (styled with drag-to-Applications layout)
dmg: sign
	@rm -f "$(BUILD_DIR)/$(BUNDLE_NAME).dmg"
	./scripts/create-dmg.sh "$(APP_NAME)" "$(APP_BUNDLE)" "$(BUILD_DIR)/$(BUNDLE_NAME).dmg"
	@echo "✅ DMG created: $(BUILD_DIR)/$(BUNDLE_NAME).dmg"

# Full distribution build: sign → notarize → staple → DMG → sign DMG → notarize DMG
release-dmg: notarize
	@rm -f "$(BUILD_DIR)/$(BUNDLE_NAME).dmg"
	./scripts/create-dmg.sh "$(APP_NAME)" "$(APP_BUNDLE)" "$(BUILD_DIR)/$(BUNDLE_NAME).dmg"
	codesign --force --sign "$(SIGNING_IDENTITY)" "$(BUILD_DIR)/$(BUNDLE_NAME).dmg"
	@if [ -n "$(KEYCHAIN_PROFILE)" ]; then \
		xcrun notarytool submit "$(BUILD_DIR)/$(BUNDLE_NAME).dmg" \
			--keychain-profile "$(KEYCHAIN_PROFILE)" --wait; \
	else \
		xcrun notarytool submit "$(BUILD_DIR)/$(BUNDLE_NAME).dmg" \
			--apple-id "$(APPLE_ID)" --team-id "$(TEAM_ID)" \
			--password "$(APP_PASSWORD)" --wait; \
	fi
	xcrun stapler staple "$(BUILD_DIR)/$(BUNDLE_NAME).dmg"
	@echo "✅ Distribution-ready DMG: $(BUILD_DIR)/$(BUNDLE_NAME).dmg"

# Build and run
run: build
	@open "$(APP_BUNDLE)"

# Install to /Applications
install: sign
	@rm -rf "/Applications/$(APP_NAME).app"
	@cp -R "$(APP_BUNDLE)" "/Applications/$(APP_NAME).app"
	@echo "✅ Installed to /Applications/$(APP_NAME).app"

# Uninstall from /Applications
uninstall:
	@rm -rf "/Applications/$(APP_NAME).app"
	@echo "✅ Removed /Applications/$(APP_NAME).app"

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	@echo "✅ Cleaned"

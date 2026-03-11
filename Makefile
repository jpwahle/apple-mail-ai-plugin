APP_NAME = AI Mail Composer
BUNDLE_NAME = AIMailComposer
BUNDLE_ID = com.aiMailComposer
VERSION = 1.0.0
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
EXECUTABLE = $(APP_BUNDLE)/Contents/MacOS/$(BUNDLE_NAME)
# Set to your Developer ID for distribution, or leave empty for ad-hoc
SIGNING_IDENTITY ?=
# Set to your Apple ID for notarization
APPLE_ID ?=
TEAM_ID ?=

.PHONY: build run clean release dmg sign notarize

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
	xcrun notarytool submit "$(BUILD_DIR)/$(BUNDLE_NAME).zip" \
		--apple-id "$(APPLE_ID)" \
		--team-id "$(TEAM_ID)" \
		--wait
	xcrun stapler staple "$(APP_BUNDLE)"
	@echo "✅ Notarized and stapled: $(APP_BUNDLE)"

# Create DMG for distribution
dmg: sign
	@rm -f "$(BUILD_DIR)/$(BUNDLE_NAME).dmg"
	hdiutil create -volname "$(APP_NAME)" \
		-srcfolder "$(APP_BUNDLE)" \
		-ov -format UDZO \
		"$(BUILD_DIR)/$(BUNDLE_NAME).dmg"
	@echo "✅ DMG created: $(BUILD_DIR)/$(BUNDLE_NAME).dmg"

# Build and run
run: build
	@open "$(APP_BUNDLE)"

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	@echo "✅ Cleaned"

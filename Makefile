.PHONY: generate build build-release lint format clean open test

# Default simulator destination
SIMULATOR ?= iPhone 16

generate:
	@echo "Generating Xcode project..."
	xcodegen generate

build: generate
	@echo "Building for simulator..."
	xcodebuild -scheme SeerApp \
		-destination 'platform=iOS Simulator,name=$(SIMULATOR)' \
		-configuration Debug \
		build

build-release: generate
	@echo "Building for release..."
	xcodebuild -scheme SeerApp \
		-destination 'generic/platform=iOS' \
		-configuration Release \
		build

lint:
	@echo "Running SwiftLint..."
	swiftlint lint --strict

format:
	@echo "Formatting code..."
	swiftformat .

clean:
	@echo "Cleaning..."
	rm -rf build/ DerivedData/ *.xcodeproj
	xcodebuild clean 2>/dev/null || true

open: generate
	@echo "Opening Xcode project..."
	open SeerApp.xcodeproj

test: generate
	@echo "Running tests..."
	xcodebuild -scheme SeerApp \
		-destination 'platform=iOS Simulator,name=$(SIMULATOR)' \
		-configuration Debug \
		test

# Install development dependencies
setup:
	@echo "Installing dependencies..."
	brew install xcodegen swiftlint swiftformat || true

# Resolve Swift packages
resolve: generate
	@echo "Resolving packages..."
	xcodebuild -resolvePackageDependencies -scheme SeerApp

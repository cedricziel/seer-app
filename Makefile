.PHONY: generate build build-release lint format clean open test bump-build bump-patch bump-minor bump-major version

# Default simulator destination
SIMULATOR ?= iPhone 17

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

# Version management
bump-build:
	@./scripts/bump-build.sh

bump-patch:
	@./scripts/bump-version.sh --patch

bump-minor:
	@./scripts/bump-version.sh --minor

bump-major:
	@./scripts/bump-version.sh --major

version:
	@echo "Version: $$(grep -E '^\s+MARKETING_VERSION:' project.yml | head -1 | sed 's/.*MARKETING_VERSION:\s*//' | tr -d ' \"') (Build $$(grep -E '^\s+CURRENT_PROJECT_VERSION:' project.yml | head -1 | sed 's/.*CURRENT_PROJECT_VERSION:\s*//' | tr -d ' '))"

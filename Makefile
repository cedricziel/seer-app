.PHONY: generate build build-release lint format clean open test bump-build bump-patch bump-minor bump-major version \
        fastlane-install fastlane-test fastlane-build fastlane-beta fastlane-release fastlane-match fastlane-bootstrap-signing

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

# Fastlane
#
# Lanes read configuration from fastlane/.env (gitignored) or from environment
# variables already set in your shell / CI. See fastlane/.env.example for the
# variables required by each lane.
fastlane-install:
	@echo "Installing fastlane via bundler..."
	bundle config set --local path 'vendor/bundle'
	bundle install

fastlane-test: generate
	bundle exec fastlane test

fastlane-build: generate
	bundle exec fastlane build

fastlane-beta: generate
	bundle exec fastlane beta

fastlane-release: generate
	bundle exec fastlane release

fastlane-match: generate
	bundle exec fastlane sync_signing type:$${TYPE:-development}

fastlane-bootstrap-signing: generate
	bundle exec fastlane bootstrap_signing

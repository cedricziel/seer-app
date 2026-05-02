.PHONY: generate build build-release lint format clean open test version \
        fastlane-install fastlane-test fastlane-build fastlane-beta fastlane-release fastlane-match fastlane-bootstrap-signing \
        fastlane-sync-metadata \
        _ensure-brew-ruby

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
	brew install xcodegen swiftlint swiftformat ruby || true

# Resolve Swift packages
resolve: generate
	@echo "Resolving packages..."
	xcodebuild -resolvePackageDependencies -scheme SeerApp

# Version: marketing version comes from project.yml (managed by release-please);
# build number comes from `git rev-list --count HEAD` at archive time.
version:
	@MV=$$(grep -E '^\s+MARKETING_VERSION:' project.yml | head -1 | sed 's/.*MARKETING_VERSION:\s*//' | sed 's/#.*//' | tr -d ' \"'); \
	BN=$$(git rev-list --count HEAD); \
	echo "Version: $$MV (Build $$BN)"

# Fastlane
#
# Lanes read configuration from fastlane/.env (gitignored) or from environment
# variables already set in your shell / CI. See fastlane/.env.example for the
# variables required by each lane.
#
# Locally we always use the bundler shipped with Homebrew Ruby. The macOS
# system Ruby (2.6) frequently fails to install fastlane's native gems.
BREW_RUBY_PREFIX := $(shell brew --prefix ruby 2>/dev/null)
BUNDLE           := $(BREW_RUBY_PREFIX)/bin/bundle

_ensure-brew-ruby:
	@if [ -z "$(BREW_RUBY_PREFIX)" ] || [ ! -x "$(BUNDLE)" ]; then \
		echo "ERROR: Homebrew Ruby is required for fastlane targets."; \
		echo "       Install with: brew install ruby (or run: make setup)"; \
		exit 1; \
	fi

fastlane-install: _ensure-brew-ruby
	@echo "Installing fastlane via $(BUNDLE)..."
	$(BUNDLE) config set --local path 'vendor/bundle'
	$(BUNDLE) install

fastlane-test: _ensure-brew-ruby generate
	$(BUNDLE) exec fastlane test

fastlane-build: _ensure-brew-ruby generate
	$(BUNDLE) exec fastlane build

fastlane-beta: _ensure-brew-ruby generate
	$(BUNDLE) exec fastlane beta

fastlane-release: _ensure-brew-ruby generate
	$(BUNDLE) exec fastlane release

fastlane-match: _ensure-brew-ruby generate
	$(BUNDLE) exec fastlane sync_signing type:$${TYPE:-development}

fastlane-bootstrap-signing: _ensure-brew-ruby generate
	$(BUNDLE) exec fastlane bootstrap_signing

fastlane-sync-metadata: _ensure-brew-ruby
	$(BUNDLE) exec fastlane sync_metadata

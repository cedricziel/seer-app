#!/bin/bash
# SessionStart hook for Claude Code on the web.
#
# Installs Linux binaries of the same SwiftLint and SwiftFormat versions the
# CI lint job uses, so `make lint`, `swiftlint`, and `swiftformat` all work
# inside the remote sandbox. iOS builds and tests still require macOS, so
# we deliberately do not try to install xcodegen / xcodebuild here.
set -euo pipefail

# Only run inside the remote (Claude Code on the web) sandbox.  Local macOS
# developers should use `make setup` (Homebrew) instead.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
    exit 0
fi

SWIFTLINT_VERSION="0.63.2"
SWIFTFORMAT_VERSION="0.61.1"

BIN_DIR="/usr/local/bin"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)
        SWIFTLINT_ASSET="swiftlint_linux_amd64.zip"
        SWIFTFORMAT_ASSET="swiftformat_linux.zip"
        SWIFTFORMAT_BIN_NAME="swiftformat_linux"
        ;;
    aarch64 | arm64)
        SWIFTLINT_ASSET="swiftlint_linux_arm64.zip"
        SWIFTFORMAT_ASSET="swiftformat_linux_aarch64.zip"
        SWIFTFORMAT_BIN_NAME="swiftformat_linux_aarch64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH" >&2
        exit 1
        ;;
esac

install_swiftlint() {
    if command -v swiftlint >/dev/null 2>&1 \
        && [ "$(swiftlint --version 2>/dev/null)" = "$SWIFTLINT_VERSION" ]; then
        echo "swiftlint $SWIFTLINT_VERSION already installed"
        return 0
    fi

    echo "Installing swiftlint $SWIFTLINT_VERSION..."
    local url="https://github.com/realm/SwiftLint/releases/download/${SWIFTLINT_VERSION}/${SWIFTLINT_ASSET}"
    curl -fsSL --retry 3 "$url" -o "$TMP_DIR/swiftlint.zip"
    unzip -q -o "$TMP_DIR/swiftlint.zip" -d "$TMP_DIR/swiftlint"

    # The dynamic `swiftlint` binary needs libsourcekitdInProc.so (Swift
    # toolchain).  The `swiftlint-static` variant is self-contained, so we
    # publish that one as `swiftlint` on PATH.
    install -m 0755 "$TMP_DIR/swiftlint/swiftlint-static" "$BIN_DIR/swiftlint"
}

install_swiftformat() {
    if command -v swiftformat >/dev/null 2>&1 \
        && [ "$(swiftformat --version 2>/dev/null)" = "$SWIFTFORMAT_VERSION" ]; then
        echo "swiftformat $SWIFTFORMAT_VERSION already installed"
        return 0
    fi

    echo "Installing swiftformat $SWIFTFORMAT_VERSION..."
    local url="https://github.com/nicklockwood/SwiftFormat/releases/download/${SWIFTFORMAT_VERSION}/${SWIFTFORMAT_ASSET}"
    curl -fsSL --retry 3 "$url" -o "$TMP_DIR/swiftformat.zip"
    unzip -q -o "$TMP_DIR/swiftformat.zip" -d "$TMP_DIR/swiftformat"
    install -m 0755 "$TMP_DIR/swiftformat/$SWIFTFORMAT_BIN_NAME" "$BIN_DIR/swiftformat"
}

install_swiftlint
install_swiftformat

echo "Lint tooling ready:"
echo "  $(swiftlint --version | head -1) ($(command -v swiftlint))"
echo "  $(swiftformat --version | head -1) ($(command -v swiftformat))"

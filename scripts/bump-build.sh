#!/bin/bash
#
# Automatically increments the build number (CURRENT_PROJECT_VERSION) in project.yml
# This script is called by Xcode as a pre-action when archiving.
#
# Usage: ./scripts/bump-build.sh

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_YML="$PROJECT_ROOT/project.yml"

if [ ! -f "$PROJECT_YML" ]; then
    echo "Error: project.yml not found at $PROJECT_YML"
    exit 1
fi

# Extract current build number
CURRENT_BUILD=$(grep -E "^\s+CURRENT_PROJECT_VERSION:\s*" "$PROJECT_YML" | head -1 | sed 's/.*CURRENT_PROJECT_VERSION:\s*//' | tr -d ' ')

if [ -z "$CURRENT_BUILD" ]; then
    echo "Error: Could not find CURRENT_PROJECT_VERSION in project.yml"
    exit 1
fi

# Increment the build number
NEW_BUILD=$((CURRENT_BUILD + 1))

echo "Incrementing build number: $CURRENT_BUILD -> $NEW_BUILD"

# Update project.yml using sed
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS requires -i '' for in-place editing
    sed -i '' "s/CURRENT_PROJECT_VERSION: $CURRENT_BUILD/CURRENT_PROJECT_VERSION: $NEW_BUILD/" "$PROJECT_YML"
else
    # Linux
    sed -i "s/CURRENT_PROJECT_VERSION: $CURRENT_BUILD/CURRENT_PROJECT_VERSION: $NEW_BUILD/" "$PROJECT_YML"
fi

# Regenerate Xcode project
echo "Regenerating Xcode project..."
cd "$PROJECT_ROOT"
if command -v xcodegen &> /dev/null; then
    xcodegen generate --quiet
else
    echo "Warning: xcodegen not found, skipping project regeneration"
fi

echo "Build number updated to $NEW_BUILD"

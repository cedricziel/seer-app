#!/bin/bash
#
# Bumps the marketing version (MARKETING_VERSION) in project.yml
# and resets the build number to 1.
#
# Usage: ./scripts/bump-version.sh [--patch|--minor|--major]
#
# Examples:
#   ./scripts/bump-version.sh --patch  # 0.1.0 -> 0.1.1
#   ./scripts/bump-version.sh --minor  # 0.1.0 -> 0.2.0
#   ./scripts/bump-version.sh --major  # 0.1.0 -> 1.0.0

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_YML="$PROJECT_ROOT/project.yml"

usage() {
    echo "Usage: $0 [--patch|--minor|--major]"
    echo ""
    echo "Options:"
    echo "  --patch  Bump patch version (0.1.0 -> 0.1.1)"
    echo "  --minor  Bump minor version (0.1.0 -> 0.2.0)"
    echo "  --major  Bump major version (0.1.0 -> 1.0.0)"
    echo ""
    echo "The build number is reset to 1 after any version bump."
    exit 1
}

if [ $# -ne 1 ]; then
    usage
fi

BUMP_TYPE=""
case "$1" in
    --patch)
        BUMP_TYPE="patch"
        ;;
    --minor)
        BUMP_TYPE="minor"
        ;;
    --major)
        BUMP_TYPE="major"
        ;;
    *)
        usage
        ;;
esac

if [ ! -f "$PROJECT_YML" ]; then
    echo "Error: project.yml not found at $PROJECT_YML"
    exit 1
fi

# Extract current version (remove quotes if present)
CURRENT_VERSION=$(grep -E "^\s+MARKETING_VERSION:\s*" "$PROJECT_YML" | head -1 | sed 's/.*MARKETING_VERSION:\s*//' | tr -d ' "')

if [ -z "$CURRENT_VERSION" ]; then
    echo "Error: Could not find MARKETING_VERSION in project.yml"
    exit 1
fi

# Parse version components
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

if [ -z "$MAJOR" ] || [ -z "$MINOR" ] || [ -z "$PATCH" ]; then
    echo "Error: Could not parse version '$CURRENT_VERSION' (expected format: X.Y.Z)"
    exit 1
fi

# Calculate new version
case "$BUMP_TYPE" in
    patch)
        NEW_PATCH=$((PATCH + 1))
        NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH"
        ;;
    minor)
        NEW_MINOR=$((MINOR + 1))
        NEW_VERSION="$MAJOR.$NEW_MINOR.0"
        ;;
    major)
        NEW_MAJOR=$((MAJOR + 1))
        NEW_VERSION="$NEW_MAJOR.0.0"
        ;;
esac

echo "Bumping $BUMP_TYPE version: $CURRENT_VERSION -> $NEW_VERSION"

# Update MARKETING_VERSION in project.yml
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/MARKETING_VERSION: \"$CURRENT_VERSION\"/MARKETING_VERSION: \"$NEW_VERSION\"/" "$PROJECT_YML"
else
    sed -i "s/MARKETING_VERSION: \"$CURRENT_VERSION\"/MARKETING_VERSION: \"$NEW_VERSION\"/" "$PROJECT_YML"
fi

# Reset build number to 1
echo "Resetting build number to 1"
CURRENT_BUILD=$(grep -E "^\s+CURRENT_PROJECT_VERSION:\s*" "$PROJECT_YML" | head -1 | sed 's/.*CURRENT_PROJECT_VERSION:\s*//' | tr -d ' ')

if [ -n "$CURRENT_BUILD" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/CURRENT_PROJECT_VERSION: $CURRENT_BUILD/CURRENT_PROJECT_VERSION: 1/" "$PROJECT_YML"
    else
        sed -i "s/CURRENT_PROJECT_VERSION: $CURRENT_BUILD/CURRENT_PROJECT_VERSION: 1/" "$PROJECT_YML"
    fi
fi

# Regenerate Xcode project
echo "Regenerating Xcode project..."
cd "$PROJECT_ROOT"
if command -v xcodegen &> /dev/null; then
    xcodegen generate --quiet
else
    echo "Warning: xcodegen not found, skipping project regeneration"
fi

echo "Version updated to $NEW_VERSION (Build 1)"

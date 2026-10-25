#!/bin/bash
set -euo pipefail
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
    exit 0
fi
root="$(cd "$(dirname "$0")/../.." && pwd)"
"$root/scripts/swift-tools" setup

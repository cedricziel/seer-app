#!/bin/bash
set -uo pipefail
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

if ! output="$(claude plugin marketplace add cedricziel/claude-plugins 2>&1)"; then
  if ! grep -qi "already" <<<"$output"; then
    echo "install-claude-plugins: marketplace add failed: $output" >&2
    exit 1
  fi
fi

if ! output="$(claude plugin install oss@cedricziel 2>&1)"; then
  echo "install-claude-plugins: plugin install failed: $output" >&2
  exit 1
fi

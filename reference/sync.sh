#!/usr/bin/env bash
# Shallow-clones the third-party reference repos listed in README.md.
# Clones are gitignored; only README.md and this script are tracked.
set -euo pipefail
cd "$(dirname "$0")"
REPOS=(
  livekit/agents
  pipecat-ai/pipecat
  livekit/client-sdk-android
  livekit/client-sdk-swift
  livekit/components-js
)
for r in "${REPOS[@]}"; do
  dir="${r//\//_}"
  if [ -d "$dir/.git" ]; then
    git -C "$dir" pull --ff-only -q || true
  else
    git clone --depth 1 -q "https://github.com/$r.git" "$dir"
  fi
  echo "ok: $r -> reference/$dir"
done

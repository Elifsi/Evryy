#!/usr/bin/env bash
# Shallow-clones third-party reference repos listed in reference/README.md.
# Clones are gitignored (reference/*/); only README.md and this script are tracked.
set -euo pipefail
cd "$(dirname "$0")"

CATEGORY="${1:-voice}"

VOICE_REPOS=(
  livekit/agents
  pipecat-ai/pipecat
  livekit/client-sdk-android
  livekit/client-sdk-swift
  livekit/components-js
)

CHAT_REPOS=(
  Gmarvis/whatsapp-clone
  GetStream/whatsApp-clone-compose
  efxlve/whatsapp-clone
)

FOOD_REPOS=(
  kaaneneskpc/Deliverr
  enatega/food-delivery-multivendor
  Aakash901/BlinkitClone
)

RIDES_REPOS=(
  anandwana001/uber-clone
  amitshekhariitbhu/ridesharing-uber-lyft-app
  WaqasSiddiqi/inDrive-Clone
  rohitstwt/Uber-Clone
)

TARGET_REPOS=()

case "$CATEGORY" in
  voice)
    TARGET_REPOS=("${VOICE_REPOS[@]}")
    ;;
  chat)
    TARGET_REPOS=("${CHAT_REPOS[@]}")
    ;;
  food)
    TARGET_REPOS=("${FOOD_REPOS[@]}")
    ;;
  rides)
    TARGET_REPOS=("${RIDES_REPOS[@]}")
    ;;
  all)
    TARGET_REPOS=(
      "${VOICE_REPOS[@]}"
      "${CHAT_REPOS[@]}"
      "${FOOD_REPOS[@]}"
      "${RIDES_REPOS[@]}"
    )
    ;;
  *)
    echo "Usage: ./sync.sh [voice|chat|food|rides|all]"
    exit 1
    ;;
esac

echo "Syncing reference repos for category: $CATEGORY"
for r in "${TARGET_REPOS[@]}"; do
  dir="${r//\//_}"
  if [ -d "$dir/.git" ]; then
    echo "updating: $r -> reference/$dir"
    git -C "$dir" pull --ff-only -q || true
  else
    echo "cloning: $r -> reference/$dir"
    git clone --depth 1 -q "https://github.com/$r.git" "$dir" || echo "warning: could not clone $r"
  fi
  echo "ok: $r -> reference/$dir"
done
echo "Finished syncing reference repositories."

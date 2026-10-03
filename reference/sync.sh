#!/usr/bin/env bash
# Shallow-clones third-party reference repos listed in reference/README.md.
# Clones are gitignored (reference/*/); only README.md and this script are tracked.
set -euo pipefail
cd "$(dirname "$0")"

CATEGORY="${1:-voice}"
export GIT_TERMINAL_PROMPT=0

NEPAL_REPOS=(
  bibekoli/local-levels-of-nepal-dataset
)

SPEECH_REPOS=(
  SYSTRAN/faster-whisper
  openai/whisper
  AI4Bharat/indicConformer-finetuning
  AI4Bharat/IndicNLP-Transliteration
)

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
  amitshekhariitbhu/ridesharing-uber-lyft-app
)

STAYS_REPOS=(
  OthmaneNissoukin/nextjs-hotel-booking
  Samizen/RoomRental
  vikasrana07/luxeride
)

SNAP_REPOS=(
  Debanshu777/Compose-Snapchat-Clone
  TowhidKashem/snapchat-clone
)

TARGET_REPOS=()

case "$CATEGORY" in
  nepal)
    TARGET_REPOS=("${NEPAL_REPOS[@]}")
    ;;
  speech)
    TARGET_REPOS=("${SPEECH_REPOS[@]}")
    ;;
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
  stays)
    TARGET_REPOS=("${STAYS_REPOS[@]}")
    ;;
  snap)
    TARGET_REPOS=("${SNAP_REPOS[@]}")
    ;;
  all)
    TARGET_REPOS=(
      "${NEPAL_REPOS[@]}"
      "${SPEECH_REPOS[@]}"
      "${VOICE_REPOS[@]}"
      "${CHAT_REPOS[@]}"
      "${FOOD_REPOS[@]}"
      "${RIDES_REPOS[@]}"
      "${STAYS_REPOS[@]}"
      "${SNAP_REPOS[@]}"
    )
    ;;
  *)
    echo "Usage: ./sync.sh [nepal|speech|voice|chat|food|rides|stays|snap|all]"
    exit 1
    ;;
esac

echo "Syncing reference repos for category: $CATEGORY"
for r in "${TARGET_REPOS[@]}"; do
  dir="${r//\//_}"
  if [ -d "$dir/.git" ]; then
    echo "updating: $r -> reference/$dir"
    git -C "$dir" pull --ff-only -q 2>/dev/null || true
  else
    echo "cloning: $r -> reference/$dir"
    git clone --depth 1 -q "https://github.com/$r.git" "$dir" 2>/dev/null || echo "skipped: $r"
  fi
  echo "ok: $r -> reference/$dir"
done
echo "Finished syncing reference repositories."

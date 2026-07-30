#!/usr/bin/env bash
#
# Erzeugt für jede Gate-Seite ein fertiges Prompt-Paket zum Einfügen in ein
# Chatfenster (ChatGPT, Claude, was auch immer verfügbar ist) — und nimmt die
# Antworten anschliessend zum kostenlosen Abspielen wieder auf.
#
# Anlass: bis zum 30. Juli 2026 brauchte jede Messung dieser Pipeline einen
# bezahlten Live-Aufruf, auch wenn nur eine Assembler-Änderung zu prüfen war.
# Eine Antwort, die ein starkes Modell einmal geliefert hat, ist damit dauerhaft
# nutzbar.
#
# Ablauf:
#   1. ./scripts/export-extraction-prompts.sh
#        -> /tmp/kitchenlink-extraction-prompts/<fixture>/page-<n>.txt
#           je Seite: Systemprompt, OCR-Belegzeilen, optional Layout-Transkript
#        -> dazu die Seitenbilder zum Mitschicken
#   2. Prompt samt Seitenbild in das Chatfenster geben, Antwort als reines JSON
#      zurückkopieren nach:
#        <ziel>/page-<n>.json
#   3. Kostenlos messen, beliebig oft:
#        KITCHENLINK_LLM_REPLAY_DIR=<ziel> \
#        KITCHENLINK_LLM_ALLOW_KEYLESS=1 \
#          ./scripts/run-import-review.sh
#
# Die Seitenindizes sind dieselben wie im Manifest des Qualitätsgates, damit die
# Auswertung ohne Umrechnung passt.
#
# Layout-Transkript mitexportieren (olmOCR o. ä. muss laufen):
#   KITCHENLINK_LAYOUT_BASE_URL=http://localhost:11434/v1 \
#   KITCHENLINK_LAYOUT_MODEL=hf.co/lmstudio-community/olmOCR-2-7B-1025-GGUF:Q4_K_M \
#     ./scripts/export-extraction-prompts.sh

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output_root=${KITCHENLINK_PROMPT_OUTPUT:-/tmp/kitchenlink-extraction-prompts}
derived_data=${KITCHENLINK_REVIEW_DERIVED_DATA:-/tmp/kitchenlink-import-review-build}
destination=${KITCHENLINK_REVIEW_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}

mkdir -p "$output_root"

echo "Prompt-Pakete werden erzeugt unter: $output_root"
echo ""

xcodebuild \
  -project "$repo_root/kitchenlink.xcodeproj" \
  -scheme kitchenlink \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "$destination" \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  build-for-testing

xctestrun=$(find "$derived_data/Build/Products" -maxdepth 1 -name '*.xctestrun' -print -quit)
[[ -n "$xctestrun" ]] || {
  echo "Keine .xctestrun-Datei unter $derived_data/Build/Products" >&2
  exit 1
}

TEST_RUNNER_KITCHENLINK_PROMPT_OUTPUT="$output_root" \
TEST_RUNNER_KITCHENLINK_LAYOUT_BASE_URL="${KITCHENLINK_LAYOUT_BASE_URL:-}" \
TEST_RUNNER_KITCHENLINK_LAYOUT_MODEL="${KITCHENLINK_LAYOUT_MODEL:-}" \
TEST_RUNNER_KITCHENLINK_LAYOUT_API_KEY="${KITCHENLINK_LAYOUT_API_KEY:-}" \
TEST_RUNNER_KITCHENLINK_LAYOUT_PAGE_TIMEOUT_SECONDS="${KITCHENLINK_LAYOUT_PAGE_TIMEOUT_SECONDS:-}" \
xcodebuild \
  test-without-building \
  -xctestrun "$xctestrun" \
  -destination "$destination" \
  -only-testing:kitchenlinkTests/MenuImportPromptExportTests/testExportExtractionPrompts

echo ""
echo "Fertig. Pakete:"
find "$output_root" -name 'page-*.txt' | sort | sed 's/^/  /'
echo ""
echo "Antworten als reines JSON ablegen als <ziel>/page-<n>.json und dann:"
echo "  KITCHENLINK_LLM_REPLAY_DIR=<ziel> KITCHENLINK_LLM_ALLOW_KEYLESS=1 \\"
echo "    ./scripts/run-import-review.sh"

#!/usr/bin/env bash
#
# KL-SCAN-002: Import-Review-Umgebung.
#
# Jagt alle Demo-Fixtures — und optional eigene Speisekarten — durch die echte
# lokale OCR-/Parser-Pipeline und öffnet einen Seite-an-Seite-HTML-Report
# (Original vs. Erkennungsergebnis) für die menschliche Qualitätsprüfung.
#
# Aufruf:
#   ./scripts/run-import-review.sh
#
# Eigene Karten zusätzlich prüfen (Ordner mit PDFs und/oder Bild-Unterordnern):
#   KITCHENLINK_REVIEW_MENUS=~/Speisekarten ./scripts/run-import-review.sh
#
# KI-Vergleich (Runde 2): mit gesetztem API-Key läuft zusätzlich der
# vorhandene KI-Pfad (Seitenbilder + OCR an das Vision-LLM); der Report zeigt
# beide Pipelines umschaltbar nebeneinander:
#   KITCHENLINK_OPENAI_API_KEY=sk-... ./scripts/run-import-review.sh
#
# Jeder Lauf landet in einem eigenen Zeitstempel-Ordner; "latest" zeigt auf den
# neuesten. Feedback aus dem Report bitte als import-review-feedback.json an
# den Agenten zurückgeben.

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
derived_data=${KITCHENLINK_REVIEW_DERIVED_DATA:-/tmp/kitchenlink-import-review-build}
output_root=${KITCHENLINK_REVIEW_OUTPUT:-/tmp/kitchenlink-import-review}
destination=${KITCHENLINK_REVIEW_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}
extra_menus=${KITCHENLINK_REVIEW_MENUS:-}

run_dir="$output_root/run-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$run_dir"

if [[ -n "$extra_menus" ]]; then
  extra_menus=$(cd "$extra_menus" && pwd)
  echo "Eigene Karten aus: $extra_menus"
fi

xcodebuild \
  -project "$repo_root/kitchenlink.xcodeproj" \
  -scheme kitchenlink \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "$destination" \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  build-for-testing

app_bundle="$derived_data/Build/Products/Debug-iphonesimulator/kitchenlink.app"

# Konfiguration in das App-Bundle legen (gleicher Gate-Mechanismus wie der
# Scanner-Benchmark, nur mit Inhalt statt leerer Flag-Datei). Der API-Key
# selbst landet NIE in einer Datei; er wird nur als TEST_RUNNER_-Variable in
# den Testprozess gereicht.
run_llm="false"
if [[ -n "${KITCHENLINK_OPENAI_API_KEY:-}" ]]; then
  run_llm="true"
  echo "KI-Vergleich aktiv (API-Key aus der Umgebung)."
fi

if [[ -n "$extra_menus" ]]; then
  printf '{"outputPath": "%s", "extraMenusPath": "%s", "runLLM": %s}\n' \
    "$run_dir" "$extra_menus" "$run_llm" > "$app_bundle/ImportReviewRequest.json"
else
  printf '{"outputPath": "%s", "runLLM": %s}\n' \
    "$run_dir" "$run_llm" > "$app_bundle/ImportReviewRequest.json"
fi

xctestrun=$(find "$derived_data/Build/Products" -maxdepth 1 -name '*.xctestrun' -print -quit)
[[ -n "$xctestrun" ]] || {
  echo "No .xctestrun file found under $derived_data/Build/Products" >&2
  exit 1
}

TEST_RUNNER_KITCHENLINK_OPENAI_API_KEY="${KITCHENLINK_OPENAI_API_KEY:-}" \
xcodebuild \
  test-without-building \
  -xctestrun "$xctestrun" \
  -destination "$destination" \
  -only-testing:kitchenlinkTests/MenuImportReviewHarnessTests/testExportImportReviewReport

[[ -f "$run_dir/report.json" ]] || {
  echo "report.json wurde nicht erzeugt — Testlauf prüfen." >&2
  exit 1
}

# Report zusammensetzen: statisches HTML + Daten als script-src (kein fetch,
# damit file:// ohne lokalen Server funktioniert).
{
  printf 'window.KL_REPORT = '
  cat "$run_dir/report.json"
  printf ';\n'
} > "$run_dir/report.js"
cp "$repo_root/scripts/import-review-report.html" "$run_dir/index.html"

ln -sfn "$run_dir" "$output_root/latest"

echo ""
echo "Import-Review bereit:"
echo "  $run_dir/index.html"
echo "  (Symlink: $output_root/latest/index.html)"

if [[ "${KITCHENLINK_REVIEW_NO_OPEN:-0}" != "1" ]] && command -v open >/dev/null; then
  open "$run_dir/index.html"
fi

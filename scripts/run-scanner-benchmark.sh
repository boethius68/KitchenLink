#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
derived_data=${KITCHENLINK_BENCHMARK_DERIVED_DATA:-/tmp/kitchenlink-scanner-benchmark-build}
output_dir=${KITCHENLINK_BENCHMARK_OUTPUT:-/tmp/kitchenlink-scanner-benchmark}
destination=${KITCHENLINK_BENCHMARK_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}
result_bundle="$output_dir/kitchenlink-scanner-benchmark.xcresult"
attachments_dir="$output_dir/attachments"
actual_report="$output_dir/actual.json"
evaluation_report="$output_dir/evaluation.json"

mkdir -p "$output_dir"
rm -rf "$result_bundle" "$attachments_dir"

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
touch "$app_bundle/RunScannerBenchmark.flag"

xctestrun=$(find "$derived_data/Build/Products" -maxdepth 1 -name '*.xctestrun' -print -quit)
[[ -n "$xctestrun" ]] || {
  echo "No .xctestrun file found under $derived_data/Build/Products" >&2
  exit 1
}

xcodebuild \
  test-without-building \
  -xctestrun "$xctestrun" \
  -destination "$destination" \
  -only-testing:kitchenlinkTests/MenuImportBenchmarkTests/testDemoMenusProduceLocalOCRBenchmarkSnapshot \
  -resultBundlePath "$result_bundle"

xcrun xcresulttool export attachments \
  --path "$result_bundle" \
  --output-path "$attachments_dir"

attachment=$(find "$attachments_dir" -maxdepth 1 -name '*.json' ! -name manifest.json -print -quit)
[[ -n "$attachment" ]] || {
  echo "Benchmark JSON attachment was not produced." >&2
  exit 1
}
cp "$attachment" "$actual_report"

set +e
xcrun swift "$repo_root/scripts/evaluate-scanner-benchmark.swift" \
  "$repo_root/docs/test-fixtures/scanner-benchmark/gold-baseline.json" \
  "$actual_report" \
  "$repo_root/docs/test-fixtures/scanner-benchmark/thresholds.json" \
  > "$evaluation_report"
evaluation_status=$?
set -e

jq '{passed, fixtures: [.fixtures[] | {
  fixtureID,
  sectionRecall,
  itemNameRecall,
  itemPriceRecall,
  ocrItemRecall,
  draftItemNameRecall,
  draftItemPriceRecall,
  parserMisses: (.parserMisses | length),
  draftParserMisses: (.draftParserMisses | length),
  draftRecoveredWithoutPrice: (.draftRecoveredWithoutPrice | length),
  draftUnpricedItems: (.draftUnpricedItems | length),
  ocrMisses: (.ocrMisses | length),
  priceMismatches: (.priceMismatches | length)
}]}' "$evaluation_report"

echo "Actual report: $actual_report"
echo "Evaluation: $evaluation_report"
exit "$evaluation_status"

#!/usr/bin/env bash
#
# Phase 1: deterministic ten-page quality measurement.
#
# Default behavior is deliberately local-only. It never enables a remote model.
# To score an already generated LLM review report:
#   KITCHENLINK_QUALITY_REPORT=/path/report.json \
#   KITCHENLINK_QUALITY_MODE=llm ./scripts/run-menu-quality-gate.sh

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
gate_dir="$repo_root/docs/test-fixtures/scanner-quality-gate"
review_output=${KITCHENLINK_QUALITY_REVIEW_OUTPUT:-/tmp/kitchenlink-menu-quality-gate-review}
report_path=${KITCHENLINK_QUALITY_REPORT:-}
mode=${KITCHENLINK_QUALITY_MODE:-local}
repeat_runs=${KITCHENLINK_QUALITY_REPEAT_RUNS:-1}
repeat_report_paths=${KITCHENLINK_QUALITY_REPEAT_REPORTS:-}

if ! [[ "$repeat_runs" =~ ^[1-9][0-9]*$ ]]; then
  echo "KITCHENLINK_QUALITY_REPEAT_RUNS muss eine positive ganze Zahl sein." >&2
  exit 2
fi

python3 "$repo_root/scripts/evaluate-menu-quality-gate.py" \
  --gate-dir "$gate_dir" \
  --check-ground-truth

report_paths=()
if [[ -z "$report_path" ]]; then
  if [[ "$mode" != "local" ]]; then
    echo "Für mode=$mode bitte KITCHENLINK_QUALITY_REPORT auf einen bereits erzeugten Report setzen." >&2
    exit 2
  fi

  for ((run_index = 1; run_index <= repeat_runs; run_index++)); do
    run_output="$review_output"
    if ((repeat_runs > 1)); then
      run_output="$review_output/run-$run_index"
    fi
    KITCHENLINK_REVIEW_OUTPUT="$run_output" \
    KITCHENLINK_REVIEW_NO_OPEN=1 \
    KITCHENLINK_OPENAI_API_KEY= \
    KITCHENLINK_OPENCODE_API_KEY= \
    KITCHENLINK_OPENCODE_FREE=0 \
    KITCHENLINK_LLM_ALLOW_KEYLESS=0 \
      "$repo_root/scripts/run-import-review.sh"
    report_paths+=("$run_output/latest/report.json")
  done
else
  report_paths+=("$report_path")
  if [[ -n "$repeat_report_paths" ]]; then
    IFS=':' read -r -a additional_reports <<< "$repeat_report_paths"
    report_paths+=("${additional_reports[@]}")
  fi
fi

for current_report in "${report_paths[@]}"; do
  [[ -f "$current_report" ]] || {
    echo "Review-Report nicht gefunden: $current_report" >&2
    exit 2
  }
done

result_path=${KITCHENLINK_QUALITY_RESULT:-"$(dirname "${report_paths[0]}")/quality-result.json"}
arguments=(
  --gate-dir "$gate_dir"
  --mode "$mode"
  --output "$result_path"
)
# launch = freigabewirksames Profil, strict = Diagnose/Fernziel.
if [[ -n "${KITCHENLINK_QUALITY_PROFILE:-}" ]]; then
  arguments+=(--profile "$KITCHENLINK_QUALITY_PROFILE")
fi
for current_report in "${report_paths[@]}"; do
  arguments+=(--report "$current_report")
done
if [[ "${KITCHENLINK_QUALITY_ENFORCE:-0}" == "1" ]]; then
  arguments+=(--enforce)
fi

python3 "$repo_root/scripts/evaluate-menu-quality-gate.py" "${arguments[@]}"
echo "Maschinenlesbares Ergebnis: $result_path"

#!/usr/bin/env bash
#
# KL-SCAN-002: Schnell-Diagnose für das KI-Gateway (ohne App-Build).
#
# Prüft in Sekunden, ob API-Key, Gateway und Modell zusammenpassen:
#   KITCHENLINK_OPENCODE_API_KEY=... ./scripts/check-llm-gateway.sh
#
# Optional anderes Gateway/Modell wie beim Review-Skript:
#   KITCHENLINK_LLM_BASE_URL=... KITCHENLINK_LLM_MODEL=... \
#     KITCHENLINK_OPENAI_API_KEY=... ./scripts/check-llm-gateway.sh
#
# Der Key wird nie vollständig ausgegeben und landet in keiner Datei.

set -euo pipefail

key="${KITCHENLINK_OPENCODE_API_KEY:-${KITCHENLINK_OPENAI_API_KEY:-}}"
if [[ -n "${KITCHENLINK_OPENCODE_API_KEY:-}" ]]; then
  base="${KITCHENLINK_LLM_BASE_URL:-https://opencode.ai/zen/v1}"
  model="${KITCHENLINK_LLM_MODEL:-claude-sonnet-5}"
else
  base="${KITCHENLINK_LLM_BASE_URL:-https://api.openai.com/v1}"
  model="${KITCHENLINK_LLM_MODEL:-gpt-4.1}"
fi

[[ -n "$key" ]] || {
  echo "Kein Key. Aufruf: KITCHENLINK_OPENCODE_API_KEY=... $0" >&2
  exit 1
}

base="${base%/}"
echo "Gateway: $base"
echo "Modell:  $model"
echo "Key:     ${key:0:6}… (${#key} Zeichen)"
echo ""

echo "== 1) Modell-Liste (GET $base/models) =="
status=$(curl -sS -o /tmp/kl-llm-models.json -w "%{http_code}" \
  "$base/models" -H "Authorization: Bearer $key" || echo "000")
echo "HTTP $status"
if [[ "$status" == "200" ]]; then
  if command -v jq >/dev/null; then
    echo "Verfügbare Modelle:"
    jq -r '.data[].id // empty' /tmp/kl-llm-models.json 2>/dev/null | sed 's/^/  - /' | head -40
  else
    head -c 600 /tmp/kl-llm-models.json; echo
  fi
else
  echo "Antwort: $(head -c 400 /tmp/kl-llm-models.json)"
fi
echo ""

echo "== 2) Mini-Chat (POST $base/chat/completions, Modell $model) =="
status=$(curl -sS -o /tmp/kl-llm-chat.json -w "%{http_code}" \
  "$base/chat/completions" \
  -H "Authorization: Bearer $key" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"Antworte nur mit OK\"}],\"max_tokens\":10}" \
  || echo "000")
echo "HTTP $status"
echo "Antwort: $(head -c 400 /tmp/kl-llm-chat.json)"
echo ""

case "$status" in
  200) echo "PASST: Key, Gateway und Modell funktionieren. Jetzt den Review-Lauf starten." ;;
  401) echo "DIAGNOSE: Der Key wird abgelehnt. Prüfen: richtiger Zen-API-Key (opencode.ai -> Zen), Billing hinterlegt, Key vollständig kopiert?" ;;
  402|403) echo "DIAGNOSE: Key ok, aber Konto/Guthaben-Problem (Billing/Credits bei Zen prüfen)." ;;
  404) echo "DIAGNOSE: Endpunkt oder Modell existiert so nicht — Modell-Liste oben prüfen und ggf. KITCHENLINK_LLM_MODEL anpassen." ;;
  400) echo "DIAGNOSE: Anfrageformat/Modellname — Antworttext oben lesen, ggf. anderes Modell aus der Liste wählen." ;;
  *)   echo "DIAGNOSE: Unerwarteter Status — Antworttext oben lesen." ;;
esac

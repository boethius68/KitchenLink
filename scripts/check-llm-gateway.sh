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
echo ""

# ============================================================================
# 3) Free-Modell-Matrix: Welche Gratis-Modelle antworten, welche können Vision?
#    (Nutzer-Vorgabe 20. Juli 2026: nur Free-Modelle nutzen.)
#    Ein winziges rotes Testbild als data-URL prüft echte Bildverarbeitung.
# ============================================================================
echo "== 3) Free-Modelle: Text- und Vision-Kurztest =="

free_models=$(jq -r '.data[].id' /tmp/kl-llm-models.json 2>/dev/null \
  | grep -E '\-free$|^big-pickle$' || true)
if [[ -z "$free_models" ]]; then
  echo "Keine Free-Modelle in der Liste gefunden — Abschnitt übersprungen."
  exit 0
fi

# 8x8 rotes PNG, base64 (winzig, kostet praktisch nichts).
red_png="iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAADED76LAAAAFklEQVR4nGP8z8Dwn4EIwESMolGFlCsEAE1uAgVDVVwJAAAAAElFTkSuQmCC"

results_file=/tmp/kl-llm-free-matrix.txt
: > "$results_file"
best_vision=""
best_text=""

for m in $free_models; do
  # Text-Test
  t_status=$(curl -sS -o /tmp/kl-llm-free-text.json -w "%{http_code}" \
    --max-time 30 "$base/chat/completions" \
    -H "Authorization: Bearer $key" -H "Content-Type: application/json" \
    -d "{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":\"Antworte nur mit OK\"}],\"max_tokens\":10}" \
    || echo "000")
  text_ok="nein"
  if [[ "$t_status" == "200" ]] && jq -e '.choices[0].message.content' /tmp/kl-llm-free-text.json >/dev/null 2>&1; then
    text_ok="ja"
    [[ -z "$best_text" ]] && best_text="$m"
  fi

  # Vision-Test (rotes Bild, Frage nach der Farbe)
  v_status=$(curl -sS -o /tmp/kl-llm-free-vision.json -w "%{http_code}" \
    --max-time 30 "$base/chat/completions" \
    -H "Authorization: Bearer $key" -H "Content-Type: application/json" \
    -d "{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":[{\"type\":\"text\",\"text\":\"Welche Farbe hat dieses Bild? Ein Wort.\"},{\"type\":\"image_url\",\"image_url\":{\"url\":\"data:image/png;base64,$red_png\"}}]}],\"max_tokens\":12}" \
    || echo "000")
  vision_ok="nein"
  if [[ "$v_status" == "200" ]]; then
    answer=$(jq -r '.choices[0].message.content // ""' /tmp/kl-llm-free-vision.json 2>/dev/null | tr '[:upper:]' '[:lower:]')
    if [[ "$answer" == *rot* || "$answer" == *red* ]]; then
      vision_ok="ja"
      [[ -z "$best_vision" ]] && best_vision="$m"
    fi
  fi

  printf "  %-28s Text(HTTP %s): %-4s Vision(HTTP %s): %s\n" \
    "$m" "$t_status" "$text_ok" "$v_status" "$vision_ok" | tee -a "$results_file"
done

echo ""
echo "== Empfehlung =="
if [[ -n "$best_vision" ]]; then
  echo "Vision-fähiges Free-Modell gefunden: $best_vision"
  echo "Review-Lauf:"
  echo "  KITCHENLINK_LLM_MODEL=$best_vision KITCHENLINK_OPENCODE_API_KEY=\$KEY ./scripts/run-import-review.sh"
elif [[ -n "$best_text" ]]; then
  echo "Kein Free-Modell kann Bilder — Text-Modus mit OCR-Koordinaten nutzen:"
  echo "  KITCHENLINK_LLM_MODEL=$best_text KITCHENLINK_LLM_SEND_IMAGES=0 \\"
  echo "    KITCHENLINK_OPENCODE_API_KEY=\$KEY ./scripts/run-import-review.sh"
else
  echo "Kein Free-Modell hat geantwortet — Ausgaben oben prüfen."
fi

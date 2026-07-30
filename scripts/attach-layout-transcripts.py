#!/usr/bin/env python3
"""Hängt Layout-Transkripte an die exportierten Prompt-Pakete.

Warum ausserhalb der App: die Layoutstufe im Simulator erhält ihre
Konfiguration derzeit nicht (offener Punkt, siehe Handoff). Über HTTP arbeitet
dasselbe Modell zuverlässig, und der Block wird hier in **genau** dem Wortlaut
erzeugt, den `MenuImportLayoutPass.promptBlock` verwendet — sonst wäre das
eingesammelte Ergebnis nicht mit einem Gateway-Lauf vergleichbar.

Aufruf (Ollama muss laufen, olmOCR geladen sein):
    python3 scripts/attach-layout-transcripts.py
"""

import base64
import json
import os
import sys
import urllib.request

# Dieselben Seiten und Indizes wie das Qualitätsgate.
PAGES = {
    "kitchenlink-pruefkueche": ([0, 1, 2], "kitchenlink-pruefkueche-{n}.png"),
    "scheune-berlin": ([0], "scheune-berlin-{n}.png"),
    "lichtburg-berlin": ([4, 5, 6], "lichtburg-berlin-{n}.png"),
    "alexxanders-chemnitz": ([0, 2, 3], "alexxanders-chemnitz-{n}.png"),
}

# Wortgleich mit MenuImportLayoutPass.instruction.
INSTRUCTION = (
    "Attached is one page of a restaurant menu. Return the complete text of the "
    "page in natural reading order. Preserve the layout structure: keep each dish "
    "together with the price or prices that belong to it, keep a bilingual pair on "
    "the same dish, and render price columns or multi-column lists as a table so "
    "it stays clear which price belongs to which dish and which portion. Do not "
    "summarize, do not translate, do not omit anything, and do not add anything "
    "that is not printed on the page."
)

# Wortgleich mit MenuImportLayoutPass.promptBlock.
BLOCK_HEADER = (
    "Layout-resolved transcript of this page (from a document model, reading "
    "order and column structure already resolved). Use it to decide which "
    "price, portion and option belongs to which entry. It carries no evidence "
    "IDs: cite only the supplied OCR evidence lines."
)

MODEL = os.environ.get(
    "KITCHENLINK_LAYOUT_MODEL",
    "hf.co/lmstudio-community/olmOCR-2-7B-1025-GGUF:Q4_K_M",
)
BASE_URL = os.environ.get("KITCHENLINK_LAYOUT_BASE_URL", "http://localhost:11434/v1")
IMAGE_ROOT = "kitchenlink/Resources/DemoMenus"
PROMPT_ROOT = os.environ.get(
    "KITCHENLINK_PROMPT_OUTPUT", "/tmp/kitchenlink-extraction-prompts"
)
MARKER = "\n\n===== ANWEISUNG"


def scaled_copy(image_path, max_dimension=1600):
    """Verkleinert die Seite auf die Kantenlänge, die die App auch sendet.

    Ohne das lehnt Ollama die grösseren Fixtures (1654x2339) mit HTTP 400 ab —
    der Anfragekörper wird zu gross. `sips` liegt auf macOS bei.
    """
    target = os.path.join("/tmp", "layout-scaled-" + os.path.basename(image_path))
    result = os.system(
        "sips --resampleHeightWidthMax %d %s --out %s >/dev/null 2>&1"
        % (max_dimension, image_path, target)
    )
    return target if result == 0 and os.path.exists(target) else image_path


def transcript(image_path):
    image_path = scaled_copy(image_path)
    encoded = base64.b64encode(open(image_path, "rb").read()).decode()
    body = json.dumps({
        "model": MODEL,
        "stream": False,
        "temperature": 0,
        "messages": [{
            "role": "user",
            "content": [
                {"type": "text", "text": INSTRUCTION},
                {
                    "type": "image_url",
                    "image_url": {"url": "data:image/png;base64," + encoded},
                },
            ],
        }],
    }).encode()
    request = urllib.request.Request(
        BASE_URL.rstrip("/") + "/chat/completions",
        data=body,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=900) as response:
        payload = json.load(response)
    return payload["choices"][0]["message"]["content"].strip()


def main():
    failures = 0
    for fixture, (pages, pattern) in PAGES.items():
        for page in pages:
            image_path = os.path.join(IMAGE_ROOT, pattern.format(n=page + 1))
            target = os.path.join(PROMPT_ROOT, fixture, "page-%d.txt" % page)
            if not os.path.exists(image_path) or not os.path.exists(target):
                print("fehlt: %s oder %s" % (image_path, target))
                failures += 1
                continue
            try:
                text = transcript(image_path)
            except Exception as error:  # noqa: BLE001 - Diagnose ist der Zweck
                print("Fehler %s Seite %d: %s" % (fixture, page, error))
                failures += 1
                continue

            existing = open(target).read()
            if BLOCK_HEADER[:40] in existing:
                print("schon vorhanden: %s Seite %d" % (fixture, page))
                continue
            head, separator, tail = existing.partition(MARKER)
            with open(target, "w") as handle:
                handle.write(head + "\n\n" + BLOCK_HEADER + "\n\n" + text + separator + tail)
            print("ok %-26s Seite %d  %5d Zeichen Transkript" % (fixture, page, len(text)))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())

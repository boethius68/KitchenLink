#!/usr/bin/env python3
"""KL-SCAN-002: Synthetischer Speisekarten-Testkorpus mit Ground Truth.

DeepSeek (OpenCode Zen, kostenlos, keylos) erzeugt diverse deutsche Karten als
JSON. Aus DIESEM JSON wird deterministisch ein realistisches PDF gerendert
(Chrome headless) — Bild und Wahrheit stimmen damit exakt überein. Allergen-
Codes werden im Bild an die Artikelnamen gehängt (wie auf echten Karten), in
der Wahrheit stehen sie getrennt: so lässt sich das Code-Trennen messen.

Aufruf:
  python3 scripts/generate_menu_corpus.py --count 30 --out /tmp/kl-menu-corpus

Ausgabe je Karte:
  <out>/pdf/<id>.pdf          — gerenderte Karte (Eingabe für den Import)
  <out>/truth/<id>.json       — Ground Truth (Erwartung)
"""
import argparse
import base64
import html
import json
import os
import random
import subprocess
import sys
import tempfile
import urllib.request

GATEWAY = "https://opencode.ai/zen/v1/chat/completions"
MODEL = os.environ.get("KITCHENLINK_CORPUS_MODEL", "deepseek-v4-flash-free")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Diversität: Küche × Layout × Sonderfall. Jede Karte kombiniert diese Achsen,
# damit der Korpus die harten Fälle breit abdeckt.
CUISINES = [
    "bayerisches Wirtshaus", "italienisches Ristorante", "griechische Taverne",
    "modernes Bistro", "Steakhouse", "vietnamesische Küche", "Café mit Frühstück",
    "Burger-Laden", "Fischrestaurant", "vegetarisch-veganes Lokal",
    "türkisches Restaurant", "gehobene saisonale Küche",
]
LAYOUTS = ["single", "two_column", "dense"]
SPECIALS = [
    "normal",
    "set_menu",       # ein Gang-Menü mit Menüpreis pro Person
    "bilingual",      # deutsch + englische Übersetzungszeile je Gericht
    "with_variants",  # einige Gerichte mit Portionen/Varianten (klein/groß)
    "cover_page",     # zusätzliche reine Titel-/Deckseite ohne Gerichte
]

SYSTEM = (
    "Du erzeugst realistische deutsche Restaurant-Speisekarten als JSON-Testdaten. "
    "Gib AUSSCHLIESSLICH gültiges JSON zurück, ohne Markdown, exakt in diesem Schema:\n"
    '{\n'
    '  "venue": "string",\n'
    '  "categories": [\n'
    '    {"title": "string", "kind": "food|drink",\n'
    '     "items": [\n'
    '       {"name": "string (OHNE Allergencodes)", "description": "string",\n'
    '        "price_cents": 1290, "allergen_codes": ["a","c"],\n'
    '        "price_basis": "per_item|per_person",\n'
    '        "variants": [{"name":"groß","price_cents":1490}],\n'
    '        "courses": "nur bei Menüs: Gangfolge als Text"}\n'
    '     ]}\n'
    '  ],\n'
    '  "allergen_legend": {"a": "Gluten", "c": "Ei"}\n'
    "}\n"
    "Regeln: realistische deutsche Gerichte und Preise (in Cent). "
    "allergen_codes sind kurze Buchstaben/Ziffern und gehören NUR ins Feld, NIE in name/description. "
    "Nur wo sinnvoll variants/courses/price_basis setzen. Keine leeren Kategorien."
)


def repair_json(s):
    """German-quote-aware Reparatur unescapter Anführungszeichen (Port aus Swift)."""
    out, in_str, ger, i, n = [], False, 0, 0, len(s)
    while i < n:
        c = s[i]
        if not in_str:
            out.append(c)
            if c == '"':
                in_str, ger = True, 0
            i += 1
            continue
        if c == "\\":
            out.append(c)
            if i + 1 < n:
                out.append(s[i + 1])
            i += 2
            continue
        if c == "„":
            ger += 1
            out.append(c)
            i += 1
            continue
        if c == '"':
            if ger > 0:
                ger -= 1
                out.append('\\"')
                i += 1
                continue
            j = i + 1
            while j < n and s[j] in " \n\r\t":
                j += 1
            nxt = s[j] if j < n else None
            if nxt is None or nxt in ",:}]":
                out.append(c)
                in_str = False
            else:
                out.append('\\"')
            i += 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


def _parse_menu(text):
    text = text.strip()
    if text.startswith("```"):
        text = text.split("```", 2)[1]
        if text.startswith("json"):
            text = text[4:]
    start, end = text.find("{"), text.rfind("}")
    if start >= 0 and end > start:
        text = text[start:end + 1]
    for candidate in (text, repair_json(text)):
        try:
            return json.loads(candidate, strict=False)
        except json.JSONDecodeError:
            continue
    raise json.JSONDecodeError("unparsebar auch nach Reparatur", text, 0)


def call_deepseek(user_prompt, timeout=120, attempts=3):
    body = json.dumps({
        "model": MODEL,
        "temperature": 0.8,
        "response_format": {"type": "json_object"},
        "max_tokens": 6000,
        "messages": [
            {"role": "system", "content": SYSTEM},
            {"role": "user", "content": user_prompt},
        ],
    }).encode()
    last_err = None
    for _ in range(attempts):
        try:
            req = urllib.request.Request(GATEWAY, data=body, headers={
                "Content-Type": "application/json",
                # Zen-Gateway lehnt den urllib-Default-UA ab (403).
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                              "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
                "Accept": "application/json",
            })
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                data = json.loads(resp.read().decode())
            msg = data["choices"][0]["message"]
            text = msg.get("content") or msg.get("reasoning") or ""
            if text.strip():
                return _parse_menu(text)
            last_err = ValueError("leere Antwort")
        except Exception as e:  # Netz/JSON/Empty -> erneut versuchen
            last_err = e
    raise last_err or RuntimeError("unbekannter Fehler")


def spec_prompt(cuisine, layout, special):
    parts = [f"Erzeuge die Speisekarte für ein {cuisine}."]
    parts.append("3 bis 5 Kategorien mit je 3 bis 6 Gerichten, plus eine Allergen-Legende.")
    if special == "set_menu":
        parts.append("Enthalte ZUSÄTZLICH ein festes Gang-Menü als EINEN Artikel mit "
                     "price_basis=per_person, courses (Vorspeise/Hauptgang/Dessert) und Menüpreis.")
    if special == "bilingual":
        parts.append("Schreibe zu jedem Gericht eine kurze englische Übersetzung in die description "
                     "(Format: 'deutsche Beschreibung | english translation').")
    if special == "with_variants":
        parts.append("Gib einigen Gerichten variants (z. B. klein/groß, 0,3l/0,5l) mit eigenen Preisen.")
    return " ".join(parts)


def slug(s):
    out = []
    for ch in s.lower():
        if ch.isascii() and (ch.isalnum()):
            out.append(ch)
        elif out and out[-1] != "-":
            out.append("-")
    return "".join(out).strip("-") or "menu"


def euro(cents):
    return f"{cents // 100},{cents % 100:02d} €"


# Allergen-Codes so anhängen, wie echte Karten es tun (an den Namen). Der
# Import muss sie wieder abtrennen — genau das wird gemessen.
def name_with_codes(item):
    codes = item.get("allergen_codes") or []
    base = item["name"]
    if codes:
        return f'{html.escape(base)} <span class="code">{",".join(html.escape(c) for c in codes)}</span>'
    return html.escape(base)


def render_html(menu, layout, special):
    css_cols = "columns:2;column-gap:32px;" if layout == "two_column" else ""
    dense = "font-size:12.5px;line-height:1.25;" if layout == "dense" else "font-size:14px;line-height:1.4;"
    blocks = []
    if special == "cover_page":
        blocks.append(f'<div class="cover"><div class="logo">✦</div>'
                      f'<h1>{html.escape(menu["venue"])}</h1>'
                      f'<div class="tag">herzlich willkommen</div></div>'
                      f'<div style="break-after:page"></div>')
    blocks.append(f'<div class="head"><h1>{html.escape(menu["venue"])}</h1></div>')
    blocks.append(f'<div class="cols" style="{css_cols}">')
    for cat in menu.get("categories", []):
        blocks.append(f'<div class="cat"><h2>{html.escape(cat["title"])}</h2>')
        for item in cat.get("items", []):
            price = ""
            if item.get("price_basis") == "per_person":
                price = f'{euro(item["price_cents"])} p. P.'
            elif item.get("price_cents") is not None:
                price = euro(item["price_cents"])
            desc = html.escape(item.get("description") or "")
            courses = item.get("courses")
            courses_html = f'<div class="courses">{html.escape(courses)}</div>' if courses else ""
            variants = item.get("variants") or []
            var_html = ""
            if variants:
                var_html = '<div class="vars">' + " · ".join(
                    f'{html.escape(v["name"])} {euro(v["price_cents"])}' for v in variants) + '</div>'
            blocks.append(
                f'<div class="item"><div class="row"><span class="nm">{name_with_codes(item)}</span>'
                f'<span class="pr">{html.escape(price)}</span></div>'
                f'<div class="ds">{desc}</div>{courses_html}{var_html}</div>')
        blocks.append('</div>')
    blocks.append('</div>')
    legend = menu.get("allergen_legend") or {}
    if legend:
        leg = " · ".join(f'<b>{html.escape(k)}</b> {html.escape(v)}' for k, v in legend.items())
        blocks.append(f'<div class="legend">Zusatzstoffe/Allergene: {leg}</div>')
    return f"""<!DOCTYPE html><html><head><meta charset="utf-8"><style>
    @page {{ size: A4; margin: 18mm; }}
    body {{ font-family: Georgia, 'Times New Roman', serif; color:#1a1a1a; {dense} }}
    .cover {{ text-align:center; padding-top:120px; }}
    .cover .logo {{ font-size:64px; }} .cover h1 {{ font-size:34px; letter-spacing:2px; }}
    .cover .tag {{ color:#777; font-style:italic; }}
    .head h1 {{ text-align:center; font-size:26px; letter-spacing:1px; border-bottom:2px solid #333; padding-bottom:8px; }}
    h2 {{ font-size:16px; text-transform:uppercase; letter-spacing:1px; border-bottom:1px solid #bbb; margin:14px 0 6px; }}
    .cat {{ break-inside:avoid; margin-bottom:10px; }}
    .item {{ break-inside:avoid; margin:5px 0; }}
    .row {{ display:flex; justify-content:space-between; gap:10px; }}
    .nm {{ font-weight:bold; }} .pr {{ white-space:nowrap; font-variant-numeric:tabular-nums; }}
    .ds {{ color:#555; font-size:0.9em; }} .courses {{ color:#444; font-size:0.9em; font-style:italic; }}
    .vars {{ color:#666; font-size:0.85em; }}
    .code {{ font-weight:normal; font-size:0.8em; vertical-align:super; color:#333; }}
    .legend {{ margin-top:18px; padding-top:8px; border-top:1px solid #ccc; font-size:0.8em; color:#666; }}
    </style></head><body>{''.join(blocks)}</body></html>"""


def render_pdf(html_str, pdf_path):
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False) as f:
        f.write(html_str)
        html_path = f.name
    try:
        subprocess.run(
            [CHROME, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
             f"--print-to-pdf={pdf_path}", f"file://{html_path}"],
            check=True, capture_output=True, timeout=120)
    finally:
        os.unlink(html_path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--count", type=int, default=10)
    ap.add_argument("--out", default="/tmp/kl-menu-corpus")
    ap.add_argument("--seed", type=int, default=1)
    args = ap.parse_args()
    random.seed(args.seed)

    pdf_dir = os.path.join(args.out, "pdf")
    truth_dir = os.path.join(args.out, "truth")
    os.makedirs(pdf_dir, exist_ok=True)
    os.makedirs(truth_dir, exist_ok=True)

    made, failed = 0, 0
    for i in range(args.count):
        cuisine = random.choice(CUISINES)
        layout = random.choice(LAYOUTS)
        special = random.choice(SPECIALS)
        ident = f"{i+1:03d}-{slug(cuisine)}-{layout}-{special}"
        try:
            menu = call_deepseek(spec_prompt(cuisine, layout, special))
            if not menu.get("categories"):
                raise ValueError("keine Kategorien")
            menu["_meta"] = {"cuisine": cuisine, "layout": layout, "special": special}
            html_str = render_html(menu, layout, special)
            render_pdf(html_str, os.path.join(pdf_dir, f"{ident}.pdf"))
            with open(os.path.join(truth_dir, f"{ident}.json"), "w") as f:
                json.dump(menu, f, ensure_ascii=False, indent=1)
            made += 1
            print(f"  ✓ {ident}: {sum(len(c['items']) for c in menu['categories'])} Artikel")
        except Exception as e:
            failed += 1
            print(f"  ✗ {ident}: {type(e).__name__}: {str(e)[:100]}", file=sys.stderr)

    print(f"\nFertig: {made} Karten erzeugt, {failed} fehlgeschlagen -> {args.out}")


if __name__ == "__main__":
    main()

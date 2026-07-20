#!/usr/bin/env python3
"""KL-SCAN-002: Automatisches Scoring der KI-Erfassung gegen die Ground Truth.

Vergleicht die KI-Ergebnisse aus einem Review-Report (report.json, Feld
llmDraftSections) mit den erwarteten Karten aus dem Truth-Ordner des
synthetischen Korpus. Misst pro Karte und aggregiert:

  - name_recall        Anteil der Wahrheits-Artikel, die die KI (Name) fand
  - price_accuracy     Anteil der gefundenen Artikel mit korrektem Preis
  - code_strip_ok      Anteil der KI-Namen OHNE hineingerutschte Allergencodes
  - spurious           von der KI erfundene Artikel (nicht in der Wahrheit)

Aufruf:
  python3 scripts/score_menu_corpus.py \\
      --report /tmp/kitchenlink-import-review/latest/report.json \\
      --truth  /tmp/kl-corpus-test/truth
"""
import argparse
import json
import re
import sys
import unicodedata

CODE_TAIL = re.compile(r"[\s,.(-]+(-?[a-z0-9](,[a-z0-9]{1,2})+[,.\-)]*|\([a-z0-9]{1,3}\))\s*$", re.I)


def norm(s):
    s = unicodedata.normalize("NFKD", s or "")
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = s.lower()
    s = re.sub(r"[^a-z0-9 ]+", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def strip_trailing_codes(name):
    prev = None
    cur = name
    while cur != prev:
        prev = cur
        cur = CODE_TAIL.sub("", cur).strip()
    return cur


def has_leftover_codes(name):
    return bool(CODE_TAIL.search(name or ""))


def truth_items(menu):
    out = []
    for cat in menu.get("categories", []):
        for it in cat.get("items", []):
            out.append({
                "name": it["name"],
                "price": it.get("price_cents"),
                "codes": [c.lower() for c in (it.get("allergen_codes") or [])],
            })
    return out


def ki_items(menu):
    out = []
    for sec in (menu.get("llmDraftSections") or []):
        for e in sec.get("entries", []):
            fixed = next((o for o in e.get("offers", [])
                          if o.get("priceKind") == "fixed" and o.get("amountCents") is not None), None)
            out.append({
                "name": e.get("name", ""),
                "price": fixed["amountCents"] if fixed else None,
                "codes": [d.get("localCode", "").lower() for d in e.get("declarations", []) if d.get("localCode")],
            })
    return out


def sanitize_id(raw):
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", raw.lower())).strip("-")


def score_menu(truth, ki):
    t_items = truth_items(truth)
    k_items = ki_items(ki)
    k_by_norm = {}
    for k in k_items:
        k_by_norm.setdefault(norm(strip_trailing_codes(k["name"])), []).append(k)

    matched = 0
    price_ok = 0
    used = set()
    for t in t_items:
        key = norm(t["name"])
        cand = None
        # exakte oder Teilstring-Übereinstimmung des normalisierten Namens
        for nk, lst in k_by_norm.items():
            if id(lst) in used:
                pass
            if nk == key or (key and (key in nk or nk in key)):
                free = [x for x in lst if id(x) not in used]
                if free:
                    cand = free[0]
                    break
        if cand:
            matched += 1
            used.add(id(cand))
            if t["price"] is not None and cand["price"] == t["price"]:
                price_ok += 1
    spurious = len(k_items) - matched
    code_clean = sum(1 for k in k_items if not has_leftover_codes(k["name"]))

    return {
        "truth_items": len(t_items),
        "ki_items": len(k_items),
        "matched": matched,
        "name_recall": matched / len(t_items) if t_items else 0.0,
        "price_accuracy": price_ok / matched if matched else 0.0,
        "code_strip_ok": code_clean / len(k_items) if k_items else 1.0,
        "spurious": max(0, spurious),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", required=True)
    ap.add_argument("--truth", required=True)
    args = ap.parse_args()

    report = json.load(open(args.report))
    import os
    truth_by_id = {}
    for fn in os.listdir(args.truth):
        if fn.endswith(".json"):
            truth_by_id[sanitize_id(fn[:-5])] = json.load(open(os.path.join(args.truth, fn)))

    rows = []
    for menu in report.get("menus", []):
        mid = menu.get("id", "")
        key = sanitize_id(mid[len("extra-"):] if mid.startswith("extra-") else mid)
        if key not in truth_by_id:
            continue
        s = score_menu(truth_by_id[key], menu)
        s["id"] = key
        s["error"] = menu.get("llmError")
        rows.append(s)

    if not rows:
        print("Keine übereinstimmenden Karten zwischen Report und Truth gefunden.", file=sys.stderr)
        sys.exit(1)

    print(f"{'Karte':<46} {'Recall':>7} {'Preis':>7} {'Codes':>7} {'Erfund.':>7}")
    print("-" * 80)
    for r in rows:
        print(f"{r['id'][:44]:<46} {r['name_recall']*100:6.0f}% {r['price_accuracy']*100:6.0f}% "
              f"{r['code_strip_ok']*100:6.0f}% {r['spurious']:>7}")
    n = len(rows)
    print("-" * 80)
    print(f"{'DURCHSCHNITT (' + str(n) + ' Karten)':<46} "
          f"{sum(r['name_recall'] for r in rows)/n*100:6.0f}% "
          f"{sum(r['price_accuracy'] for r in rows)/n*100:6.0f}% "
          f"{sum(r['code_strip_ok'] for r in rows)/n*100:6.0f}% "
          f"{sum(r['spurious'] for r in rows)/n:6.1f}")


if __name__ == "__main__":
    main()

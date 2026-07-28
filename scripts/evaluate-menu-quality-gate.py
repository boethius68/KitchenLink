#!/usr/bin/env python3
"""Score a KitchenLink import-review report against the Phase-1 ground truth."""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from copy import deepcopy
from difflib import SequenceMatcher
import hashlib
import json
from pathlib import Path
import re
import struct
import sys
import unicodedata


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_GATE_DIR = REPO_ROOT / "docs/test-fixtures/scanner-quality-gate"


def read_json(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def build_selected_pilot_gate(manifest, truth_by_fixture, selected_pages):
    """Project canonical ground truth onto a synthetic selected-page report.

    The import-review harness intentionally sends selected pages as one stack
    so a legitimate cover page cannot make the whole pilot fail as an empty
    menu. Its report therefore uses sequential page indexes and the fixture ID
    ``pilot-selection``. This function creates the matching in-memory gate
    without duplicating or weakening the canonical ground truth files.
    """
    documents = {
        document.get("fixtureID"): document
        for document in manifest.get("documents", [])
    }
    pilot_pages = []
    pilot_sections = []
    pilot_entries = []
    pilot_notices = []
    forbidden_entry_texts = []
    languages = []
    currencies = []

    for pilot_index, selection in enumerate(selected_pages):
        fixture_id, separator, raw_page_index = str(selection).rpartition(":")
        if not separator or not fixture_id:
            raise ValueError(f"invalid selected page {selection!r}")
        try:
            source_page_index = int(raw_page_index)
        except ValueError as error:
            raise ValueError(
                f"invalid selected page index in {selection!r}"
            ) from error

        document = documents.get(fixture_id)
        truth = truth_by_fixture.get(fixture_id)
        if not document or not truth:
            raise ValueError(f"unknown fixture in selected page {selection!r}")
        source_page = next(
            (
                page
                for page in document.get("pages", [])
                if page.get("pageIndex") == source_page_index
            ),
            None,
        )
        if source_page is None:
            raise ValueError(
                f"page {source_page_index} is not in the canonical gate "
                f"for {fixture_id}"
            )

        projected_page = deepcopy(source_page)
        projected_page["pageIndex"] = pilot_index
        projected_page["sourceFixtureID"] = fixture_id
        projected_page["sourcePageIndex"] = source_page_index
        pilot_pages.append(projected_page)

        for source, target in (
            (truth.get("sections", []), pilot_sections),
            (truth.get("entries", []), pilot_entries),
            (truth.get("notices", []), pilot_notices),
        ):
            for record in source:
                if record.get("pageIndex") != source_page_index:
                    continue
                projected_record = deepcopy(record)
                projected_record["pageIndex"] = pilot_index
                target.append(projected_record)

        forbidden_entry_texts.extend(truth.get("forbiddenEntryTexts", []))
        if truth.get("languageTag"):
            languages.append(truth["languageTag"])
        if truth.get("currencyCode"):
            currencies.append(truth["currencyCode"])

    pilot_truth = {
        "schemaVersion": "kitchenlink-menu-ground-truth/1.0.0",
        "fixtureID": "pilot-selection",
        "languageTag": languages[0] if languages else None,
        "currencyCode": currencies[0] if currencies else None,
        "sections": pilot_sections,
        "entries": pilot_entries,
        # Unscoped document declarations cannot safely be attributed to a
        # selected page. Page-scoped notices remain measurable above.
        "documentDeclarations": [],
        "expectedReviewCodes": [],
        "notices": pilot_notices,
        "forbiddenEntryTexts": list(dict.fromkeys(forbidden_entry_texts)),
    }
    pilot_manifest = {
        "schemaVersion": manifest.get("schemaVersion"),
        "selectedPageCount": len(pilot_pages),
        "documents": [{
            "fixtureID": "pilot-selection",
            "groundTruthFile": "(projected in memory)",
            "pages": pilot_pages,
        }],
    }
    return pilot_manifest, {"pilot-selection": pilot_truth}


def draft_from_snapshot(snapshot, mode):
    snapshot = snapshot or {}
    if mode == "llm":
        return (
            snapshot.get("llmDraft"),
            snapshot.get("llmDraftValidationErrors") or [],
        )
    return snapshot.get("draft"), snapshot.get("draftValidationErrors") or []


def nearest_rank(values, percentile):
    if not values:
        return None
    ordered = sorted(values)
    rank = max(1, (len(ordered) * percentile + 99) // 100)
    return ordered[min(len(ordered), rank) - 1]


def semantic_signature(snapshot, mode):
    draft, _ = draft_from_snapshot(snapshot, mode)
    if not isinstance(draft, dict):
        return "missing-draft"

    generated_id_paths = {}

    def collect_generated_ids(value, path="root"):
        if isinstance(value, dict):
            generated_id = value.get("id")
            if isinstance(generated_id, str):
                generated_id_paths[generated_id] = path
            for key, item in value.items():
                collect_generated_ids(item, f"{path}.{key}")
        elif isinstance(value, list):
            for index, item in enumerate(value):
                collect_generated_ids(item, f"{path}[{index}]")

    def canonicalize_generated_ids(value):
        if isinstance(value, dict):
            return {
                key: canonicalize_generated_ids(item)
                for key, item in value.items()
                if key != "id"
            }
        if isinstance(value, list):
            return [canonicalize_generated_ids(item) for item in value]
        if isinstance(value, str) and value in generated_id_paths:
            return {"generatedReference": generated_id_paths[value]}
        return value

    # Processing time, token use and generated IDs may vary without changing
    # the imported menu. Repeatability intentionally compares the complete
    # semantic result and its review findings.
    source_payload = {
        "sections": draft.get("sections") or [],
        "declarations": draft.get("declarations") or [],
        "reviewFindings": draft.get("reviewFindings") or [],
    }
    collect_generated_ids(source_payload)
    payload = canonicalize_generated_ids(source_payload)
    encoded = json.dumps(
        payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def measure_repeatability(reports, manifest, mode):
    run_count = len(reports)
    document_results = []
    matching_pairs = 0
    total_pairs = 0
    for document in manifest.get("documents", []):
        fixture_id = document["fixtureID"]
        signatures = []
        for report in reports:
            snapshots = {menu.get("id"): menu for menu in report.get("menus", [])}
            signatures.append(
                semantic_signature(snapshots.get(fixture_id), mode)
            )
        document_pairs = run_count * (run_count - 1) // 2
        document_matches = sum(
            1
            for left in range(run_count)
            for right in range(left + 1, run_count)
            if signatures[left] == signatures[right]
        )
        matching_pairs += document_matches
        total_pairs += document_pairs
        document_results.append({
            "fixtureID": fixture_id,
            "uniqueSemanticOutputs": len(set(signatures)),
            "matchingPairs": document_matches,
            "totalPairs": document_pairs,
            "exactPairwiseAgreement": (
                document_matches / document_pairs if document_pairs else None
            ),
        })
    return {
        "repeatRuns": run_count,
        "exactSemanticRepeatability": (
            matching_pairs / total_pairs if total_pairs else None
        ),
        "matchingDocumentPairs": matching_pairs,
        "totalDocumentPairs": total_pairs,
        "documents": document_results,
    }


def normalized(value) -> str:
    if value is None:
        return ""
    decomposed = unicodedata.normalize("NFKD", str(value))
    without_marks = "".join(
        character for character in decomposed
        if not unicodedata.combining(character)
    ).lower()
    return " ".join(re.findall(r"[a-z0-9]+", without_marks))


def exact_text(value) -> str:
    if value is None:
        return ""
    return unicodedata.normalize("NFC", str(value).strip())


def token(value) -> str:
    return normalized(value).replace(" ", "")


def canonical_price_kind(value) -> str:
    compact = token(value)
    return {
        "onrequest": "onrequest",
        "on_request": "onrequest",
    }.get(compact, compact)


def metric_counts(expected, actual):
    expected_counter = Counter(expected)
    actual_counter = Counter(actual)
    true_positive = sum((expected_counter & actual_counter).values())
    false_negative = sum((expected_counter - actual_counter).values())
    false_positive = sum((actual_counter - expected_counter).values())
    precision = true_positive / (true_positive + false_positive) if true_positive + false_positive else 1.0
    recall = true_positive / (true_positive + false_negative) if true_positive + false_negative else 1.0
    f1 = 2 * precision * recall / (precision + recall) if precision + recall else 0.0
    return {
        "truePositive": true_positive,
        "falsePositive": false_positive,
        "falseNegative": false_negative,
        "precision": precision,
        "recall": recall,
        "f1": f1,
    }


def png_dimensions(path: Path):
    with path.open("rb") as handle:
        header = handle.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    return struct.unpack(">II", header[16:24])


def validate_offer(offer, path, errors):
    kind = canonical_price_kind(offer.get("priceKind"))
    amount = offer.get("amountCents")
    delta = offer.get("deltaCents")
    minimum = offer.get("minimumAmountCents")
    maximum = offer.get("maximumAmountCents")
    valid = {
        "fixed": amount is not None and delta is None and minimum is None and maximum is None,
        "from": amount is None and delta is None and minimum is not None and maximum is None,
        "range": amount is None and delta is None and minimum is not None and maximum is not None
            and minimum <= maximum,
        "market": amount is None and delta is None and minimum is None and maximum is None,
        "onrequest": amount is None and delta is None and minimum is None and maximum is None,
        "included": amount is None and delta is None and minimum is None and maximum is None,
        "free": amount in (None, 0) and delta is None and minimum is None and maximum is None,
        "delta": amount is None and delta is not None and minimum is None and maximum is None,
        "unknown": amount is None and delta is None and minimum is None and maximum is None,
    }.get(kind, False)
    if not valid:
        errors.append(f"{path}: price fields contradict priceKind={offer.get('priceKind')!r}")


def walk_expected_offers(entry, prefix="entry"):
    result = [(prefix, offer) for offer in entry.get("offers", [])]
    for group in entry.get("optionGroups", []):
        group_name = normalized(group.get("title"))
        for choice in group.get("choices", []):
            offer = choice.get("offer")
            if offer:
                context = f"group:{group_name}:choice:{normalized(choice.get('name'))}"
                result.append((context, offer))
    for component in entry.get("bundleComponents", []):
        component_name = normalized(component.get("title"))
        for offer in component.get("offers", []):
            result.append((f"component:{component_name}", offer))
        group = component.get("optionGroup") or {}
        group_name = normalized(group.get("title"))
        for choice in group.get("choices", []):
            offer = choice.get("offer")
            if offer:
                context = (
                    f"component:{component_name}:group:{group_name}:"
                    f"choice:{normalized(choice.get('name'))}"
                )
                result.append((context, offer))
    return result


def walk_actual_offers(entry, prefix="entry"):
    result = [(prefix, offer) for offer in entry.get("offers") or []]
    for group in entry.get("optionGroups") or []:
        group_name = normalized((group.get("title") or {}).get("value"))
        for choice in group.get("choices") or []:
            for offer in choice.get("offers") or []:
                context = f"group:{group_name}:choice:{normalized((choice.get('name') or {}).get('value'))}"
                result.append((context, offer))
    for component in entry.get("bundleComponents") or []:
        component_name = normalized((component.get("title") or {}).get("value"))
        for offer in component.get("offers") or []:
            result.append((f"component:{component_name}", offer))
        group = component.get("optionGroup") or {}
        group_name = normalized((group.get("title") or {}).get("value"))
        for choice in group.get("choices") or []:
            for offer in choice.get("offers") or []:
                context = (
                    f"component:{component_name}:group:{group_name}:"
                    f"choice:{normalized((choice.get('name') or {}).get('value'))}"
                )
                result.append((context, offer))
    return result


def offer_key(context, offer, default_currency=None):
    label = offer.get("label")
    if isinstance(label, dict):
        label = label.get("value")
    return (
        context,
        normalized(label),
        canonical_price_kind(offer.get("priceKind")),
        offer.get("amountCents"),
        offer.get("deltaCents"),
        offer.get("minimumAmountCents"),
        offer.get("maximumAmountCents"),
        normalized(offer.get("currencyCode") or default_currency),
        normalized(offer.get("basis") or "unknown"),
        normalized(offer.get("rawPrice")),
    )


def describe_price_key(key):
    """Turns a safety price key back into something a human can look up."""
    context, kind, amount, delta, minimum, maximum = key
    amounts = {
        "amountCents": amount,
        "deltaCents": delta,
        "minimumAmountCents": minimum,
        "maximumAmountCents": maximum,
    }
    return {
        "context": context,
        "priceKind": kind,
        **{name: value for name, value in amounts.items() if value is not None},
    }


def safety_price_key(context, offer):
    return (
        context,
        canonical_price_kind(offer.get("priceKind")),
        offer.get("amountCents"),
        offer.get("deltaCents"),
        offer.get("minimumAmountCents"),
        offer.get("maximumAmountCents"),
    )


def selection_key(selection):
    selection = selection or {}
    return (
        selection.get("minimum"),
        selection.get("maximum"),
        selection.get("freeSelectionCount"),
        normalized(selection.get("mode") or "unknown"),
        selection.get("allowsRepeats"),
    )


def quantity_key(quantity):
    if not quantity:
        return None
    return (
        normalized(quantity.get("rawText")),
        quantity.get("value"),
        normalized(quantity.get("unit")),
        normalized(quantity.get("kind")),
    )


def expected_relation_keys(entry, default_currency=None):
    entry_name = normalized(entry.get("name"))
    result = []
    quantities = entry.get("quantities", [])
    for quantity in quantities:
        result.append(("entry_quantity", entry_name, quantity_key(quantity)))
    for offer_index, offer in enumerate(entry.get("offers", [])):
        quantity_order = offer.get("appliesToQuantityOrder")
        if quantity_order is None and len(quantities) == 1:
            quantity_order = 0
        if quantity_order is not None:
            target = (
                quantity_key(quantities[quantity_order])
                if 0 <= quantity_order < len(quantities)
                else "invalid"
            )
            result.append(("entry_offer_quantity", entry_name, offer_index, target))
    for group in entry.get("optionGroups", []):
        group_name = normalized(group.get("title"))
        result.append(("group", entry_name, group_name, selection_key(group.get("selection"))))
        for choice in group.get("choices", []):
            offer = choice.get("offer")
            result.append((
                "choice",
                entry_name,
                group_name,
                normalized(choice.get("name")),
                normalized(choice.get("description")),
                normalized(choice.get("kind")),
                quantity_key(choice.get("quantity")),
                offer_key("choice", offer, default_currency) if offer else None,
                (
                    choice.get("quantity") is None
                    or offer is None
                    or offer.get("appliesToQuantityOrder", 0) == 0
                ),
            ))
    for component in entry.get("bundleComponents", []):
        component_name = normalized(component.get("title"))
        result.append((
            "component",
            entry_name,
            component_name,
            normalized(component.get("description")),
            normalized(component.get("kind")),
            quantity_key(component.get("quantity")),
        ))
        component_quantities = [component["quantity"]] if component.get("quantity") else []
        for offer_index, offer in enumerate(component.get("offers", [])):
            quantity_order = offer.get("appliesToQuantityOrder")
            if quantity_order is None and len(component_quantities) == 1:
                quantity_order = 0
            if quantity_order is not None:
                target = (
                    quantity_key(component_quantities[quantity_order])
                    if 0 <= quantity_order < len(component_quantities)
                    else "invalid"
                )
                result.append((
                    "component_offer_quantity",
                    entry_name,
                    component_name,
                    offer_index,
                    target,
                ))
        group = component.get("optionGroup") or {}
        if group:
            group_name = normalized(group.get("title"))
            result.append((
                "bundle_group",
                entry_name,
                component_name,
                group_name,
                selection_key(group.get("selection")),
            ))
            for choice in group.get("choices", []):
                offer = choice.get("offer")
                result.append((
                    "bundle_choice",
                    entry_name,
                    component_name,
                    group_name,
                    normalized(choice.get("name")),
                    normalized(choice.get("description")),
                    normalized(choice.get("kind")),
                    quantity_key(choice.get("quantity")),
                    offer_key("choice", offer, default_currency) if offer else None,
                    (
                        choice.get("quantity") is None
                        or offer is None
                        or offer.get("appliesToQuantityOrder", 0) == 0
                    ),
                ))
    return result


def actual_relation_keys(entry):
    entry_name = normalized((entry.get("name") or {}).get("value"))
    result = []
    quantities = entry.get("quantities") or []
    for quantity in quantities:
        result.append(("entry_quantity", entry_name, quantity_key(quantity)))
    quantity_by_id = {
        quantity.get("id"): quantity_key(quantity)
        for quantity in quantities
        if quantity.get("id")
    }
    for offer_index, offer in enumerate(entry.get("offers") or []):
        if offer.get("appliesToQuantityID") is not None:
            result.append((
                "entry_offer_quantity",
                entry_name,
                offer_index,
                quantity_by_id.get(offer.get("appliesToQuantityID"), "invalid"),
            ))
    for group in entry.get("optionGroups") or []:
        group_name = normalized((group.get("title") or {}).get("value"))
        rule = group.get("selectionRule") or {}
        result.append(("group", entry_name, group_name, selection_key(rule)))
        for choice in group.get("choices") or []:
            offers = choice.get("offers") or []
            result.append((
                "choice",
                entry_name,
                group_name,
                normalized((choice.get("name") or {}).get("value")),
                normalized((choice.get("description") or {}).get("value")),
                normalized(choice.get("kind")),
                quantity_key(choice.get("quantity")),
                offer_key("choice", offers[0]) if offers else None,
                (
                    choice.get("quantity") is None
                    or not offers
                    or offers[0].get("appliesToQuantityID")
                        == (choice.get("quantity") or {}).get("id")
                ),
            ))
    for component in entry.get("bundleComponents") or []:
        component_name = normalized((component.get("title") or {}).get("value"))
        result.append((
            "component",
            entry_name,
            component_name,
            normalized((component.get("description") or {}).get("value")),
            normalized(component.get("kind")),
            quantity_key(component.get("quantity")),
        ))
        component_quantity = component.get("quantity")
        for offer_index, offer in enumerate(component.get("offers") or []):
            if offer.get("appliesToQuantityID") is not None:
                result.append((
                    "component_offer_quantity",
                    entry_name,
                    component_name,
                    offer_index,
                    (
                        quantity_key(component_quantity)
                        if offer.get("appliesToQuantityID")
                            == (component_quantity or {}).get("id")
                        else "invalid"
                    ),
                ))
        group = component.get("optionGroup") or {}
        if group:
            group_name = normalized((group.get("title") or {}).get("value"))
            result.append((
                "bundle_group",
                entry_name,
                component_name,
                group_name,
                selection_key(group.get("selectionRule")),
            ))
            for choice in group.get("choices") or []:
                offers = choice.get("offers") or []
                result.append((
                    "bundle_choice",
                    entry_name,
                    component_name,
                    group_name,
                    normalized((choice.get("name") or {}).get("value")),
                    normalized((choice.get("description") or {}).get("value")),
                    normalized(choice.get("kind")),
                    quantity_key(choice.get("quantity")),
                    offer_key("choice", offers[0]) if offers else None,
                    (
                        choice.get("quantity") is None
                        or not offers
                        or offers[0].get("appliesToQuantityID")
                            == (choice.get("quantity") or {}).get("id")
                    ),
                ))
    return result


def alternatives(text):
    if not text:
        return []
    return [
        alternative.get("value")
        for alternative in (text.get("alternatives") or [])
        if alternative.get("value")
    ]


def expected_translations(entry):
    values = list(entry.get("translations", []))
    for component in entry.get("bundleComponents", []):
        values.extend(component.get("translations", []))
        for choice in (component.get("optionGroup") or {}).get("choices", []):
            values.extend(choice.get("translations", []))
    return [normalized(value) for value in values]


def actual_translations(entry):
    values = alternatives(entry.get("name")) + alternatives(entry.get("description"))
    for component in entry.get("bundleComponents") or []:
        values.extend(alternatives(component.get("title")))
        values.extend(alternatives(component.get("description")))
        group = component.get("optionGroup") or {}
        values.extend(alternatives(group.get("title")))
        for choice in group.get("choices") or []:
            values.extend(alternatives(choice.get("name")))
            values.extend(alternatives(choice.get("description")))
    return [normalized(value) for value in values]


def walk_actual_declarations(draft):
    for declaration in draft.get("declarations") or []:
        yield declaration

    def visit_option_group(group):
        if not isinstance(group, dict):
            return
        for choice in group.get("choices") or []:
            for declaration in choice.get("declarations") or []:
                yield declaration

    def visit_entry(entry):
        for declaration in entry.get("declarations") or []:
            yield declaration
        for group in entry.get("optionGroups") or []:
            yield from visit_option_group(group)
        for component in entry.get("bundleComponents") or []:
            for declaration in component.get("declarations") or []:
                yield declaration
            yield from visit_option_group(component.get("optionGroup"))

    def visit_section(section):
        for declaration in section.get("declarations") or []:
            yield declaration
        for entry in section.get("entries") or []:
            yield from visit_entry(entry)
        for subsection in section.get("subsections") or []:
            yield from visit_section(subsection)

    for section in draft.get("sections") or []:
        yield from visit_section(section)


def actual_notice_records(draft):
    records = []
    for declaration in walk_actual_declarations(draft):
        if normalized(declaration.get("kind")) != "notice":
            continue
        evidence = declaration.get("evidence") or {}
        records.append({
            "pageIndex": evidence.get("pageIndex"),
            "rawText": declaration.get("rawText"),
            "alternatives": declaration.get("alternatives") or [],
            "evidence": evidence,
        })
    return records


def declaration_keys_expected(entry):
    result = [f"code:{normalized(code)}" for code in entry.get("declarationCodes", [])]
    result.extend(f"claim:{normalized(claim)}" for claim in entry.get("claims", []))
    for group in entry.get("optionGroups", []):
        for choice in group.get("choices", []):
            context = f"choice:{normalized(choice.get('name'))}:"
            result.extend(
                context + f"code:{normalized(code)}"
                for code in choice.get("declarationCodes", [])
            )
    return result


def declaration_keys_actual(entry):
    result = []
    for declaration in entry.get("declarations") or []:
        if declaration.get("localCode"):
            result.append(f"code:{normalized(declaration.get('localCode'))}")
        claim = normalized(declaration.get("claim"))
        if claim not in ("", "unknown", "declared"):
            result.append(f"claim:{claim}")
    for group in entry.get("optionGroups") or []:
        for choice in group.get("choices") or []:
            context = f"choice:{normalized((choice.get('name') or {}).get('value'))}:"
            for declaration in choice.get("declarations") or []:
                if declaration.get("localCode"):
                    result.append(context + f"code:{normalized(declaration.get('localCode'))}")
    return result


def document_declaration_key(declaration):
    local_code = declaration.get("localCode")
    kind = declaration.get("kind")
    if not kind and local_code:
        kind = "source_declaration"
    return (
        normalized(kind or "unknown"),
        normalized(local_code),
        normalized(declaration.get("canonicalID")),
        normalized(declaration.get("claim") or "unknown"),
        normalized(declaration.get("scope") or "document"),
        normalized(declaration.get("rawText")),
    )


def page_index_from_text(text):
    evidence = (text or {}).get("evidence") or {}
    return evidence.get("pageIndex")


def flatten_draft(draft):
    sections = []
    entries = []

    def visit(section, parent_path):
        title = section.get("title") or {}
        section_path = parent_path + [title.get("value") or ""]
        sections.append({
            "title": title,
            "pageIndex": page_index_from_text(title),
            "path": section_path,
            "raw": section,
        })
        for entry in section.get("entries") or []:
            entries.append({
                "pageIndex": page_index_from_text(entry.get("name")),
                "section": title.get("value") or "",
                "raw": entry,
            })
        for subsection in section.get("subsections") or []:
            visit(subsection, section_path)

    for section in (draft or {}).get("sections") or []:
        visit(section, [])
    return sections, entries


def actual_evidence_elements(draft):
    elements = []

    def add_evidence(path, visible_value, evidence, fallback_page=None):
        elements.append({
            "path": path,
            "visibleValue": visible_value,
            "evidence": evidence or {},
            "fallbackPage": fallback_page,
        })

    def add_text(path, text, fallback_page=None):
        if not isinstance(text, dict):
            return
        page_index = page_index_from_text(text)
        add_evidence(path, text.get("value"), text.get("evidence"), fallback_page)
        for index, alternative in enumerate(text.get("alternatives") or []):
            add_evidence(
                f"{path}.alternatives[{index}]",
                alternative.get("value"),
                alternative.get("evidence"),
                page_index if page_index is not None else fallback_page,
            )

    def add_declarations(path, declarations, fallback_page=None):
        for index, declaration in enumerate(declarations or []):
            add_evidence(
                f"{path}[{index}]",
                declaration.get("rawText"),
                declaration.get("evidence"),
                fallback_page,
            )
            declaration_page = (declaration.get("evidence") or {}).get(
                "pageIndex", fallback_page
            )
            for alternative_index, alternative in enumerate(
                declaration.get("alternatives") or []
            ):
                add_evidence(
                    f"{path}[{index}].alternatives[{alternative_index}]",
                    alternative.get("value"),
                    alternative.get("evidence"),
                    declaration_page,
                )

    def add_offer(path, offer, fallback_page=None):
        add_text(f"{path}.label", offer.get("label"), fallback_page)
        add_evidence(
            path,
            offer.get("rawPrice"),
            offer.get("evidence"),
            fallback_page,
        )

    def add_quantity(path, quantity, fallback_page=None):
        if not isinstance(quantity, dict):
            return
        add_evidence(
            path,
            quantity.get("rawText"),
            quantity.get("evidence"),
            fallback_page,
        )

    def add_option_group(path, group, fallback_page=None):
        if not isinstance(group, dict):
            return
        add_text(f"{path}.title", group.get("title"), fallback_page)
        for choice_index, choice in enumerate(group.get("choices") or []):
            choice_path = f"{path}.choices[{choice_index}]"
            choice_page = page_index_from_text(choice.get("name"))
            add_text(f"{choice_path}.name", choice.get("name"), fallback_page)
            add_text(
                f"{choice_path}.description",
                choice.get("description"),
                choice_page if choice_page is not None else fallback_page,
            )
            add_quantity(
                f"{choice_path}.quantity",
                choice.get("quantity"),
                choice_page if choice_page is not None else fallback_page,
            )
            for offer_index, offer in enumerate(choice.get("offers") or []):
                add_offer(
                    f"{choice_path}.offers[{offer_index}]",
                    offer,
                    choice_page if choice_page is not None else fallback_page,
                )
            add_declarations(
                f"{choice_path}.declarations",
                choice.get("declarations"),
                choice_page if choice_page is not None else fallback_page,
            )

    def visit_section(section, path):
        section_page = page_index_from_text(section.get("title"))
        add_text(f"{path}.title", section.get("title"), section_page)
        add_declarations(
            f"{path}.declarations",
            section.get("declarations"),
            section_page,
        )
        for entry_index, entry in enumerate(section.get("entries") or []):
            entry_path = f"{path}.entries[{entry_index}]"
            entry_page = page_index_from_text(entry.get("name"))
            add_text(f"{entry_path}.name", entry.get("name"), entry_page)
            add_text(f"{entry_path}.description", entry.get("description"), entry_page)
            for offer_index, offer in enumerate(entry.get("offers") or []):
                add_offer(f"{entry_path}.offers[{offer_index}]", offer, entry_page)
            for quantity_index, quantity in enumerate(entry.get("quantities") or []):
                add_quantity(
                    f"{entry_path}.quantities[{quantity_index}]",
                    quantity,
                    entry_page,
                )
            for group_index, group in enumerate(entry.get("optionGroups") or []):
                add_option_group(
                    f"{entry_path}.optionGroups[{group_index}]",
                    group,
                    entry_page,
                )
            for component_index, component in enumerate(
                entry.get("bundleComponents") or []
            ):
                component_path = f"{entry_path}.bundleComponents[{component_index}]"
                component_page = page_index_from_text(component.get("title"))
                add_text(f"{component_path}.title", component.get("title"), entry_page)
                add_text(
                    f"{component_path}.description",
                    component.get("description"),
                    component_page if component_page is not None else entry_page,
                )
                add_quantity(
                    f"{component_path}.quantity",
                    component.get("quantity"),
                    component_page if component_page is not None else entry_page,
                )
                for offer_index, offer in enumerate(component.get("offers") or []):
                    add_offer(
                        f"{component_path}.offers[{offer_index}]",
                        offer,
                        component_page if component_page is not None else entry_page,
                    )
                add_option_group(
                    f"{component_path}.optionGroup",
                    component.get("optionGroup"),
                    component_page if component_page is not None else entry_page,
                )
                add_declarations(
                    f"{component_path}.declarations",
                    component.get("declarations"),
                    component_page if component_page is not None else entry_page,
                )
            add_declarations(
                f"{entry_path}.declarations",
                entry.get("declarations"),
                entry_page,
            )
        for subsection_index, subsection in enumerate(section.get("subsections") or []):
            visit_section(subsection, f"{path}.subsections[{subsection_index}]")

    for section_index, section in enumerate(draft.get("sections") or []):
        visit_section(section, f"sections[{section_index}]")
    add_declarations("declarations", draft.get("declarations"), None)
    return elements


def evidence_element_is_covered(element, selected_pages):
    evidence = element["evidence"]
    page_index = evidence.get("pageIndex", element.get("fallbackPage"))
    return (
        evidence.get("isLocated") is True
        and page_index in selected_pages
        and bool(normalized(evidence.get("rawText")))
    )


def evidence_element_supports_value(element, selected_pages):
    if not evidence_element_is_covered(element, selected_pages):
        return False
    visible = normalized(element.get("visibleValue"))
    if not visible:
        return True
    raw = normalized(element["evidence"].get("rawText"))
    return visible in raw or raw in visible


def match_records(expected, actual, key_function):
    actual_by_key = defaultdict(list)
    for record in actual:
        actual_by_key[key_function(record)].append(record)
    pairs = []
    missing = []
    for record in expected:
        key = key_function(record)
        if actual_by_key[key]:
            pairs.append((record, actual_by_key[key].pop(0)))
        else:
            missing.append(record)
    extras = []
    for records in actual_by_key.values():
        extras.extend(records)
    return pairs, missing, extras


def evidence_matches(evidence, page_index, visible_text):
    if not evidence or not evidence.get("isLocated"):
        return False
    if evidence.get("pageIndex") != page_index:
        return False
    expected = normalized(visible_text)
    raw = normalized(evidence.get("rawText"))
    if not expected:
        return bool(raw)
    if expected in raw or raw in expected:
        return True
    expected_tokens = set(expected.split())
    raw_tokens = set(raw.split())
    return bool(expected_tokens) and len(expected_tokens & raw_tokens) / len(expected_tokens) >= 0.8


def expected_evidence_count(entry):
    count = 1
    if entry.get("description"):
        count += 1
    count += sum(1 for offer in entry.get("offers", []) if offer.get("rawPrice"))
    return count


def score_document(manifest_document, truth, snapshot, mode):
    selected_pages = {page["pageIndex"] for page in manifest_document["pages"]}
    page_kinds = {page["pageIndex"]: page["pageKind"] for page in manifest_document["pages"]}
    draft, validation_errors = draft_from_snapshot(snapshot, mode)

    missing_draft = not isinstance(draft, dict)
    draft = draft if isinstance(draft, dict) else {"sections": [], "declarations": []}
    actual_sections_all, actual_entries_all = flatten_draft(draft)
    actual_sections = [
        section for section in actual_sections_all
        if section.get("pageIndex") in selected_pages
    ]
    actual_entries = [
        entry for entry in actual_entries_all
        if entry.get("pageIndex") in selected_pages
    ]

    expected_sections = truth.get("sections", [])
    expected_entries = truth.get("entries", [])
    expected_notices = [
        notice
        for notice in truth.get("notices", [])
        if notice.get("pageIndex") in selected_pages
    ]
    expected_document_notice_texts = {
        normalized(declaration.get("rawText"))
        for declaration in truth.get("documentDeclarations", [])
        if normalized(declaration.get("kind")) == "notice"
    }
    actual_notices = [
        notice
        for notice in actual_notice_records(draft)
        if notice.get("pageIndex") in selected_pages
        and normalized(notice.get("rawText")) not in expected_document_notice_texts
    ]
    notice_key = lambda record: (
        record.get("pageIndex"),
        normalized(record.get("rawText")),
    )
    notice_pairs, missing_notices, extra_notices = match_records(
        expected_notices,
        actual_notices,
        notice_key,
    )
    default_currency = truth.get("currencyCode")
    section_key = lambda record: (
        record.get("pageIndex"),
        normalized(
            record.get("title")
            if isinstance(record.get("title"), str)
            else (record.get("title") or {}).get("value")
        ),
    )
    entry_key = lambda record: (
        record.get("pageIndex"),
        normalized(
            record.get("name")
            if isinstance(record.get("name"), str)
            else ((record.get("raw") or {}).get("name") or {}).get("value")
        ),
    )
    section_pairs, missing_sections, extra_sections = match_records(
        expected_sections, actual_sections, section_key
    )
    entry_pairs, missing_entries, extra_entries = match_records(
        expected_entries, actual_entries, entry_key
    )
    expected_name_exact_keys = [
        (entry.get("pageIndex"), exact_text(entry.get("name")))
        for entry in expected_entries
    ]
    actual_name_exact_keys = [
        (
            entry.get("pageIndex"),
            exact_text(((entry.get("raw") or {}).get("name") or {}).get("value")),
        )
        for entry in actual_entries
    ]
    name_exact_metrics = metric_counts(
        expected_name_exact_keys,
        actual_name_exact_keys,
    )
    expected_description_keys = [
        (
            entry.get("pageIndex"),
            normalized(entry.get("name")),
            normalized(entry.get("description")),
        )
        for entry in expected_entries
        if entry.get("description") is not None
    ]
    actual_description_keys = [
        (
            entry.get("pageIndex"),
            normalized(((entry.get("raw") or {}).get("name") or {}).get("value")),
            normalized(
                (((entry.get("raw") or {}).get("description") or {}).get("value"))
            ),
        )
        for entry in actual_entries
        if (((entry.get("raw") or {}).get("description") or {}).get("value"))
    ]
    description_counts = metric_counts(
        expected_description_keys,
        actual_description_keys,
    )
    expected_description_exact_keys = [
        (
            entry.get("pageIndex"),
            exact_text(entry.get("name")),
            exact_text(entry.get("description")),
        )
        for entry in expected_entries
        if entry.get("description") is not None
    ]
    actual_description_exact_keys = [
        (
            entry.get("pageIndex"),
            exact_text(((entry.get("raw") or {}).get("name") or {}).get("value")),
            exact_text(
                (((entry.get("raw") or {}).get("description") or {}).get("value"))
            ),
        )
        for entry in actual_entries
        if (((entry.get("raw") or {}).get("description") or {}).get("value"))
    ]
    description_exact_metrics = metric_counts(
        expected_description_exact_keys,
        actual_description_exact_keys,
    )

    expected_offer_keys = []
    actual_offer_keys = []
    expected_safety_prices = []
    actual_safety_prices = []
    expected_relations = []
    actual_relations = []
    expected_declarations = []
    actual_declarations = []
    expected_translation_values = []
    actual_translation_values = []
    category_assignment_total = len(expected_entries)
    category_assignment_correct = 0
    price_text_exact_total = 0
    price_text_exact_correct = 0
    price_basis_total = 0
    price_basis_correct = 0
    price_currency_total = 0
    price_currency_correct = 0
    forbidden_claim_hits = []
    evidence_total = 0
    evidence_pass = 0

    for expected, actual_wrapper in entry_pairs:
        actual = actual_wrapper["raw"]
        if normalized(expected.get("section")) == normalized(actual_wrapper.get("section")):
            category_assignment_correct += 1
        forbidden_claims = {
            normalized(claim) for claim in expected.get("forbiddenClaims", [])
        }
        for declaration in actual.get("declarations") or []:
            claim = normalized(declaration.get("claim"))
            if claim and claim in forbidden_claims:
                forbidden_claim_hits.append({
                    "entry": expected.get("name"),
                    "claim": declaration.get("claim"),
                })
        expected_walked_offers = list(walk_expected_offers(expected))
        actual_walked_offers = list(walk_actual_offers(actual))
        expected_offer_keys.extend(
            offer_key(context, offer, default_currency)
            for context, offer in expected_walked_offers
        )
        actual_offer_keys.extend(
            offer_key(context, offer) for context, offer in actual_walked_offers
        )
        expected_safety_prices.extend(
            safety_price_key(context, offer)
            for context, offer in expected_walked_offers
        )
        actual_safety_prices.extend(
            safety_price_key(context, offer)
            for context, offer in actual_walked_offers
        )
        expected_relations.extend(expected_relation_keys(expected, default_currency))
        actual_relations.extend(actual_relation_keys(actual))
        expected_declarations.extend(declaration_keys_expected(expected))
        actual_declarations.extend(declaration_keys_actual(actual))
        expected_translation_values.extend(expected_translations(expected))
        actual_translation_values.extend(actual_translations(actual))

        offer_pairs, missing_offers, _ = match_records(
            expected_walked_offers,
            actual_walked_offers,
            lambda record: safety_price_key(record[0], record[1]),
        )
        for (_, expected_offer), (_, actual_offer) in offer_pairs:
            price_basis_total += 1
            price_basis_correct += (
                normalized(expected_offer.get("basis") or "unknown")
                == normalized(actual_offer.get("basis") or "unknown")
            )
            price_currency_total += 1
            price_currency_correct += (
                normalized(expected_offer.get("currencyCode") or default_currency)
                == normalized(actual_offer.get("currencyCode"))
            )
            if expected_offer.get("rawPrice") is not None:
                price_text_exact_total += 1
                price_text_exact_correct += (
                    exact_text(expected_offer.get("rawPrice"))
                    == exact_text(actual_offer.get("rawPrice"))
                )
        for _, missing_offer in missing_offers:
            price_basis_total += 1
            price_currency_total += 1
            if missing_offer.get("rawPrice") is not None:
                price_text_exact_total += 1

        evidence_total += 1
        if evidence_matches(
            (actual.get("name") or {}).get("evidence"),
            expected["pageIndex"],
            expected.get("name"),
        ):
            evidence_pass += 1
        if expected.get("description"):
            evidence_total += 1
            if evidence_matches(
                (actual.get("description") or {}).get("evidence"),
                expected["pageIndex"],
                expected.get("description"),
            ):
                evidence_pass += 1

        actual_main_offers = {
            offer_key("entry", offer): offer
            for offer in actual.get("offers") or []
        }
        for offer in expected.get("offers", []):
            if not offer.get("rawPrice"):
                continue
            evidence_total += 1
            key = offer_key("entry", offer, default_currency)
            actual_offer = actual_main_offers.get(key)
            if actual_offer and evidence_matches(
                actual_offer.get("evidence"),
                expected["pageIndex"],
                offer.get("rawPrice"),
            ):
                evidence_pass += 1

    for expected in missing_entries:
        for _, missing_offer in walk_expected_offers(expected):
            price_basis_total += 1
            price_currency_total += 1
            if missing_offer.get("rawPrice") is not None:
                price_text_exact_total += 1
        expected_offer_keys.extend(
            offer_key(context, offer, default_currency)
            for context, offer in walk_expected_offers(expected)
        )
        expected_safety_prices.extend(
            safety_price_key(context, offer)
            for context, offer in walk_expected_offers(expected)
        )
        expected_relations.extend(expected_relation_keys(expected, default_currency))
        expected_declarations.extend(declaration_keys_expected(expected))
        expected_translation_values.extend(expected_translations(expected))
        evidence_total += expected_evidence_count(expected)

    for extra in extra_entries:
        actual = extra["raw"]
        actual_offer_keys.extend(
            offer_key(context, offer) for context, offer in walk_actual_offers(actual)
        )
        actual_safety_prices.extend(
            safety_price_key(context, offer)
            for context, offer in walk_actual_offers(actual)
        )
        actual_relations.extend(actual_relation_keys(actual))
        actual_declarations.extend(declaration_keys_actual(actual))
        actual_translation_values.extend(actual_translations(actual))

    expected_document_declarations = [
        document_declaration_key(declaration)
        for declaration in truth.get("documentDeclarations", [])
    ]
    actual_document_declarations = [
        document_declaration_key(declaration)
        for declaration in draft.get("declarations") or []
        if not (
            normalized(declaration.get("kind")) == "notice"
            and normalized(declaration.get("rawText"))
                not in expected_document_notice_texts
        )
    ]
    expected_declarations.extend(expected_document_declarations)
    actual_declarations.extend(actual_document_declarations)

    expected_translation_values.extend(
        normalized(translation)
        for notice in expected_notices
        for translation in notice.get("translations", [])
    )
    actual_translation_values.extend(
        normalized(alternative.get("value"))
        for notice in actual_notices
        for alternative in notice.get("alternatives", [])
        if alternative.get("value")
    )

    for expected_notice, actual_notice in notice_pairs:
        evidence_total += 1
        if evidence_matches(
            actual_notice.get("evidence"),
            expected_notice.get("pageIndex"),
            expected_notice.get("rawText"),
        ):
            evidence_pass += 1
        actual_alternatives = {
            normalized(alternative.get("value")): alternative
            for alternative in actual_notice.get("alternatives", [])
            if alternative.get("value")
        }
        for translation in expected_notice.get("translations", []):
            evidence_total += 1
            alternative = actual_alternatives.get(normalized(translation))
            if alternative and evidence_matches(
                alternative.get("evidence"),
                expected_notice.get("pageIndex"),
                translation,
            ):
                evidence_pass += 1
    evidence_total += sum(
        1 + len(notice.get("translations", []))
        for notice in missing_notices
    )

    for expected, actual in section_pairs:
        evidence_total += 1
        if evidence_matches(
            (actual["title"] or {}).get("evidence"),
            expected["pageIndex"],
            expected["title"],
        ):
            evidence_pass += 1
    evidence_total += len(missing_sections)

    extracted_evidence_elements = [
        element
        for element in actual_evidence_elements(draft)
        if element.get("fallbackPage") in selected_pages
        or (element.get("evidence") or {}).get("pageIndex") in selected_pages
    ]
    extracted_evidence_covered = sum(
        evidence_element_is_covered(element, selected_pages)
        for element in extracted_evidence_elements
    )
    extracted_evidence_supported = sum(
        evidence_element_supports_value(element, selected_pages)
        for element in extracted_evidence_elements
    )

    expected_review_codes = list(truth.get("expectedReviewCodes", []))
    for entry in expected_entries:
        expected_review_codes.extend(entry.get("expectedReviewCodes", []))
    actual_review_codes = [
        finding.get("code")
        for finding in draft.get("reviewFindings") or []
        if finding.get("pageIndex") in selected_pages or finding.get("pageIndex") is None
    ]
    expected_review_set = set(expected_review_codes)
    actual_review_set = set(actual_review_codes)
    review_recall = (
        len(expected_review_set & actual_review_set) / len(expected_review_set)
        if expected_review_set else 1.0
    )

    outcomes = {
        outcome.get("pageIndex"): outcome
        for outcome in ((draft.get("processing") or {}).get("pageOutcomes") or [])
    }
    silent_pages = [
        page_index for page_index in sorted(selected_pages)
        if page_index not in outcomes or outcomes[page_index].get("status") == "failed"
    ]
    cover_pages = {
        page_index for page_index, kind in page_kinds.items() if kind == "cover"
    }
    cover_false_positives = sum(
        1 for entry in actual_entries_all if entry.get("pageIndex") in cover_pages
    )
    failed_pages = [
        page_index
        for page_index in sorted(selected_pages)
        if page_index not in outcomes
        or outcomes[page_index].get("status") in ("failed", "fallback")
    ]
    page_latencies = [
        outcome.get("latencyMilliseconds")
        for page_index, outcome in outcomes.items()
        if page_index in selected_pages
        and isinstance(outcome.get("latencyMilliseconds"), int)
        and outcome.get("latencyMilliseconds") >= 0
    ]
    attempts = sum(
        max(0, outcome.get("attempts") or 0)
        for page_index, outcome in outcomes.items()
        if page_index in selected_pages
    )
    usage = (draft.get("processing") or {}).get("usage") or {}

    forbidden = {normalized(value) for value in truth.get("forbiddenEntryTexts", [])}
    forbidden_hits = [
        ((entry.get("raw") or {}).get("name") or {}).get("value")
        for entry in actual_entries
        if normalized(((entry.get("raw") or {}).get("name") or {}).get("value")) in forbidden
    ]
    offer_metrics = metric_counts(expected_offer_keys, actual_offer_keys)
    safety_price_metrics = metric_counts(expected_safety_prices, actual_safety_prices)
    relation_metrics = metric_counts(expected_relations, actual_relations)
    declaration_metrics = metric_counts(expected_declarations, actual_declarations)
    notice_metrics = metric_counts(
        [notice_key(notice) for notice in expected_notices],
        [notice_key(notice) for notice in actual_notices],
    )
    translation_metrics = metric_counts(
        expected_translation_values, actual_translation_values
    )

    fuzzy = []
    extra_names = [
        ((extra.get("raw") or {}).get("name") or {}).get("value") or ""
        for extra in extra_entries
    ]
    for missing in missing_entries:
        expected_name = missing.get("name") or ""
        if not extra_names:
            continue
        candidate = max(
            extra_names,
            key=lambda name: SequenceMatcher(
                None, normalized(expected_name), normalized(name)
            ).ratio(),
        )
        similarity = SequenceMatcher(
            None, normalized(expected_name), normalized(candidate)
        ).ratio()
        if similarity >= 0.55:
            fuzzy.append({
                "expected": expected_name,
                "actual": candidate,
                "similarity": similarity,
            })

    return {
        "fixtureID": manifest_document["fixtureID"],
        "missingDraft": missing_draft,
        "sectionCounts": metric_counts(
            [section_key(record) for record in expected_sections],
            [section_key(record) for record in actual_sections],
        ),
        "entryCounts": metric_counts(
            [entry_key(record) for record in expected_entries],
            [entry_key(record) for record in actual_entries],
        ),
        "nameExact": {
            **name_exact_metrics,
            "accuracy": (
                name_exact_metrics["truePositive"]
                / (
                    name_exact_metrics["truePositive"]
                    + name_exact_metrics["falsePositive"]
                    + name_exact_metrics["falseNegative"]
                )
                if (
                    name_exact_metrics["truePositive"]
                    + name_exact_metrics["falsePositive"]
                    + name_exact_metrics["falseNegative"]
                )
                else 1.0
            ),
        },
        "categoryAssignment": {
            "correct": category_assignment_correct,
            "total": category_assignment_total,
            "accuracy": (
                category_assignment_correct / category_assignment_total
                if category_assignment_total else 1.0
            ),
        },
        "descriptionCounts": description_counts,
        "descriptionExact": {
            **description_exact_metrics,
            "accuracy": (
                description_exact_metrics["truePositive"]
                / (
                    description_exact_metrics["truePositive"]
                    + description_exact_metrics["falsePositive"]
                    + description_exact_metrics["falseNegative"]
                )
                if (
                    description_exact_metrics["truePositive"]
                    + description_exact_metrics["falsePositive"]
                    + description_exact_metrics["falseNegative"]
                )
                else 1.0
            ),
        },
        "offerCounts": offer_metrics,
        "priceFields": {
            "rawTextExact": {
                "correct": price_text_exact_correct,
                "total": price_text_exact_total,
                "accuracy": (
                    price_text_exact_correct / price_text_exact_total
                    if price_text_exact_total else 1.0
                ),
            },
            "basis": {
                "correct": price_basis_correct,
                "total": price_basis_total,
                "accuracy": (
                    price_basis_correct / price_basis_total
                    if price_basis_total else 1.0
                ),
            },
            "currency": {
                "correct": price_currency_correct,
                "total": price_currency_total,
                "accuracy": (
                    price_currency_correct / price_currency_total
                    if price_currency_total else 1.0
                ),
            },
        },
        "relationCounts": relation_metrics,
        "declarationCounts": declaration_metrics,
        "noticeCounts": notice_metrics,
        "translationCounts": translation_metrics,
        "evidence": {
            "correct": extracted_evidence_covered,
            "supported": extracted_evidence_supported,
            "total": len(extracted_evidence_elements),
            "coverage": (
                extracted_evidence_covered / len(extracted_evidence_elements)
                if extracted_evidence_elements else 1.0
            ),
            "supportAccuracy": (
                extracted_evidence_supported / len(extracted_evidence_elements)
                if extracted_evidence_elements else 1.0
            ),
        },
        "groundTruthEvidence": {
            "correct": evidence_pass,
            "total": evidence_total,
            "accuracy": evidence_pass / evidence_total if evidence_total else 1.0,
        },
        "reviews": {
            "expected": sorted(expected_review_set),
            "actual": sorted(actual_review_set),
            "recall": review_recall,
        },
        "operational": {
            "provider": (draft.get("processing") or {}).get("provider"),
            "model": (draft.get("processing") or {}).get("model"),
            "selectedPages": len(selected_pages),
            "reportedPageOutcomes": sum(
                1 for page_index in outcomes if page_index in selected_pages
            ),
            "failedPages": len(failed_pages),
            "failedPageIndexes": failed_pages,
            "pageFailureRate": (
                len(failed_pages) / len(selected_pages) if selected_pages else 0
            ),
            "pageLatenciesMilliseconds": page_latencies,
            "latencyCoverage": (
                len(page_latencies) / len(selected_pages) if selected_pages else 1
            ),
            "attempts": attempts,
            "retries": max(0, attempts - len(selected_pages)),
            "tokenUsage": {
                "inputTokens": usage.get("inputTokens"),
                "outputTokens": usage.get("outputTokens"),
                "totalTokens": usage.get("totalTokens"),
            },
        },
        "safety": {
            "missingItems": len(missing_entries),
            "inventedItems": len(extra_entries),
            "inventedPrices": safety_price_metrics["falsePositive"],
            "forbiddenClaimHits": len(forbidden_claim_hits),
            "coverFalsePositives": cover_false_positives,
            "silentPageLosses": len(silent_pages),
            "validationErrors": len(validation_errors) + (1 if missing_draft else 0),
        },
        "diagnostics": {
            "missingEntries": [entry.get("name") for entry in missing_entries],
            "extraEntries": [
                ((entry.get("raw") or {}).get("name") or {}).get("value")
                for entry in extra_entries
            ],
            "missingSections": [section.get("title") for section in missing_sections],
            "extraSections": [
                (section.get("title") or {}).get("value") for section in extra_sections
            ],
            "missingNotices": [
                notice.get("rawText") for notice in missing_notices
            ],
            "extraNotices": [
                notice.get("rawText") for notice in extra_notices
            ],
            # inventedPrices is a hard-gate count and one third of the headline
            # correctionsPerPage, so the report has to say WHICH prices it
            # means — otherwise the number cannot be acted on.
            "inventedPrices": [
                describe_price_key(key)
                for key in (Counter(actual_safety_prices) - Counter(expected_safety_prices)).elements()
            ],
            "missingPrices": [
                describe_price_key(key)
                for key in (Counter(expected_safety_prices) - Counter(actual_safety_prices)).elements()
            ],
            "forbiddenEntryHits": forbidden_hits,
            "forbiddenClaimHits": forbidden_claim_hits,
            "uncoveredEvidencePaths": [
                element["path"]
                for element in extracted_evidence_elements
                if not evidence_element_is_covered(element, selected_pages)
            ][:30],
            "unsupportedEvidencePaths": [
                element["path"]
                for element in extracted_evidence_elements
                if not evidence_element_supports_value(element, selected_pages)
            ][:30],
            "silentPages": silent_pages,
            "fuzzyNameHints": fuzzy[:12],
        },
    }


def aggregate_results(document_results):
    def combine_count_block(key):
        # Reconstruct aggregate counts directly from TP/FP/FN.
        true_positive = sum(result[key]["truePositive"] for result in document_results)
        false_positive = sum(result[key]["falsePositive"] for result in document_results)
        false_negative = sum(result[key]["falseNegative"] for result in document_results)
        precision = true_positive / (true_positive + false_positive) if true_positive + false_positive else 1.0
        recall = true_positive / (true_positive + false_negative) if true_positive + false_negative else 1.0
        f1 = 2 * precision * recall / (precision + recall) if precision + recall else 0.0
        return {
            "truePositive": true_positive,
            "falsePositive": false_positive,
            "falseNegative": false_negative,
            "precision": precision,
            "recall": recall,
            "f1": f1,
        }

    name_exact_true_positive = sum(
        result["nameExact"]["truePositive"] for result in document_results
    )
    name_exact_union = sum(
        result["nameExact"]["truePositive"]
        + result["nameExact"]["falsePositive"]
        + result["nameExact"]["falseNegative"]
        for result in document_results
    )
    category_correct = sum(
        result["categoryAssignment"]["correct"] for result in document_results
    )
    category_total = sum(
        result["categoryAssignment"]["total"] for result in document_results
    )
    description_exact_true_positive = sum(
        result["descriptionExact"]["truePositive"] for result in document_results
    )
    description_exact_union = sum(
        result["descriptionExact"]["truePositive"]
        + result["descriptionExact"]["falsePositive"]
        + result["descriptionExact"]["falseNegative"]
        for result in document_results
    )

    def sum_accuracy(path):
        correct = sum(
            result["priceFields"][path]["correct"] for result in document_results
        )
        total = sum(
            result["priceFields"][path]["total"] for result in document_results
        )
        return correct, total

    price_text_correct, price_text_total = sum_accuracy("rawTextExact")
    price_basis_correct, price_basis_total = sum_accuracy("basis")
    price_currency_correct, price_currency_total = sum_accuracy("currency")
    evidence_correct = sum(result["evidence"]["correct"] for result in document_results)
    evidence_supported = sum(
        result["evidence"]["supported"] for result in document_results
    )
    evidence_total = sum(result["evidence"]["total"] for result in document_results)
    ground_truth_evidence_correct = sum(
        result["groundTruthEvidence"]["correct"] for result in document_results
    )
    ground_truth_evidence_total = sum(
        result["groundTruthEvidence"]["total"] for result in document_results
    )
    expected_reviews = set()
    actual_reviews = set()
    for result in document_results:
        expected_reviews.update(result["reviews"]["expected"])
        actual_reviews.update(result["reviews"]["actual"])

    safety = {
        key: sum(result["safety"][key] for result in document_results)
        for key in (
            "missingItems",
            "inventedItems",
            "inventedPrices",
            "forbiddenClaimHits",
            "coverFalsePositives",
            "silentPageLosses",
            "validationErrors",
        )
    }
    operational_blocks = [result["operational"] for result in document_results]
    page_latencies = [
        latency
        for block in operational_blocks
        for latency in block["pageLatenciesMilliseconds"]
    ]
    selected_pages = sum(block["selectedPages"] for block in operational_blocks)
    failed_pages = sum(block["failedPages"] for block in operational_blocks)
    measured_pages = len(page_latencies)

    def summed_usage(key):
        values = [
            block["tokenUsage"].get(key)
            for block in operational_blocks
            if block["tokenUsage"].get(key) is not None
        ]
        return sum(values) if values else None

    # The launch profile is recall-first: a human resolves every flagged entry
    # before publishing, so an entry the extractor never produced is the one
    # error the review cannot repair.
    entry_recall = combine_count_block("entryCounts")["recall"]
    # Headline effort metric: how many entries a person has to add, delete or
    # reprice per page. Derived purely from the existing hard-gate counts.
    corrections_per_page = (
        (safety["missingItems"] + safety["inventedItems"] + safety["inventedPrices"])
        / selected_pages
        if selected_pages
        else 0.0
    )

    return {
        "sectionF1": combine_count_block("sectionCounts")["f1"],
        "entryF1": combine_count_block("entryCounts")["f1"],
        "entryRecall": entry_recall,
        "correctionsPerPage": corrections_per_page,
        "nameExactAccuracy": (
            name_exact_true_positive / name_exact_union
            if name_exact_union else 1.0
        ),
        "categoryAssignmentAccuracy": (
            category_correct / category_total if category_total else 1.0
        ),
        "descriptionF1": combine_count_block("descriptionCounts")["f1"],
        "descriptionExactAccuracy": (
            description_exact_true_positive / description_exact_union
            if description_exact_union else 1.0
        ),
        "offerF1": combine_count_block("offerCounts")["f1"],
        "priceTextExactAccuracy": (
            price_text_correct / price_text_total if price_text_total else 1.0
        ),
        "priceBasisAccuracy": (
            price_basis_correct / price_basis_total if price_basis_total else 1.0
        ),
        "currencyAccuracy": (
            price_currency_correct / price_currency_total
            if price_currency_total else 1.0
        ),
        "relationF1": combine_count_block("relationCounts")["f1"],
        "declarationF1": combine_count_block("declarationCounts")["f1"],
        "noticeF1": combine_count_block("noticeCounts")["f1"],
        "translationF1": combine_count_block("translationCounts")["f1"],
        "evidenceCoverage": evidence_correct / evidence_total if evidence_total else 1.0,
        "evidenceSupportAccuracy": (
            evidence_supported / evidence_total if evidence_total else 1.0
        ),
        "groundTruthEvidenceAccuracy": (
            ground_truth_evidence_correct / ground_truth_evidence_total
            if ground_truth_evidence_total else 1.0
        ),
        "expectedReviewRecall": (
            len(expected_reviews & actual_reviews) / len(expected_reviews)
            if expected_reviews else 1.0
        ),
        "operational": {
            "providers": sorted({
                block["provider"] for block in operational_blocks if block["provider"]
            }),
            "models": sorted({
                block["model"] for block in operational_blocks if block["model"]
            }),
            "selectedPages": selected_pages,
            "failedPages": failed_pages,
            "pageFailureRate": (
                failed_pages / selected_pages if selected_pages else 0
            ),
            "measuredLatencyPages": measured_pages,
            "latencyCoverage": (
                measured_pages / selected_pages if selected_pages else 1
            ),
            "p50PageLatencyMilliseconds": nearest_rank(page_latencies, 50),
            "p95PageLatencyMilliseconds": nearest_rank(page_latencies, 95),
            "maximumPageLatencyMilliseconds": max(page_latencies) if page_latencies else None,
            "attempts": sum(block["attempts"] for block in operational_blocks),
            "retries": sum(block["retries"] for block in operational_blocks),
            "tokenUsage": {
                "inputTokens": summed_usage("inputTokens"),
                "outputTokens": summed_usage("outputTokens"),
                "totalTokens": summed_usage("totalTokens"),
            },
        },
        "safety": safety,
        "counts": {
            "sections": combine_count_block("sectionCounts"),
            "entries": combine_count_block("entryCounts"),
            "offers": combine_count_block("offerCounts"),
            "relations": combine_count_block("relationCounts"),
            "declarations": combine_count_block("declarationCounts"),
            "notices": combine_count_block("noticeCounts"),
            "translations": combine_count_block("translationCounts"),
            "descriptions": combine_count_block("descriptionCounts"),
            "descriptionExact": {
                "correct": description_exact_true_positive,
                "union": description_exact_union,
            },
            "namesExact": {
                "correct": name_exact_true_positive,
                "union": name_exact_union,
            },
            "categories": {"correct": category_correct, "total": category_total},
            "priceTextExact": {
                "correct": price_text_correct,
                "total": price_text_total,
            },
            "priceBasis": {
                "correct": price_basis_correct,
                "total": price_basis_total,
            },
            "currency": {
                "correct": price_currency_correct,
                "total": price_currency_total,
            },
            "evidence": {
                "correct": evidence_correct,
                "supported": evidence_supported,
                "total": evidence_total,
            },
            "groundTruthEvidence": {
                "correct": ground_truth_evidence_correct,
                "total": ground_truth_evidence_total,
            },
        },
    }


def validate_ground_truth(gate_dir: Path):
    errors = []
    manifest = read_json(gate_dir / "manifest.json")
    policy = read_json(gate_dir / "policy.json")
    if manifest.get("schemaVersion") != "kitchenlink-menu-quality-gate-manifest/1.0.0":
        errors.append("manifest.json: unsupported schemaVersion")
    if policy.get("schemaVersion") != "kitchenlink-menu-quality-policy/1.3.0":
        errors.append("policy.json: unsupported schemaVersion")
    elif not isinstance(policy.get("profiles"), dict) or not policy["profiles"]:
        errors.append("policy.json: no threshold profiles defined")
    elif policy.get("defaultProfile") not in policy["profiles"]:
        errors.append("policy.json: defaultProfile is not one of profiles")

    page_keys = set()
    page_hashes = set()
    truth_by_fixture = {}
    total_pages = 0
    for document in manifest.get("documents", []):
        fixture_id = document.get("fixtureID")
        truth_path = gate_dir / document.get("groundTruthFile", "")
        if not truth_path.is_file():
            errors.append(f"{fixture_id}: missing {truth_path.name}")
            continue
        truth = read_json(truth_path)
        truth_by_fixture[fixture_id] = truth
        if truth.get("fixtureID") != fixture_id:
            errors.append(f"{truth_path.name}: fixtureID does not match manifest")
        selected_pages = {page.get("pageIndex") for page in document.get("pages", [])}
        section_keys = {
            (section.get("pageIndex"), normalized(section.get("title")))
            for section in truth.get("sections", [])
        }
        entry_keys = set()
        for entry_index, entry in enumerate(truth.get("entries", [])):
            key = (entry.get("pageIndex"), normalized(entry.get("name")))
            if key in entry_keys:
                errors.append(f"{truth_path.name}: duplicate entry {key}")
            entry_keys.add(key)
            if entry.get("pageIndex") not in selected_pages:
                errors.append(f"{truth_path.name}: entry outside selected pages: {entry.get('name')}")
            section_key = (entry.get("pageIndex"), normalized(entry.get("section")))
            if section_key not in section_keys:
                errors.append(f"{truth_path.name}: missing section for {entry.get('name')}")
            for offer_index, offer in enumerate(entry.get("offers", [])):
                validate_offer(
                    offer,
                    f"{truth_path.name}.entries[{entry_index}].offers[{offer_index}]",
                    errors,
                )
            for context, offer in walk_expected_offers(entry):
                validate_offer(
                    offer,
                    f"{truth_path.name}.entries[{entry_index}].{context}",
                    errors,
                )
        for notice_index, notice in enumerate(truth.get("notices", [])):
            notice_path = f"{truth_path.name}.notices[{notice_index}]"
            if notice.get("pageIndex") not in selected_pages:
                errors.append(f"{notice_path}: pageIndex outside selected pages")
            if not normalized(notice.get("rawText")):
                errors.append(f"{notice_path}: rawText must not be empty")
            if not isinstance(notice.get("translations", []), list):
                errors.append(f"{notice_path}: translations must be an array")

        for page in document.get("pages", []):
            total_pages += 1
            page_key = (fixture_id, page.get("pageIndex"))
            if page_key in page_keys:
                errors.append(f"manifest.json: duplicate page {page_key}")
            page_keys.add(page_key)
            if page.get("sha256") in page_hashes:
                errors.append(f"manifest.json: duplicate page hash {page.get('sha256')}")
            page_hashes.add(page.get("sha256"))
            resource = REPO_ROOT / page.get("resourcePath", "")
            if not resource.is_file():
                errors.append(f"manifest.json: missing resource {resource}")
                continue
            digest = hashlib.sha256(resource.read_bytes()).hexdigest()
            if digest != page.get("sha256"):
                errors.append(f"manifest.json: SHA mismatch for {resource.name}")
            try:
                width, height = png_dimensions(resource)
                if width != page.get("pixelWidth") or height != page.get("pixelHeight"):
                    errors.append(f"manifest.json: dimension mismatch for {resource.name}")
            except ValueError as error:
                errors.append(f"manifest.json: {resource.name}: {error}")
            if page.get("pageKind") == "cover":
                cover_entries = [
                    entry for entry in truth.get("entries", [])
                    if entry.get("pageIndex") == page.get("pageIndex")
                ]
                if cover_entries:
                    errors.append(f"{truth_path.name}: cover page contains expected entries")

    if total_pages != manifest.get("selectedPageCount"):
        errors.append(
            f"manifest.json: selectedPageCount={manifest.get('selectedPageCount')} "
            f"but found {total_pages}"
        )
    return manifest, policy, truth_by_fixture, errors


def repeatability_enforcement_failures(repeatability, policy):
    failures = []
    operational_targets = policy.get("operationalTargets", {})
    minimum_repeat_runs = operational_targets.get("minimumRepeatRuns")
    repeat_runs = repeatability.get("repeatRuns", 0)
    if minimum_repeat_runs is not None and repeat_runs < minimum_repeat_runs:
        failures.append(f"repeatRuns {repeat_runs} < {minimum_repeat_runs}")
    minimum_repeatability = operational_targets.get(
        "minimumExactSemanticRepeatability"
    )
    actual_repeatability = repeatability.get("exactSemanticRepeatability")
    if minimum_repeatability is not None:
        if actual_repeatability is None:
            failures.append("exactSemanticRepeatability not measured")
        elif actual_repeatability + 1e-12 < minimum_repeatability:
            failures.append(
                "exactSemanticRepeatability "
                f"{actual_repeatability:.3f} < {minimum_repeatability:.3f}"
            )
    return failures


def resolve_policy_profile(policy, profile_name):
    """Return one named threshold profile from policy.json.

    The gate carries two profiles on purpose. `strict` describes an
    unsupervised, deterministic extractor; no LLM-based pipeline can pass it,
    because exact semantic repeatability across runs is structurally far below
    its target. `launch` is the release-relevant bar for the product that
    actually exists: every draft passes a mandatory human review
    (`MenuImportDraftReviewModel.canConvert`), so precision errors are
    correctable and only unrecoverable losses block a release.
    """
    profiles = policy.get("profiles")
    if not isinstance(profiles, dict) or not profiles:
        # Older policy files carried the strict thresholds at the top level.
        return policy
    if profile_name not in profiles:
        available = ", ".join(sorted(profiles))
        raise ValueError(f"unknown profile '{profile_name}' (available: {available})")
    return profiles[profile_name]


def enforcement_failures(metrics, policy, include_repeatability=True):
    failures = []
    for metric, target in policy.get("measurementTargets", {}).items():
        actual = metrics.get(metric, 0)
        if actual + 1e-12 < target:
            failures.append(f"{metric} {actual:.3f} < {target:.3f}")
    for metric, maximum in policy.get("maximumTargets", {}).items():
        actual = metrics.get(metric)
        if actual is None:
            failures.append(f"{metric} not measured")
        elif actual > maximum + 1e-12:
            failures.append(f"{metric} {actual:.3f} > {maximum:.3f}")
    safety = metrics.get("safety", {})
    mapping = {
        "maximumMissingItems": "missingItems",
        "maximumInventedItems": "inventedItems",
        "maximumInventedPrices": "inventedPrices",
        "maximumForbiddenClaimHits": "forbiddenClaimHits",
        "maximumCoverFalsePositives": "coverFalsePositives",
        "maximumSilentPageLosses": "silentPageLosses",
        "maximumValidationErrors": "validationErrors",
    }
    for policy_key, result_key in mapping.items():
        maximum = policy.get("hardSafetyGates", {}).get(policy_key)
        if maximum is not None and safety.get(result_key, 0) > maximum:
            failures.append(
                f"{result_key} {safety.get(result_key, 0)} > {maximum}"
            )
    operational = metrics.get("operational", {})
    operational_targets = policy.get("operationalTargets", {})
    minimum_latency_coverage = operational_targets.get("minimumLatencyCoverage")
    if (
        minimum_latency_coverage is not None
        and operational.get("latencyCoverage", 0) + 1e-12 < minimum_latency_coverage
    ):
        failures.append(
            "latencyCoverage "
            f"{operational.get('latencyCoverage', 0):.3f} "
            f"< {minimum_latency_coverage:.3f}"
        )
    maximum_latency = operational_targets.get(
        "maximumP95PageLatencyMilliseconds"
    )
    actual_latency = operational.get("p95PageLatencyMilliseconds")
    if maximum_latency is not None:
        if actual_latency is None:
            failures.append("p95PageLatencyMilliseconds not measured")
        elif actual_latency > maximum_latency:
            failures.append(
                f"p95PageLatencyMilliseconds {actual_latency} > {maximum_latency}"
            )
    maximum_failure_rate = operational_targets.get("maximumPageFailureRate")
    if (
        maximum_failure_rate is not None
        and operational.get("pageFailureRate", 0) > maximum_failure_rate + 1e-12
    ):
        failures.append(
            "pageFailureRate "
            f"{operational.get('pageFailureRate', 0):.3f} "
            f"> {maximum_failure_rate:.3f}"
        )
    if include_repeatability:
        failures.extend(
            repeatability_enforcement_failures(
                operational.get("repeatability", {}),
                policy,
            )
        )
    return failures


def release_enforcement_failures(
    run_document_results,
    run_metrics,
    repeatability,
    policy,
):
    failures = []
    for run_index, (documents, metrics) in enumerate(
        zip(run_document_results, run_metrics),
        start=1,
    ):
        failures.extend(
            f"run {run_index}: {failure}"
            for failure in enforcement_failures(
                metrics,
                policy,
                include_repeatability=False,
            )
        )
        for document in documents:
            document_metrics = aggregate_results([document])
            failures.extend(
                f"run {run_index} / {document['fixtureID']}: {failure}"
                for failure in enforcement_failures(
                    document_metrics,
                    policy,
                    include_repeatability=False,
                )
            )

    failures.extend(
        f"all runs: {failure}"
        for failure in repeatability_enforcement_failures(repeatability, policy)
    )
    minimum_repeatability = policy.get("operationalTargets", {}).get(
        "minimumExactSemanticRepeatability"
    )
    if minimum_repeatability is not None:
        for document in repeatability.get("documents", []):
            actual = document.get("exactPairwiseAgreement")
            if actual is not None and actual + 1e-12 < minimum_repeatability:
                failures.append(
                    f"all runs / {document['fixtureID']}: "
                    f"exactSemanticRepeatability {actual:.3f} "
                    f"< {minimum_repeatability:.3f}"
                )
    return failures


def print_summary(result, failures, enforce):
    metrics = result["metrics"]
    safety = metrics["safety"]
    operational = metrics["operational"]
    mode_label = "ERZWUNGEN" if enforce else "MESSUNG"
    profile = result.get("enforcement", {}).get("profile", "launch")
    print(
        f"KitchenLink Qualitätsgate · {result['mode']} · Profil {profile} · "
        f"{mode_label}"
    )
    print(
        f"Ground Truth: {result['groundTruth']['pages']} Seiten, "
        f"{result['groundTruth']['entries']} Einträge"
    )
    print(
        "Launch-Leitwerte: "
        f"Eintrags-Recall {metrics['entryRecall']:.3f} · "
        f"Review-Erkennung {metrics['expectedReviewRecall']:.3f} · "
        f"Korrekturen/Seite {metrics['correctionsPerPage']:.2f}"
    )
    print(
        "Struktur: "
        f"Bereiche F1 {metrics['sectionF1']:.3f} · "
        f"Einträge F1 {metrics['entryF1']:.3f} · "
        f"Kategoriezuordnung {metrics['categoryAssignmentAccuracy']:.3f} · "
        f"Beziehungen F1 {metrics['relationF1']:.3f}"
    )
    print(
        "Texte/Preise: "
        f"Namen exakt {metrics['nameExactAccuracy']:.3f} · "
        f"Beschreibungen F1 {metrics['descriptionF1']:.3f} · "
        f"Preise F1 {metrics['offerF1']:.3f} · "
        f"Preistext exakt {metrics['priceTextExactAccuracy']:.3f} · "
        f"Preisbasis {metrics['priceBasisAccuracy']:.3f}"
    )
    print(
        "Deklaration/Belege: "
        f"Deklarationen {metrics['declarationF1']:.3f} · "
        f"Hinweise {metrics['noticeF1']:.3f} · "
        f"Übersetzungen {metrics['translationF1']:.3f} · "
        f"Belegabdeckung {metrics['evidenceCoverage']:.3f} · "
        f"Beleginhalt {metrics['evidenceSupportAccuracy']:.3f}"
    )
    print(
        "Sicherheit: "
        f"fehlende Einträge {safety['missingItems']} · "
        f"erfundene Einträge {safety['inventedItems']} · "
        f"erfundene Preise {safety['inventedPrices']} · "
        f"verbotene Claims {safety['forbiddenClaimHits']} · "
        f"Deckseiten-Fehler {safety['coverFalsePositives']} · "
        f"stille Seitenverluste {safety['silentPageLosses']} · "
        f"Validierungsfehler {safety['validationErrors']}"
    )
    latency = operational["p95PageLatencyMilliseconds"]
    repeatability = operational["repeatability"]["exactSemanticRepeatability"]
    print(
        "Betrieb: "
        f"Seitenfehler {operational['pageFailureRate']:.3f} · "
        f"Latenzabdeckung {operational['latencyCoverage']:.3f} · "
        f"P95-Seitenlatenz "
        f"{str(latency) + ' ms' if latency is not None else 'nicht gemessen'} · "
        f"Wiederholbarkeit "
        f"{f'{repeatability:.3f}' if repeatability is not None else 'nicht gemessen'} "
        f"({operational['repeatability']['repeatRuns']} Lauf/Läufe)"
    )
    if failures:
        prefix = "Gate NICHT bestanden" if enforce else "Würde im Erzwingungsmodus scheitern"
        print(prefix + ":")
        maximum_printed_failures = 24
        for failure in failures[:maximum_printed_failures]:
            print(f"  - {failure}")
        if len(failures) > maximum_printed_failures:
            print(
                f"  - … {len(failures) - maximum_printed_failures} weitere "
                "Details stehen im JSON-Bericht."
            )
    else:
        print(f"Gate bestanden (Profil {profile}).")

    comparison = result.get("profileComparison") or {}
    others = {name: data for name, data in comparison.items() if name != profile}
    if others:
        summary = " · ".join(
            f"{name}: {'bestanden' if data['passed'] else str(data['failureCount']) + ' Abweichungen'}"
            for name, data in sorted(others.items())
        )
        print(f"Andere Profile (nur Diagnose): {summary}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--gate-dir", type=Path, default=DEFAULT_GATE_DIR)
    parser.add_argument(
        "--report",
        type=Path,
        action="append",
        help="Repeat for multiple independent runs to measure exact repeatability.",
    )
    parser.add_argument("--mode", choices=("local", "llm"), default="local")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check-ground-truth", action="store_true")
    parser.add_argument(
        "--selected-pilot",
        action="store_true",
        help=(
            "Score a synthetic pilot-selection report by projecting the "
            "canonical truth onto report.selectedPages."
        ),
    )
    parser.add_argument("--enforce", action="store_true")
    parser.add_argument(
        "--profile",
        default=None,
        help=(
            "Threshold profile from policy.json. 'launch' is the "
            "release-relevant bar; 'strict' is the diagnostic long-term "
            "target. Defaults to policy.defaultProfile."
        ),
    )
    arguments = parser.parse_args()

    manifest, policy, truth_by_fixture, errors = validate_ground_truth(
        arguments.gate_dir.resolve()
    )
    if errors:
        print("Ground Truth ist ungültig:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 2
    if arguments.check_ground_truth and not arguments.report:
        total_entries = sum(
            len(truth.get("entries", [])) for truth in truth_by_fixture.values()
        )
        print(
            f"Ground Truth gültig: {manifest['selectedPageCount']} Seiten, "
            f"{total_entries} Einträge."
        )
        return 0
    if not arguments.report:
        parser.error("--report is required unless --check-ground-truth is used")

    reports = [read_json(path.resolve()) for path in arguments.report]
    if arguments.selected_pilot:
        selected_pages = reports[0].get("selectedPages")
        if not isinstance(selected_pages, list) or not selected_pages:
            print(
                "Selected pilot report has no selectedPages array.",
                file=sys.stderr,
            )
            return 2
        if any(report.get("selectedPages") != selected_pages for report in reports[1:]):
            print(
                "Selected pilot reports use different page selections.",
                file=sys.stderr,
            )
            return 2
        try:
            manifest, truth_by_fixture = build_selected_pilot_gate(
                manifest,
                truth_by_fixture,
                selected_pages,
            )
        except ValueError as error:
            print(f"Selected pilot is invalid: {error}", file=sys.stderr)
            return 2
    run_document_results = []
    run_metrics = []
    for report in reports:
        snapshots = {menu.get("id"): menu for menu in report.get("menus", [])}
        documents = []
        for document in manifest["documents"]:
            fixture_id = document["fixtureID"]
            documents.append(
                score_document(
                    document,
                    truth_by_fixture[fixture_id],
                    snapshots.get(fixture_id),
                    arguments.mode,
                )
            )
        run_document_results.append(documents)
        run_metrics.append(aggregate_results(documents))

    repeatability = measure_repeatability(
        reports,
        manifest,
        arguments.mode,
    )
    document_results = run_document_results[0]
    all_run_operational = aggregate_results([
        document
        for documents in run_document_results
        for document in documents
    ])["operational"]
    all_run_operational["repeatability"] = repeatability
    metrics = {
        **run_metrics[0],
        "operational": all_run_operational,
    }
    total_entries = sum(
        len(truth.get("entries", [])) for truth in truth_by_fixture.values()
    )
    result = {
        "schemaVersion": "kitchenlink-menu-quality-result/1.3.0",
        "mode": arguments.mode,
        "groundTruth": {
            "pages": manifest["selectedPageCount"],
            "entries": total_entries,
            "valid": True,
        },
        "metrics": metrics,
        "documents": document_results,
        "runSummaries": [
            {
                "runIndex": run_index,
                "metrics": current_metrics,
                "documents": [
                    {
                        "fixtureID": document["fixtureID"],
                        "metrics": aggregate_results([document]),
                    }
                    for document in documents
                ],
            }
            for run_index, (current_metrics, documents) in enumerate(
                zip(run_metrics, run_document_results),
                start=1,
            )
        ],
    }
    if arguments.selected_pilot:
        result["selectedPages"] = selected_pages
    profile_name = arguments.profile or policy.get("defaultProfile") or "launch"
    try:
        active_profile = resolve_policy_profile(policy, profile_name)
    except ValueError as error:
        print(f"Profil ist ungültig: {error}", file=sys.stderr)
        return 2

    failures = release_enforcement_failures(
        run_document_results,
        run_metrics,
        repeatability,
        active_profile,
    )
    result["enforcement"] = {
        "requested": arguments.enforce,
        "profile": profile_name,
        "passed": not failures,
        "failures": failures,
    }
    # Always report the other profiles too, so tightening the bar later never
    # requires a second run.
    result["profileComparison"] = {
        name: {
            "passed": not other_failures,
            "failureCount": len(other_failures),
            "failures": other_failures,
        }
        for name, other_failures in (
            (
                name,
                release_enforcement_failures(
                    run_document_results,
                    run_metrics,
                    repeatability,
                    profile,
                ),
            )
            for name, profile in (policy.get("profiles") or {}).items()
        )
    }

    if arguments.output:
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        with arguments.output.open("w", encoding="utf-8") as handle:
            json.dump(result, handle, ensure_ascii=False, indent=2, sort_keys=True)
            handle.write("\n")
    print_summary(result, failures, arguments.enforce)
    return 1 if arguments.enforce and failures else 0


if __name__ == "__main__":
    raise SystemExit(main())

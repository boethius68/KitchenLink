#!/usr/bin/env python3
"""Build self-contained KitchenLink lockups from the outlined wordmark."""

from copy import deepcopy
from pathlib import Path
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parent
SVG_NS = "http://www.w3.org/2000/svg"
XLINK_NS = "http://www.w3.org/1999/xlink"
ET.register_namespace("", SVG_NS)
ET.register_namespace("xlink", XLINK_NS)


def svg_tag(name: str) -> str:
    return f"{{{SVG_NS}}}{name}"


def build_lockup(
    symbol_name: str,
    wordmark_name: str,
    output_name: str,
    title_text: str,
) -> None:
    symbol_root = ET.parse(ROOT / symbol_name).getroot()
    wordmark_root = ET.parse(ROOT / wordmark_name).getroot()

    root = ET.Element(
        svg_tag("svg"),
        {
            "viewBox": "0 0 1217 240",
            "role": "img",
            "aria-labelledby": "title",
        },
    )
    title = ET.SubElement(root, svg_tag("title"), {"id": "title"})
    title.text = title_text

    wordmark_defs = wordmark_root.find(svg_tag("defs"))
    if wordmark_defs is None:
        raise RuntimeError(f"No glyph definitions found in {wordmark_name}")
    root.append(deepcopy(wordmark_defs))

    symbol_group = ET.SubElement(root, svg_tag("g"))
    for child in symbol_root:
        if child.tag in {svg_tag("title"), svg_tag("desc")}:
            continue
        symbol_group.append(deepcopy(child))

    visible_groups = wordmark_root.findall(svg_tag("g"))
    if not visible_groups:
        raise RuntimeError(f"No outlined wordmark found in {wordmark_name}")
    wordmark_group = deepcopy(visible_groups[-1])
    wordmark_group.set("transform", "translate(380 63) scale(0.15454)")
    root.append(wordmark_group)

    tree = ET.ElementTree(root)
    ET.indent(tree, space="  ")
    tree.write(ROOT / output_name, encoding="UTF-8", xml_declaration=True)


def main() -> None:
    build_lockup(
        "kitchenlink-symbol.svg",
        "kitchenlink-wordmark.svg",
        "kitchenlink-lockup.svg",
        "KitchenLink horizontal logo, color working version",
    )
    build_lockup(
        "kitchenlink-symbol-mono.svg",
        "kitchenlink-wordmark.svg",
        "kitchenlink-lockup-mono.svg",
        "KitchenLink horizontal logo, monochrome working version",
    )
    build_lockup(
        "kitchenlink-symbol-reverse.svg",
        "kitchenlink-wordmark-reverse.svg",
        "kitchenlink-lockup-reverse.svg",
        "KitchenLink horizontal logo, reversed working version",
    )


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Render the deterministic three-page KitchenLink import test menu.

Unlike the synthetic corpus generator, this fixture does not call a model. Its
content is intentionally fixed so the app always offers one known card covering
food, drinks, descriptions, portions, variants, extras, set menus, allergens
and additives. Run from the repository root after changing the fixture text.
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import textwrap

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "kitchenlink" / "Resources" / "DemoMenus"
WIDTH, HEIGHT = 1654, 2339
GRAPE = "#2C2438"
LEMON = "#B6CC1B"
PAPER = "#F8F6F1"
MUTED = "#655F70"
LINE = "#C9C4CF"

FONT_REGULAR = "/System/Library/Fonts/Supplemental/Arial.ttf"
FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"


def font(size, bold=False):
    return ImageFont.truetype(FONT_BOLD if bold else FONT_REGULAR, size)


def wrapped(draw, text, xy, max_width, text_font, fill=GRAPE, spacing=7):
    words = text.split()
    lines, current = [], ""
    for word in words:
        candidate = f"{current} {word}".strip()
        if draw.textlength(candidate, font=text_font) <= max_width or not current:
            current = candidate
        else:
            lines.append(current)
            current = word
    if current:
        lines.append(current)
    x, y = xy
    line_height = text_font.size + spacing
    for line in lines:
        draw.text((x, y), line, font=text_font, fill=fill)
        y += line_height
    return y


def page(number, subtitle):
    image = Image.new("RGB", (WIDTH, HEIGHT), PAPER)
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((70, 64, WIDTH - 70, 260), radius=34, fill=GRAPE)
    draw.text((112, 96), "KITCHENLINK PRÜFKÜCHE", font=font(52, True), fill="white")
    draw.text((114, 171), subtitle.upper(), font=font(25, True), fill=LEMON)
    draw.text((WIDTH - 212, 175), f"{number} / 3", font=font(23, True), fill="white")
    return image, draw


def section(draw, title, x, y, width):
    draw.text((x, y), title.upper(), font=font(31, True), fill=GRAPE)
    y += 49
    draw.line((x, y, x + width, y), fill=GRAPE, width=3)
    return y + 20


def item(draw, x, y, width, name, price, description, codes="", options=None, tag=None):
    name_font = font(26, True)
    price_font = font(24, True)
    code_font = font(20, True)
    price_width = draw.textlength(price, font=price_font)
    draw.text((x, y), name, font=name_font, fill=GRAPE)
    if codes:
        displayed_codes = ",".join(
            token.upper() if token.isalpha() else token
            for token in codes.split(",")
        )
        name_width = draw.textlength(name, font=name_font)
        draw.text((x + name_width + 10, y - 2), f"[{displayed_codes}]", font=code_font, fill=MUTED)
    draw.text((x + width - price_width, y + 2), price, font=price_font, fill=GRAPE)
    y += 38
    y = wrapped(draw, description, (x, y), width, font(20), MUTED, spacing=6)
    if tag:
        draw.rounded_rectangle((x, y + 4, x + 118, y + 38), radius=10, fill="#E3E7C5")
        draw.text((x + 10, y + 9), tag.upper(), font=font(15, True), fill=GRAPE)
        y += 46
    if options:
        y = wrapped(draw, options, (x, y + 3), width, font(18, True), GRAPE, spacing=5)
    draw.line((x, y + 12, x + width, y + 12), fill=LINE, width=1)
    return y + 32


def render_page_1():
    image, draw = page(1, "Speisen · Varianten · Extras")
    margin, gap = 90, 64
    col = (WIDTH - 2 * margin - gap) // 2
    left, right = margin, margin + col + gap

    y = section(draw, "Vorspeisen", left, 320, col)
    y = item(draw, left, y, col, "Geröstetes Bauernbrot", "6,90 €", "Kräuterbutter, Tomaten-Dip und Meersalz", "a,g")
    y = item(draw, left, y, col, "Knoblauchgarnelen", "12,90 €", "Garnelen aus der Pfanne, Chili und Petersilie", "b,o")
    y = item(draw, left, y, col, "Bunter Marktsalat", "8,90 €", "Blattsalate, Tomate, Gurke und Senf-Vinaigrette", "j", "Extra: Hähnchenbrust +4,00 € · Feta +2,00 €")

    y = section(draw, "Hauptgerichte", left, y + 20, col)
    y = item(draw, left, y, col, "Veganes Kokoscurry", "15,90 €", "Gemüse, Kichererbsen, Kokosmilch und Basmatireis", "f,i", "Variante: mit Tofu +2,50 €", "vegan")
    item(draw, left, y, col, "Küstenfisch", "22,90 €", "Gebratenes Kabeljaufilet, Kartoffelstampf und Beurre blanc", "d,g")

    y = section(draw, "Klassiker", right, 320, col)
    y = item(draw, right, y, col, "Wiener Schnitzel", "17,90 €", "Kalbsschnitzel, Preiselbeeren und Kartoffelsalat", "a,c,g,j", "Portionen: klein 14,90 € · groß 20,90 €")
    y = item(draw, right, y, col, "Prüfküchen-Burger", "16,90 €", "Rindfleisch, Brioche, Cheddar, Salat und Haussauce", "a,c,g,j,2,8", "Extras: doppelt Fleisch +5,00 € · Cheddar +1,50 €")
    y = item(draw, right, y, col, "Käsespätzle", "14,50 €", "Hausgemachte Spätzle, Bergkäse und Röstzwiebeln", "a,c,g", "Portionen: klein 10,90 € · normal 14,50 €")
    y = item(draw, right, y, col, "Hähnchen vom Grill", "18,90 €", "Maispoularde, Rosmarinjus und Marktgemüse", "i", "Beilage wählen: Pommes 0,00 € · Salat 0,00 € · Bratkartoffeln +1,50 €")

    footer(draw)
    return image


def render_page_2():
    image, draw = page(2, "Pizza · Gangmenü · Dessert")
    x, width = 120, WIDTH - 240
    y = section(draw, "Pizza & Pasta", x, 320, width)
    y = item(draw, x, y, width, "Pizza Margherita", "10,90 €", "Tomatensauce, Mozzarella und Basilikum", "a,g", "Größen: 28 cm 10,90 € · 36 cm 15,90 €")
    y = item(draw, x, y, width, "Pizza Prüfstand", "14,90 €", "Salami, Paprika, Oliven und Mozzarella", "a,g,2,6", "Extra: glutenfreier Boden +2,50 €")
    y = item(draw, x, y, width, "Pasta Arrabbiata", "13,50 €", "Penne, pikante Tomatensauce, Knoblauch und Parmesan", "a,g,o", "Variante: ohne Parmesan 0,00 €", "vegetarisch")

    y = section(draw, "3-Gang-Abendmenü", x, y + 15, width)
    y = item(
        draw, x, y, width, "Menü Abendbrise", "39,90 € pro Person",
        "Ein festes Menü als ein Angebot mit wählbarem Hauptgang.", "a,c,d,g",
        "Vorspeise: Marktsalat · Hauptgang (Wahl): Küstenfisch oder veganes Curry · Dessert: Schokoladenküchlein"
    )

    y = section(draw, "Dessert", x, y + 15, width)
    y = item(draw, x, y, width, "Panna Cotta", "7,20 €", "Vanille, Beerenragout und Mandelkrokant", "g,h")
    y = item(draw, x, y, width, "Schokoladenküchlein", "7,90 €", "Warmer Kern, Vanilleeis und Kakaocrumble", "a,c,g")
    item(draw, x, y, width, "Zitronensorbet", "6,50 €", "Hausgemacht mit Minze und alkoholfreiem Sekt", "5", tag="vegan")

    footer(draw)
    return image


def render_page_3():
    image, draw = page(3, "Getränke · Zusatzstoffe · Legende")
    margin, gap = 90, 64
    col = (WIDTH - 2 * margin - gap) // 2
    left, right = margin, margin + col + gap

    y = section(draw, "Alkoholfreie Getränke", left, 320, col)
    y = item(draw, left, y, col, "Hauslimonade Zitrone", "4,20 €", "Zitrone, Minze und Soda", options="Größen: 0,3 l 4,20 € · 0,5 l 5,90 €")
    y = item(draw, left, y, col, "Cola Zero", "3,60 €", "Eisgekühlt serviert", "1,9,11", "Größen: 0,2 l 3,60 € · 0,4 l 5,20 €")
    y = item(draw, left, y, col, "Tonic Water", "3,80 €", "Mit Limettenscheibe", "12")

    y = section(draw, "Kaffee & Tee", left, y + 20, col)
    y = item(draw, left, y, col, "Cappuccino", "3,90 €", "Doppelter Espresso und Milchschaum", "g", "Variante: Haferdrink +0,50 €")
    item(draw, left, y, col, "Espresso", "2,80 €", "Kräftige Hausröstung", "11")

    y = section(draw, "Wein & Bier", right, 320, col)
    y = item(draw, right, y, col, "Riesling trocken", "6,90 €", "Mosel, mineralisch und frisch", "l,13", "Größen: 0,2 l 6,90 € · 0,75 l 24,00 €")
    y = item(draw, right, y, col, "Kellerpils", "4,20 €", "Naturtrüb vom Fass", "a,13", "Größen: 0,3 l 4,20 € · 0,5 l 5,60 €")

    y = section(draw, "Allergen- & Zusatzstoff-Legende", right, y + 22, col)
    legend = [
        "a Glutenhaltiges Getreide", "b Krebstiere", "c Eier", "d Fisch",
        "f Soja", "g Milch / Laktose", "h Schalenfrüchte", "i Sellerie",
        "j Senf", "l Sulfite", "o Knoblauch", "1 mit Farbstoff",
        "2 mit Konservierungsstoff", "5 geschwefelt", "6 geschwärzt",
        "8 mit Phosphat", "9 mit Süßungsmittel", "11 koffeinhaltig",
        "12 chininhaltig", "13 alkoholhaltig",
    ]
    for line in legend:
        displayed_line = line[0].upper() + line[1:] if line[0].isalpha() else line
        draw.text((right, y), displayed_line, font=font(19), fill=MUTED)
        y += 29

    footer(draw)
    return image


def footer(draw):
    y = HEIGHT - 105
    draw.line((90, y, WIDTH - 90, y), fill=LINE, width=2)
    draw.text((90, y + 24), "SANDBOX-TESTKARTE · NICHT FÜR DEN GASTBETRIEB", font=font(17, True), fill=MUTED)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    pages = [render_page_1(), render_page_2(), render_page_3()]
    for index, image in enumerate(pages, start=1):
        path = OUT / f"kitchenlink-pruefkueche-{index}.png"
        image.save(path, format="PNG", optimize=True)
        print(path)


if __name__ == "__main__":
    main()

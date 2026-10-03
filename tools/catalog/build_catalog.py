#!/usr/bin/env python3
"""Arma el catálogo de productos de Cobrá a partir de datos abiertos de SEPA
(Precios Claros, Gobierno de Argentina).

Entradas (archivos .csv.gz del mismo día):
  --productos  productos_AAAA-MM-DD.csv.gz   (código, descripción, marca, rubro...)
  --precios    precios_AAAA-MM-DD.csv.gz     (se usa solo para saber en cuántas
                                              sucursales aparece cada producto)
Salidas:
  assets/catalog/productos_ar.json   -> viaja dentro de la app (autocompletado sin internet)
  supabase/seed/catalog_seed.csv     -> para importar a la tabla catalog_products

Se queda con los N productos más comunes, dando prioridad a lo típico de kiosco.
No incluye precios: un kiosco cobra distinto que un supermercado.

Uso:
  python3 tools/catalog/build_catalog.py --productos productos_2018-03-11.csv.gz \
      --precios precios_2018-03-11.csv.gz --max 10000
"""
import argparse
import collections
import csv
import gzip
import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# ───────────────────────── Códigos de barras ─────────────────────────

def checksum_ok(code: str) -> bool:
    """Dígito verificador de EAN-8 / EAN-13 (y UPC-A de 12, tratado como EAN-13 con 0 adelante)."""
    if len(code) == 12:
        code = "0" + code
    if len(code) not in (8, 13) or not code.isdigit():
        return False
    body, check = code[:-1], int(code[-1])
    # Desde la derecha del cuerpo los pesos alternan 3, 1, 3, 1...
    total = sum(int(d) * (3 if i % 2 == 0 else 1) for i, d in enumerate(reversed(body)))
    return (10 - total % 10) % 10 == check


def normalize_ean(raw: str):
    """Código canónico (EAN-13, o EAN-8) o None si no es un código de barras real."""
    code = re.sub(r"\D", "", raw or "")
    if code != (raw or "").strip():          # tenía letras o guiones: código interno
        return None
    if code.startswith("00000"):             # códigos internos de los supermercados
        return None
    if not checksum_ok(code):
        return None
    return "0" + code if len(code) == 12 else code

# ───────────────────────── Limpieza de textos ─────────────────────────

_UNIT_FIXES = [
    (re.compile(r"(?<=\d)\s*(?:g|gr|grs|gramos?)\b", re.I), " g"),
    (re.compile(r"(?<=\d)\s*(?:kg|kgs|kilos?)\b", re.I), " kg"),
    (re.compile(r"(?<=\d)\s*(?:lt|lts|litros?|l)\b", re.I), " L"),
    (re.compile(r"(?<=\d)\s*(?:cc|cm3|ml|mls)\b", re.I), " ml"),
    (re.compile(r"(?<=\d)\s*(?:un|u|unid|unidades?)\b\.?", re.I), " u."),
]
_SMALL_WORDS = {"de", "del", "la", "las", "el", "los", "y", "con", "sin", "en", "para", "por", "al", "a", "e", "o"}
_KEEP_UPPER = {"uht", "pet", "led", "usb", "pvc", "uv", "spf", "ph", "tv", "cd", "xl", "xxl", "ml", "kg", "l", "g"}


def _title_token(tok: str, first: bool) -> str:
    low = tok.lower()
    if low in _KEEP_UPPER and not tok.islower():
        units = {"ml": "ml", "kg": "kg", "g": "g", "l": "L"}
        return units.get(low, tok.upper())
    if low in _SMALL_WORDS and not first:
        return low
    if any(c.isdigit() for c in tok):
        return tok
    return tok[:1].upper() + tok[1:].lower() if tok.isupper() or tok.islower() else tok


def clean_name(desc: str) -> str:
    s = (desc or "").replace(" ", " ")
    s = re.sub(r"\s+", " ", s).strip(" .-")
    if not s:
        return ""
    # Decimales con coma: "1.5 Lt" -> "1,5 L"
    s = re.sub(r"(\d)\.(\d+)(?=\s*(?:lt|lts|l|kg|kgs|gr|g|ml|cc)\b)", r"\1,\2", s, flags=re.I)
    for rx, rep in _UNIT_FIXES:
        s = rx.sub(rep, s)
    # Solo se re-capitaliza si viene todo en mayúsculas o todo en minúsculas
    letters = [c for c in s if c.isalpha()]
    if letters and (all(c.isupper() for c in letters) or all(c.islower() for c in letters)):
        s = " ".join(_title_token(t, i == 0) for i, t in enumerate(s.split(" ")))
    return re.sub(r"\s+", " ", s).strip()


def clean_brand(brand: str) -> str:
    b = re.sub(r"\s+", " ", (brand or "")).strip()
    if not b or b.lower() in {"sin marca", "s/m", "nan", "null", "none", "-"}:
        return ""
    return " ".join(t[:1].upper() + t[1:].lower() if t.isupper() else t for t in b.split(" "))


def clean_category(rubro: str) -> str:
    r = re.sub(r"\s+", " ", (rubro or "")).strip()
    if not r or r.upper() in {"SIN CATEGORÍA", "SIN CATEGORIA", "NAN"}:
        return ""
    letters = [c for c in r if c.isalpha()]
    mostly_upper = letters and sum(c.isupper() for c in letters) / len(letters) > 0.6
    return r[:1].upper() + r[1:].lower() if mostly_upper else r

# ───────────────────────── Selección ─────────────────────────

# Palabras completas (con \b): "pila" no debe coincidir con "Capilatis" ni "man" con "Manzana".
KIOSK_REGEX = re.compile(
    r"\b(?:gaseosas?|agua|aguas|jugos?|cervezas?|fernet|energizante|isot[oó]nic[ao]|soda|"
    r"alfajor(?:es)?|galletit\w*|golosinas?|caramelos?|chicles?|chocolates?|snacks?|"
    r"papas fritas|palitos|man[ií]|turr[oó]n(?:es)?|bombon(?:es)?|bomb[oó]n|barras? de cereal|"
    r"helados?|yerba|mate cocido|caf[eé]|t[eé] en saquitos|cigarrillos?|encendedor(?:es)?|"
    r"pilas?|preservativos?|pa[ñn]uelos?|pastillas?|gomitas?|chupet\w*|obleas?|mentol|"
    r"vino|aperitivo|gin|whisky|vodka)\b",
    re.I,
)
KIOSK_CATEGORIES = {"bebidas sin alcohol", "bebidas con alcohol"}
KIOSK_BOOST = 2.0


def is_kiosk(name: str, brand: str, category: str) -> bool:
    return category.lower() in KIOSK_CATEGORIES or bool(KIOSK_REGEX.search(f"{name} {brand}"))


def build(productos_path, precios_path, max_items):
    popularity = collections.Counter()
    with gzip.open(precios_path, "rt", encoding="utf-8", errors="replace", newline="") as f:
        reader = csv.reader(f)
        header = next(reader)
        i = header.index("producto_sepa_id")
        for row in reader:
            if len(row) > i:
                popularity[row[i]] += 1

    best = {}
    with gzip.open(productos_path, "rt", encoding="utf-8", errors="replace", newline="") as f:
        for r in csv.DictReader(f):
            raw = (r.get("producto_sepa_id") or "").strip()
            ean = normalize_ean(raw)
            if not ean:
                continue
            name = clean_name(r.get("producto_descripcion"))
            if len(name) < 6 or len(name.split()) < 2:
                continue
            brand = clean_brand(r.get("producto_marca"))
            category = clean_category(r.get("categoria_rubro_desc"))
            pop = popularity.get(raw, 0)
            if pop <= 0:
                continue
            score = pop * (KIOSK_BOOST if is_kiosk(name, brand, category) else 1.0)
            if ean not in best or score > best[ean][0]:
                best[ean] = (score, ean, name, brand, category)

    ranked = sorted(best.values(), key=lambda x: (-x[0], x[1]))[:max_items]
    return [(e, n, b, c) for _, e, n, b, c in ranked]


def write_outputs(items):
    out_json = os.path.join(ROOT, "assets", "catalog", "productos_ar.json")
    out_csv = os.path.join(ROOT, "supabase", "seed", "catalog_seed.csv")
    os.makedirs(os.path.dirname(out_json), exist_ok=True)
    os.makedirs(os.path.dirname(out_csv), exist_ok=True)
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump([list(i) for i in items], f, ensure_ascii=False, separators=(",", ":"))
    with open(out_csv, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["ean", "name", "brand", "category", "source"])
        for e, n, b, c in items:
            w.writerow([e, n, b, c, "sepa"])
    return out_json, out_csv


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--productos", required=True)
    ap.add_argument("--precios", required=True)
    ap.add_argument("--max", type=int, default=10000)
    a = ap.parse_args()
    items = build(a.productos, a.precios, a.max)
    j, c = write_outputs(items)
    kiosk = sum(1 for _, n, b, cat in items if is_kiosk(n, b, cat))
    print(f"productos: {len(items)} | típicos de kiosco: {kiosk}")
    print(f"con marca: {sum(1 for i in items if i[2])} | con rubro: {sum(1 for i in items if i[3])}")
    print(f"escrito: {os.path.relpath(j, ROOT)} ({os.path.getsize(j)//1024} KB), {os.path.relpath(c, ROOT)} ({os.path.getsize(c)//1024} KB)")


if __name__ == "__main__":
    main()

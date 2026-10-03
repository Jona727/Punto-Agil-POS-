#!/usr/bin/env python3
"""Convierte supabase/seed/catalog_seed.csv en bloques de SQL para pegar en el
SQL Editor de Supabase (alternativa al importador de CSV, que puede fallar con
archivos grandes). Cada bloque se puede ejecutar varias veces sin duplicar.

Uso: python3 tools/catalog/csv_to_sql.py [--por-bloque 2000]
"""
import argparse
import csv
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CSV_PATH = os.path.join(ROOT, "supabase", "seed", "catalog_seed.csv")
OUT_DIR = os.path.join(ROOT, "supabase", "seed", "sql")


def quote(value: str) -> str:
    """Literal de texto de PostgreSQL: se duplican las comillas simples."""
    return "'" + (value or "").replace("'", "''") + "'"


def build_chunks(rows, per_chunk):
    chunks = []
    for start in range(0, len(rows), per_chunk):
        part = rows[start:start + per_chunk]
        values = ",\n".join(
            f"({quote(r['ean'])},{quote(r['name'])},{quote(r['brand'])},{quote(r['category'])},{quote(r['source'])})"
            for r in part
        )
        # Sin comentarios a propósito: si al pegar se pierden los saltos de línea,
        # un "-- comentario" dejaría toda la consulta comentada (error "end of input").
        chunks.append(
            "insert into public.catalog_products (ean, name, brand, category, source) values\n"
            "{values}\n"
            "on conflict (ean) do nothing;\n".format(values=values)
        )
    return chunks


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--por-bloque", type=int, default=2000)
    a = ap.parse_args()
    with open(CSV_PATH, encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    os.makedirs(OUT_DIR, exist_ok=True)
    for old in os.listdir(OUT_DIR):
        if old.startswith("catalog_seed_") and old.endswith(".sql"):
            os.remove(os.path.join(OUT_DIR, old))
    for i, sql in enumerate(build_chunks(rows, a.por_bloque), start=1):
        path = os.path.join(OUT_DIR, f"catalog_seed_{i:02d}.sql")
        with open(path, "w", encoding="utf-8") as f:
            f.write(sql)
        print(f"{os.path.relpath(path, ROOT)}: {os.path.getsize(path)//1024} KB")
    print(f"filas: {len(rows)}")


if __name__ == "__main__":
    main()

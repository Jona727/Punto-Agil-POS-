import os, sys, unittest
sys.path.insert(0, os.path.dirname(__file__))
import csv_to_sql as c


class Sql(unittest.TestCase):
    def test_escapa_comillas_simples(self):
        self.assertEqual(c.quote("Dulce d'Leche"), "'Dulce d''Leche'")
        self.assertEqual(c.quote("O'Brien's"), "'O''Brien''s'")

    def test_vacio_y_none(self):
        self.assertEqual(c.quote(""), "''")
        self.assertEqual(c.quote(None), "''")

    def test_no_se_puede_inyectar_sql(self):
        self.assertEqual(c.quote("x'); drop table public.products; --"), "'x''); drop table public.products; --'")

    def test_bloques(self):
        rows = [{"ean": str(i), "name": f"P{i}", "brand": "", "category": "", "source": "sepa"} for i in range(5)]
        chunks = c.build_chunks(rows, 2)
        self.assertEqual(len(chunks), 3)
        self.assertIn("bloque 1 de 3", chunks[0])
        self.assertIn("on conflict (ean) do nothing", chunks[0])
        self.assertEqual(chunks[2].count("('"), 1)


if __name__ == "__main__":
    unittest.main()

import os, sys, unittest
sys.path.insert(0, os.path.dirname(__file__))
import build_catalog as b


class Ean(unittest.TestCase):
    def test_codigos_reales_validos(self):
        for code in ["7790895000430", "7790040929609", "7622300833909", "7501007499789"]:
            self.assertTrue(b.checksum_ok(code), code)

    def test_digito_verificador_incorrecto(self):
        self.assertFalse(b.checksum_ok("7790895000431"))
        self.assertFalse(b.checksum_ok("1234567890123"))

    def test_ean8(self):
        self.assertTrue(b.checksum_ok("77940131"))   # Arcor, del catálogo
        self.assertFalse(b.checksum_ok("77940132"))

    def test_upc12_se_normaliza_a_13(self):
        self.assertEqual(b.normalize_ean("038000134579"), "0038000134579")
        self.assertEqual(b.normalize_ean("0038000134579"), "0038000134579")

    def test_codigos_internos_se_descartan(self):
        self.assertIsNone(b.normalize_ean("36-4-0200031200000"))
        self.assertIsNone(b.normalize_ean("0000042277842"))
        self.assertIsNone(b.normalize_ean(""))
        self.assertIsNone(b.normalize_ean("abc"))
        self.assertIsNone(b.normalize_ean("7790895000431"))


class Nombres(unittest.TestCase):
    def test_unidades_y_decimales(self):
        self.assertEqual(b.clean_name("Coca Cola Light 1.5 Lt"), "Coca Cola Light 1,5 L")
        self.assertEqual(b.clean_name("Fernet Branca 750 Cc"), "Fernet Branca 750 ml")
        self.assertEqual(b.clean_name("Galletitas Chocolate Chocolinas 170 Gr"), "Galletitas Chocolate Chocolinas 170 g")
        self.assertEqual(b.clean_name("Te en Saquitos Taragui 50 Un"), "Te en Saquitos Taragui 50 u.")
        self.assertEqual(b.clean_name("Yerba Mate La Tranquera 1 Kg"), "Yerba Mate La Tranquera 1 kg")

    def test_pegado_sin_espacio(self):
        self.assertEqual(b.clean_name("Galle Ferrari Crackers 300g"), "Galle Ferrari Crackers 300 g")

    def test_todo_mayusculas_se_capitaliza(self):
        self.assertEqual(b.clean_name("GASEOSA COLA SIN AZUCAR 2.25 LT"), "Gaseosa Cola sin Azucar 2,25 L")

    def test_no_toca_nombres_ya_bien_escritos(self):
        self.assertEqual(b.clean_name("Alfajor Triple Jorgito"), "Alfajor Triple Jorgito")
        self.assertEqual(b.clean_name("Dulce de Leche La Serenísima 400 g"), "Dulce de Leche La Serenísima 400 g")

    def test_espacios_y_puntuacion(self):
        self.assertEqual(b.clean_name("  Chicles   Beldent  "), "Chicles Beldent")
        self.assertEqual(b.clean_name(""), "")
        self.assertEqual(b.clean_name(None), "")

    def test_marca_y_rubro(self):
        self.assertEqual(b.clean_brand("SIN MARCA"), "")
        self.assertEqual(b.clean_brand("COCA COLA"), "Coca Cola")
        self.assertEqual(b.clean_brand("Arcor"), "Arcor")
        self.assertEqual(b.clean_category("SIN CATEGORÍA"), "")
        self.assertEqual(b.clean_category("BEBIDAS SIN ALCOHOL"), "Bebidas sin alcohol")
        self.assertEqual(b.clean_category("PERFUMERÍA y CUIDADO PERSONAL"), "Perfumería y cuidado personal")
        self.assertEqual(b.clean_category("Almacén"), "Almacén")


class Kiosco(unittest.TestCase):
    def test_deteccion(self):
        self.assertTrue(b.is_kiosk("Gaseosa Cola 1,5 L", "", ""))
        self.assertTrue(b.is_kiosk("Alfajor Triple Jorgito", "", "Almacén"))
        self.assertTrue(b.is_kiosk("Agua Mineral 2 L", "", "Bebidas sin alcohol"))
        self.assertFalse(b.is_kiosk("Detergente Ala 750 ml", "", "Limpieza"))

    def test_palabras_completas(self):
        self.assertFalse(b.is_kiosk("Enjuague Ortiga Capilatis 410 ml", "Capilatis", "Perfumería"))
        self.assertFalse(b.is_kiosk("Jabón de Manzana 125 g", "", "Perfumería"))
        self.assertTrue(b.is_kiosk("Pilas Alcalinas AA Duracell 4 u.", "", ""))
        self.assertTrue(b.is_kiosk("Maní Pelado Salado 200 g", "", ""))


if __name__ == "__main__":
    unittest.main()

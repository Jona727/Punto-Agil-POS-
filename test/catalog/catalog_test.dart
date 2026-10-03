import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cobra/features/catalog/data/asset_catalog_source.dart';
import 'package:cobra/features/catalog/data/catalog_repository_impl.dart';
import 'package:cobra/features/catalog/data/supabase_catalog_source.dart';
import 'package:cobra/features/catalog/domain/barcode.dart';
import 'package:cobra/features/catalog/domain/catalog_product.dart';

/// Catálogo de prueba en memoria.
class FakeBundle extends CachingAssetBundle {
  FakeBundle(this.content);
  final String? content;

  @override
  Future<ByteData> load(String key) async {
    if (content == null) throw FlutterError('no existe $key');
    final bytes = Uint8List.fromList(content!.codeUnits);
    return ByteData.sublistView(bytes);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (content == null) throw FlutterError('no existe $key');
    return content!;
  }
}

class FakeRemote implements SupabaseCatalogSource {
  FakeRemote(this.products, {this.explota = false});
  final Map<String, CatalogProduct> products;
  final bool explota;
  final List<String> consultas = [];

  @override
  Future<CatalogProduct?> find(String normalizedBarcode) async {
    consultas.add(normalizedBarcode);
    if (explota) throw StateError('sin internet');
    return products[normalizedBarcode];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('catálogo incluido en la app (el archivo real)', () {
    late AssetCatalogSource source;
    setUp(() => source = AssetCatalogSource());

    test('tiene más de mil productos (son miles)', () async {
      expect(await source.size, greaterThan(5000));
    });

    test('encuentra productos típicos de kiosco por su código', () async {
      final coca = await source.find('7790895000430');
      expect(coca!.name, 'Coca Cola 1,5 L');
      expect(coca.brand, 'Coca Cola');
      expect(coca.category, 'Bebidas sin alcohol');

      expect((await source.find('7790290001193'))!.name, 'Fernet Branca 750 ml');
      expect((await source.find('7790895000454'))!.name, 'Gaseosa Naranja Fanta 1,5 L');
    });

    test('un código desconocido no devuelve nada', () async {
      expect(await source.find('7799999999990'), isNull);
    });

    test('el archivo es íntegro: cada código es válido, único y tiene nombre', () {
      final rows = jsonDecode(File('assets/catalog/productos_ar.json').readAsStringSync()) as List;
      final vistos = <String>{};
      for (final row in rows) {
        final r = row as List;
        final ean = r[0] as String;
        expect(normalizeBarcode(ean), ean, reason: 'no está normalizado: $ean');
        expect(barcodeChecksumOk(ean), isTrue, reason: 'dígito de control inválido: $ean');
        expect(vistos.add(ean), isTrue, reason: 'repetido: $ean');
        expect((r[1] as String).trim().length, greaterThanOrEqualTo(6), reason: 'nombre vacío: $ean');
      }
      expect(rows.length, greaterThan(5000));
    });

    test('los nombres vienen listos para usar (sin abreviaturas de unidades)', () async {
      final p = await source.find('7790040929609');
      expect(p!.name, 'Galletitas Surtido Seleccionadas Bagley 400 g');
    });
  });

  group('AssetCatalogSource con archivos propios', () {
    test('si el archivo no existe, no rompe: simplemente no sugiere', () async {
      final source = AssetCatalogSource(bundle: FakeBundle(null));
      expect(await source.find('7790895000430'), isNull);
      expect(await source.size, 0);
    });

    test('si el archivo está dañado, no rompe', () async {
      final source = AssetCatalogSource(bundle: FakeBundle('esto no es json'));
      expect(await source.find('7790895000430'), isNull);
    });

    test('lee filas con y sin marca/rubro', () async {
      final source = AssetCatalogSource(
          bundle: FakeBundle('[["7790000000001","Producto A","Marca","Rubro"],["7790000000002","Producto B"]]'));
      expect((await source.find('7790000000001'))!.brand, 'Marca');
      final b = (await source.find('7790000000002'))!;
      expect(b.name, 'Producto B');
      expect(b.brand, '');
    });
  });

  group('CatalogRepositoryImpl', () {
    final local = AssetCatalogSource(
        bundle: FakeBundle('[["7790895000430","Coca Cola 1,5 L","Coca Cola","Bebidas"]]'));
    const nube = CatalogProduct(ean: '7791111111111', name: 'Producto de la nube');

    test('encuentra en el catálogo de la app sin consultar la nube', () async {
      final remote = FakeRemote({});
      final repo = CatalogRepositoryImpl(local: local, remote: remote);

      expect((await repo.lookup('7790895000430'))!.name, 'Coca Cola 1,5 L');
      expect(remote.consultas, isEmpty);
    });

    test('si no está en la app, busca en la nube', () async {
      final remote = FakeRemote({'7791111111111': nube});
      final repo = CatalogRepositoryImpl(local: local, remote: remote);

      expect(await repo.lookup('7791111111111'), nube);
      expect(remote.consultas, ['7791111111111']);
    });

    test('sin nube configurada solo usa el de la app', () async {
      final repo = CatalogRepositoryImpl(local: local);
      expect(await repo.lookup('7791111111111'), isNull);
      expect((await repo.lookup('7790895000430')), isNotNull);
    });

    test('si la nube falla (sin internet), no rompe: no hay sugerencia', () async {
      final repo = CatalogRepositoryImpl(local: local, remote: FakeRemote({}, explota: true));
      expect(await repo.lookup('7791111111111'), isNull);
    });

    test('acepta el código escrito de varias formas', () async {
      final repo = CatalogRepositoryImpl(local: local);
      expect(await repo.lookup(' 7790895000430 '), isNotNull);
    });

    test('un código inválido ni siquiera consulta', () async {
      final remote = FakeRemote({});
      final repo = CatalogRepositoryImpl(local: local, remote: remote);

      expect(await repo.lookup('abc'), isNull);
      expect(await repo.lookup('123'), isNull);
      expect(await repo.lookup(''), isNull);
      expect(remote.consultas, isEmpty);
    });

    test('un UPC de 12 dígitos encuentra el producto guardado con 13', () async {
      final repo = CatalogRepositoryImpl(
          local: AssetCatalogSource(
              bundle: FakeBundle('[["0038000846731","Papas Fritas Original Pringles 37 g","Pringles","Almacén"]]')));
      expect((await repo.lookup('038000846731'))!.brand, 'Pringles');
    });
  });
}

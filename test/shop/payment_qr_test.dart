import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:cobra/features/billing/presentation/widgets/payment_qr_panel.dart';
import 'package:cobra/features/shop/data/models/shop_model.dart';
import 'package:cobra/features/shop/domain/entities/shop.dart';
import 'package:cobra/features/shop/domain/payment_qr.dart';
import 'package:cobra/features/sync/data/sync_mappers.dart';

/// QR de ejemplo con el formato de los QR de cobro interoperables (empieza con 000201).
const qrEjemplo =
    '00020101021143650016com.mercadolibre0201...5204000053030325802AR5913JONATAN TEST6004CABA63041D3C';

/// Escribe el negocio con el formato ANTERIOR (6 campos, sin QR) para probar
/// que lo ya guardado en los teléfonos se sigue leyendo.
class SwitchableShopAdapter extends TypeAdapter<ShopModel> {
  static bool writeLegacy = false;
  final _real = ShopModelAdapter();

  @override
  int get typeId => 1;

  @override
  ShopModel read(BinaryReader reader) => _real.read(reader);

  @override
  void write(BinaryWriter writer, ShopModel obj) {
    if (!writeLegacy) return _real.write(writer, obj);
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.addressLine1)
      ..writeByte(2)
      ..write(obj.addressLine2)
      ..writeByte(3)
      ..write(obj.phoneNumber)
      ..writeByte(4)
      ..write(obj.paymentAlias)
      ..writeByte(5)
      ..write(obj.footerText);
  }
}

void main() {
  group('reglas del QR de cobro', () {
    test('reconoce el formato estándar de Mercado Pago y bancos', () {
      expect(looksLikePaymentQr(qrEjemplo), isTrue);
      expect(looksLikePaymentQr('  $qrEjemplo  '), isTrue);
    });

    test('un enlace u otro texto no parece QR de cobro estándar', () {
      expect(looksLikePaymentQr('https://link.mercadopago.com.ar/algo'), isFalse);
      expect(looksLikePaymentQr(''), isFalse);
    });

    test('rechaza vacíos y textos demasiado largos', () {
      expect(isUsablePaymentQr(qrEjemplo), isTrue);
      expect(isUsablePaymentQr('   '), isFalse);
      expect(isUsablePaymentQr('0' * (maxPaymentQrLength + 1)), isFalse);
      expect(isUsablePaymentQr('0' * maxPaymentQrLength), isTrue);
    });
  });

  group('negocio con QR', () {
    test('copyWith y comparación incluyen el QR', () {
      const base = Shop(name: 'K');
      final conQr = base.copyWith(paymentQr: qrEjemplo);
      expect(conQr.paymentQr, qrEjemplo);
      expect(conQr, isNot(base));
      expect(conQr.copyWith(name: 'Otro').paymentQr, qrEjemplo);
    });

    test('el QR viaja a la nube y vuelve', () {
      final shop = const Shop(name: 'K', paymentAlias: 'k.mp').copyWith(paymentQr: qrEjemplo);
      final row = shopToRow(shop);
      expect(row['payment_qr'], qrEjemplo);
      expect(rowToShop(row), shop);
    });

    test('filas de la nube sin el campo (cuentas viejas) quedan sin QR', () {
      expect(rowToShop({'name': 'K'}).paymentQr, '');
      expect(rowToShop({'name': 'K', 'payment_qr': null}).paymentQr, '');
    });
  });

  group('persistencia del negocio', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('cobra_shop_test');
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(SwitchableShopAdapter());
      }
      SwitchableShopAdapter.writeLegacy = false;
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('el QR sobrevive a guardar y reabrir', () async {
      var box = await Hive.openBox<ShopModel>('shop');
      await box.put('k', ShopModel.fromEntity(const Shop(name: 'K').copyWith(paymentQr: qrEjemplo)));
      await box.close();

      box = await Hive.openBox<ShopModel>('shop');
      expect(box.get('k')!.paymentQr, qrEjemplo);
    });

    test('un negocio guardado antes de esta versión se lee sin QR y sin perder datos',
        () async {
      SwitchableShopAdapter.writeLegacy = true;
      var box = await Hive.openBox<ShopModel>('shop');
      await box.put(
          'k',
          ShopModel.fromEntity(
              const Shop(name: 'Kiosco Lucía', paymentAlias: 'lucia.mp', phoneNumber: '123')));
      await box.close();

      SwitchableShopAdapter.writeLegacy = false;
      box = await Hive.openBox<ShopModel>('shop');
      final leido = box.get('k')!;

      expect(leido.paymentQr, '');
      expect(leido.name, 'Kiosco Lucía');
      expect(leido.paymentAlias, 'lucia.mp');
      expect(leido.phoneNumber, '123');
    });
  });

  group('panel de cobro con Mercado Pago', () {
    Future<void> abrir(WidgetTester tester,
        {String qr = '', String alias = '', double total = 8300}) {
      return tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PaymentQrPanel(qr: qr, alias: alias, total: total),
          ),
        ),
      ));
    }

    testWidgets('con QR cargado: monto grande y el QR del comercio', (tester) async {
      await abrir(tester, qr: qrEjemplo, alias: 'jonaram727');

      expect(find.text('Cobrar \$8300.00'), findsOneWidget);
      expect(find.byType(PrettyQrView), findsOneWidget);
      expect(find.text('jonaram727'), findsOneWidget);
      expect(find.textContaining('escanea'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin QR pero con alias: se muestra el alias para transferir',
        (tester) async {
      await abrir(tester, alias: 'jonaram727');

      expect(find.byType(PrettyQrView), findsNothing,
          reason: 'ya no se muestra un QR inventado (el link no funcionaba)');
      expect(find.text('jonaram727'), findsOneWidget);
      expect(find.byTooltip('Copiar alias'), findsOneWidget);
      expect(find.text('Cobrar \$8300.00'), findsOneWidget);
      expect(find.textContaining('cargá tu QR'), findsOneWidget);
    });

    testWidgets('copiar el alias lo deja en el portapapeles', (tester) async {
      String? copiado;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiado = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await abrir(tester, alias: 'jonaram727');
      await tester.tap(find.byTooltip('Copiar alias'));
      await tester.pump();

      expect(copiado, 'jonaram727');
      expect(find.text('Alias copiado'), findsOneWidget);
    });

    testWidgets('sin QR ni alias: avisa dónde configurarlos', (tester) async {
      await abrir(tester);

      expect(find.byType(PrettyQrView), findsNothing);
      expect(find.textContaining('Cargá tu QR o tu alias'), findsOneWidget);
      expect(find.text('Cobrar \$8300.00'), findsOneWidget);
    });
  });
}

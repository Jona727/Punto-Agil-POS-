// Comprueba el cableado real de la app cuando Supabase SÍ está configurado:
// guardar un producto debe dejar un cambio en la cola de sincronización.
//
//   flutter test test/sync/wiring_test.dart \
//     --dart-define=SUPABASE_URL=https://ejemplo.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=sb_publishable_ejemplo
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cobra/core/config/app_config.dart';
import 'package:cobra/core/data/hive_database.dart';
import 'package:cobra/core/service_locator.dart' as di;
import 'package:cobra/features/billing/data/models/sale_item_model.dart';
import 'package:cobra/features/billing/data/models/sale_model.dart';
import 'package:cobra/features/product/data/models/product_model.dart';
import 'package:cobra/features/product/domain/entities/product.dart';
import 'package:cobra/features/product/domain/usecases/product_usecases.dart';
import 'package:cobra/features/shop/data/models/shop_model.dart';
import 'package:cobra/features/sync/data/hive_sync_storage.dart';
import 'package:cobra/features/sync/domain/sync_models.dart';
import 'package:cobra/features/sync/domain/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final configurado = AppConfig.isSupabaseConfigured;

  test('con Supabase configurado, agregar un producto queda en la cola',
      () async {
    final dir = await Directory.systemTemp.createTemp('cobra_wiring');
    addTearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });
    Hive.init(dir.path);
    Hive
      ..registerAdapter(ProductModelAdapter())
      ..registerAdapter(ShopModelAdapter())
      ..registerAdapter(SaleItemModelAdapter())
      ..registerAdapter(SaleModelAdapter());
    await Hive.openBox<ProductModel>(HiveDatabase.productBoxName);
    await Hive.openBox<ShopModel>(HiveDatabase.shopBoxName);
    await Hive.openBox<SaleModel>(HiveDatabase.salesBoxName);
    await Hive.openBox(HiveDatabase.settingsBoxName);
    await Hive.openBox(HiveDatabase.syncOutboxBoxName);

    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
    await di.init();

    expect(di.sl.isRegistered<SyncService>(), isTrue);
    expect(di.sl<SyncRecorder>(), same(di.sl<SyncService>()));

    // Lo mismo que hace la pantalla "Agregar producto".
    final result = await di.sl<AddProductUseCase>()(
        const Product(id: 'p1', name: 'Yerba', barcode: '1', price: 10));
    expect(result.isRight(), isTrue);

    final pendientes = HiveSyncOutbox().pending();
    expect(pendientes.length, 1);
    expect(pendientes.single.kind, SyncKind.product);
    expect(pendientes.single.id, 'p1');
  }, skip: configurado ? null : 'requiere --dart-define de Supabase');
}

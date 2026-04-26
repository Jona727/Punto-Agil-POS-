import 'package:get_it/get_it.dart';
import '../../features/product/data/repositories/product_repository_impl.dart';
import '../../features/product/domain/repositories/product_repository.dart';
import '../../features/product/domain/usecases/product_usecases.dart';
import '../../features/product/presentation/bloc/product_bloc.dart';
import '../../features/shop/data/repositories/shop_repository_impl.dart';
import '../../features/shop/domain/repositories/shop_repository.dart';
import '../../features/shop/domain/usecases/shop_usecases.dart';
import '../../features/shop/presentation/bloc/shop_bloc.dart';
import '../../features/settings/data/repositories/printer_repository_impl.dart';
import '../../features/settings/domain/repositories/printer_repository.dart';
import '../../features/settings/presentation/bloc/printer_bloc.dart';
import '../../features/billing/data/repositories/sale_repository_impl.dart';
import '../../features/billing/domain/repositories/sale_repository.dart';
import '../../features/billing/domain/usecases/sale_usecases.dart';
import '../../features/billing/presentation/bloc/billing_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Features - Product
  // Bloc
  sl.registerFactory(
    () => ProductBloc(
      getProductsUseCase: sl(),
      addProductUseCase: sl(),
      updateProductUseCase: sl(),
      deleteProductUseCase: sl(),
      updatePricesMassivelyUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => ShopBloc(
      getShopUseCase: sl(),
      updateShopUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => PrinterBloc(
      repository: sl(),
    ),
  );

  // Features - Billing
  sl.registerFactory(
    () => BillingBloc(
      getProductByBarcodeUseCase: sl(),
      saveSaleUseCase: sl(),
      getDailySalesUseCase: sl(),
      voidSaleUseCase: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => GetProductsUseCase(sl()));
  sl.registerLazySingleton(() => AddProductUseCase(sl()));
  sl.registerLazySingleton(() => UpdateProductUseCase(sl()));
  sl.registerLazySingleton(() => DeleteProductUseCase(sl()));
  sl.registerLazySingleton(() => GetProductByBarcodeUseCase(sl()));
  sl.registerLazySingleton(() => UpdatePricesMassivelyUseCase(sl()));

  // Features - Shop
  // Use cases
  sl.registerLazySingleton(() => GetShopUseCase(sl()));
  sl.registerLazySingleton(() => UpdateShopUseCase(sl()));

  // Features - Billing (Sales)
  sl.registerLazySingleton(() => SaveSaleUseCase(sl()));
  sl.registerLazySingleton(() => GetDailySalesUseCase(sl()));
  sl.registerLazySingleton(() => VoidSaleUseCase(sl()));

  // Repositories
  sl.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(),
  );

  sl.registerLazySingleton<ShopRepository>(
    () => ShopRepositoryImpl(),
  );

  sl.registerLazySingleton<PrinterRepository>(
    () => PrinterRepositoryImpl(),
  );

  sl.registerLazySingleton<SaleRepository>(
    () => SaleRepositoryImpl(),
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'config/routes/app_routes.dart';
import 'core/config/app_config.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/sync/domain/sync_service.dart';
import 'core/data/hive_database.dart';
import 'core/service_locator.dart' as di;
import 'core/theme/app_theme.dart';
import 'features/billing/presentation/bloc/billing_bloc.dart';
import 'features/product/presentation/bloc/product_bloc.dart';
import 'features/shop/presentation/bloc/shop_bloc.dart';
import 'features/settings/presentation/bloc/printer_bloc.dart';
import 'features/settings/presentation/bloc/printer_event.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveDatabase.init();
  if (AppConfig.isSupabaseConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }
  await di.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthBloc _authBloc = di.sl<AuthBloc>();
  late final _router = createRouter(_authBloc);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _authBloc),
        BlocProvider<ProductBloc>(
            create: (context) => di.sl<ProductBloc>()..add(LoadProducts())),
        BlocProvider<ShopBloc>(
            create: (context) => di.sl<ShopBloc>()..add(LoadShopEvent())),
        BlocProvider<BillingBloc>(
            create: (context) => di.sl<BillingBloc>()),
        BlocProvider<PrinterBloc>(
            create: (context) => di.sl<PrinterBloc>()..add(InitPrinterEvent())),
      ],
      child: _SyncBridge(
        child: MaterialApp.router(
          title: 'Cobrá',
          theme: AppTheme.lightTheme,
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

/// Conecta la sesión con la sincronización:
/// - al haber sesión iniciada, arranca la sincronización con esa cuenta;
/// - cuando la nube trae cambios, recarga productos y datos del negocio.
class _SyncBridge extends StatefulWidget {
  final Widget child;
  const _SyncBridge({required this.child});

  @override
  State<_SyncBridge> createState() => _SyncBridgeState();
}

class _SyncBridgeState extends State<_SyncBridge> {
  StreamSubscription<void>? _changes;
  StreamSubscription<AuthState>? _auth;

  @override
  void initState() {
    super.initState();
    if (!di.sl.isRegistered<SyncService>()) return; // app sin Supabase

    final sync = di.sl<SyncService>();
    final authBloc = context.read<AuthBloc>();

    _changes = sync.dataChanges.listen((_) {
      if (!mounted) return;
      context.read<ProductBloc>().add(LoadProducts());
      context.read<ShopBloc>().add(LoadShopEvent());
    });

    void onAuth(AuthState s) {
      if (s.status == AuthStatus.authenticated && s.user != null) {
        unawaited(sync.onSignedIn(s.user!.id));
      } else {
        sync.onSignedOut();
      }
    }

    onAuth(authBloc.state);
    _auth = authBloc.stream
        .distinct((a, b) => a.status == b.status && a.user == b.user)
        .listen(onAuth);
  }

  @override
  void dispose() {
    _changes?.cancel();
    _auth?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

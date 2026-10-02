/// Datos de conexión a Supabase.
///
/// No se escriben en el código: se pasan al compilar, por ejemplo
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJ...
/// La anon key es pública por diseño (la seguridad la dan las reglas RLS),
/// pero así evitamos mezclar proyectos de prueba y de producción.
///
/// Si no se pasan, la app funciona 100% local, como hasta ahora.
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

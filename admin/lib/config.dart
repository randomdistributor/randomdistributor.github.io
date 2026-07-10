/// App configuration. Values can be overridden at build time with
/// --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// The anon key is safe to ship in a client (RLS protects the data).
class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jeyygyomrqhiresojdty.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpleXlneW9tcnFoaXJlc29qZHR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2NzQ2MTMsImV4cCI6MjA5OTI1MDYxM30.FqWx_M0swUQxLYCQ2zJpPkSOkYvgHpa3GtwZUrZi6y0',
  );

  static const appName = 'Random Distributors — Admin';
}

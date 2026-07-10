/// Buyer app configuration.
/// Override at build time with --dart-define=SUPABASE_URL=... etc.
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

  /// Suppliers/buyers log in with mobile + PIN. The mobile is mapped to an
  /// internal email so no SMS provider is needed. MUST match the
  /// admin-provision Edge Function's LOGIN_DOMAIN.
  static const loginDomain = 'randomdistributors.app';

  static String loginEmail(String mobile) =>
      '${mobile.replaceAll(RegExp(r'[^0-9]'), '')}@$loginDomain';

  static const appName = 'Random Distributors';
}

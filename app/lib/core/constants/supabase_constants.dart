import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConstants {
  // Lấy URL và Anon Key từ file .env an toàn
  static String get url =>
      dotenv.isInitialized ? (dotenv.env['SUPABASE_URL'] ?? '') : '';
  static String get anonKey =>
      dotenv.isInitialized ? (dotenv.env['SUPABASE_ANON_KEY'] ?? '') : '';

  // Deep Link redirect scheme cho Mobile Google OAuth
  static String get redirectScheme => dotenv.isInitialized
      ? (dotenv.env['AUTH_REDIRECT_SCHEME'] ?? 'io.supabase.fconnect')
      : 'io.supabase.fconnect';
  static String get redirectUrl => dotenv.isInitialized
      ? (dotenv.env['AUTH_REDIRECT_URL'] ?? 'io.supabase.fconnect://login-callback/')
      : 'io.supabase.fconnect://login-callback/';

  // Google Sign-In Web Client ID từ .env
  static String get googleWebClientId => dotenv.isInitialized
      ? (dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '')
      : '';
}

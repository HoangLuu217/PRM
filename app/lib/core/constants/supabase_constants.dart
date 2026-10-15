import 'package:flutter/foundation.dart';
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

  // Redirect URL phù hợp cho từng nền tảng:
  // - Web: Tự động lấy origin hiện tại (ví dụ: http://localhost:3000/ hoặc cổng đang chạy)
  // - Mobile: Trả về Deep Link (io.supabase.fconnect://login-callback/)
  static String get authRedirectUrl {
    if (kIsWeb) {
      try {
        final uri = Uri.base;
        if (uri.scheme == 'http' || uri.scheme == 'https') {
          return '${uri.origin}/';
        }
      } catch (_) {}
      return 'http://localhost:3000/';
    }
    return redirectUrl;
  }

  // Google Sign-In Web Client ID từ .env
  static String get googleWebClientId => dotenv.isInitialized
      ? (dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '')
      : '';
}

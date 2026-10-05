import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  // Lấy Base URL tự động thông minh theo môi trường (Android Emulator: 10.0.2.2, Web/Desktop: localhost)
  static String get baseUrl {
    if (dotenv.isInitialized &&
        dotenv.env['API_BASE_URL'] != null &&
        dotenv.env['API_BASE_URL']!.trim().isNotEmpty) {
      return dotenv.env['API_BASE_URL']!.trim();
    }

    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:5000/api';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      default:
        return 'http://localhost:5000/api';
    }
  }

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String profile = '/auth/profile';
  static const String sendEmailOtp = '/auth/send-email-otp';
  static const String verifyEmailOtp = '/auth/verify-email-otp';
  static const String resetPassword = '/auth/reset-password';
  static const String businesses = '/businesses';
  static const String bookings = '/bookings';
  static const String articles = '/articles';
}
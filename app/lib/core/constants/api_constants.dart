import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  // Lấy Base URL duy nhất từ file .env, tự động chuyển 10.0.2.2 thành localhost nếu chạy Web
  static String get baseUrl {
    final url = dotenv.isInitialized ? (dotenv.env['API_BASE_URL'] ?? '') : '';
    if (kIsWeb && url.contains('10.0.2.2')) {
      return url.replaceAll('10.0.2.2', 'localhost');
    }
    return url;
  }

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String profile = '/auth/profile';
  static const String sendEmailOtp = '/auth/send-email-otp';
  static const String verifyEmailOtp = '/auth/verify-email-otp';
  static const String resetPassword = '/auth/reset-password';
  static const String businesses = '/businesses';
  static const String onboardBusiness = '/businesses/onboard';
  static const String bookings = '/bookings';
  static const String myBookings = '/bookings/me';
  static const String tables = '/tables';
  static const String orders = '/orders';
  static const String myOrders = '/orders/me';
  static const String ownerBookings = '/owner/bookings';
  static const String ownerOrders = '/owner/orders';
  static const String articles = '/articles';
}
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  // Lấy Base URL: nếu chạy Web thì luôn trỏ thẳng localhost:5000, nếu Mobile thì đọc từ .env
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    final url = dotenv.isInitialized ? (dotenv.env['API_BASE_URL'] ?? '') : '';
    if (url.isEmpty) {
      return 'http://10.0.2.2:5000/api';
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
  static const String reviews = '/reviews';
}

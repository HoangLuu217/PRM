import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  // Configure API_BASE_URL with the deployed API URL when building for production.
  static String get baseUrl {
    final url = dotenv.isInitialized ? (dotenv.env['API_BASE_URL'] ?? '') : '';
    if (url.trim().isNotEmpty) {
      return url.trim().replaceFirst(RegExp(r'/+$'), '');
    }
    return kIsWeb ? 'http://localhost:5000/api' : 'http://10.0.2.2:5000/api';
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
  static const String favorites = '/favorites';
}
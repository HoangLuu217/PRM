import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get baseUrl {
    final url = dotenv.isInitialized ? (dotenv.env['API_BASE_URL'] ?? '') : '';
    if (url.trim().isNotEmpty) {
      return url.trim().replaceFirst(RegExp(r'/+$'), '');
    }
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    return 'http://10.0.2.2:5000/api';
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
  static const String customerBookings = '/bookings/customer';
  static const String tables = '/tables';
  static const String orders = '/orders';
  static const String myOrders = '/orders/me';
  static const String customerOrders = '/orders/customer';
  static const String ownerBookings = '/owner/bookings';
  static const String ownerOrders = '/owner/orders';
  static const String articles = '/articles';
  static const String notifications = '/notifications';
  static const String reviews = '/reviews';
  static const String favorites = '/favorites';
}
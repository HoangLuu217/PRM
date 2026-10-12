import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  // Lấy Base URL duy nhất từ file .env
  static String get baseUrl =>
      dotenv.isInitialized ? (dotenv.env['API_BASE_URL'] ?? '') : '';

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String profile = '/auth/profile';
  static const String sendEmailOtp = '/auth/send-email-otp';
  static const String verifyEmailOtp = '/auth/verify-email-otp';
  static const String resetPassword = '/auth/reset-password';
}
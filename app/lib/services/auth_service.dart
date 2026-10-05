import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';
import '../models/user_model.dart';

class AuthService {
  static const String _tokenKey = 'jwt_token';

  // Save token locally
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // Get token locally
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Remove token locally (Logout)
  Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // Login API
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final token = data['token'] ?? data['data']?['token'];
        final rawData = data['data'] is Map ? data['data'] : null;
        final userData = data['user'] ?? rawData?['user'] ?? rawData ?? data;

        if (token != null) {
          await saveToken(token);
        }

        return {
          'success': true,
          'token': token,
          'user': userData != null ? User.fromJson(userData) : null,
          'message': data['message'] ?? 'Login successful',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  // Gửi mã OTP xác nhận đăng ký tài khoản về Email
  Future<Map<String, dynamic>> sendRegisterOtp(String email, {String? fullName}) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.sendEmailOtp}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'fullName': fullName?.trim() ?? '',
          'type': 'REGISTER',
          'recaptchaToken': 'dev_recaptcha_bypass_token',
        }),
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message'] ?? (response.statusCode == 200 ? 'Đã gửi mã xác thực OTP qua email' : 'Không thể gửi mã OTP'),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối máy chủ: $e',
      };
    }
  }

  // Register API
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    String role = 'USER', // 'USER' or 'MERCHANT'
    String? phone,
    String? otpCode,
  }) async {
    try {
      final Map<String, dynamic> requestBody = {
        'fullName': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'role': role,
        'phone': phone ?? '',
      };

      if (otpCode != null && otpCode.trim().isNotEmpty) {
        requestBody['otpCode'] = otpCode.trim();
      }

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.register}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['success'] == true) {
          final token = data['token'] ?? data['data']?['token'];
          final rawData = data['data'] is Map ? data['data'] : null;
          final userData = data['user'] ?? rawData?['user'] ?? rawData ?? data;

          if (token != null) {
            await saveToken(token);
          }

          return {
            'success': true,
            'token': token,
            'user': userData != null ? User.fromJson(userData) : null,
            'message': data['message'] ?? 'Registration successful',
          };
        }
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Registration failed',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  // Get Current User Profile API
  Future<User?> getProfile() async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profile}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawData = data['data'] is Map ? data['data'] : null;
        final userData = data['user'] ?? rawData?['user'] ?? rawData ?? data;
        if (userData != null) {
          return User.fromJson(userData);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Update Profile API
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> updateData) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profile}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updateData),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final rawData = data['data'] is Map ? data['data'] : null;
        final userData = data['user'] ?? rawData?['user'] ?? rawData ?? data;
        return {
          'success': true,
          'user': userData != null ? User.fromJson(userData) : null,
          'message': data['message'] ?? 'Profile updated successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Update failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  // Google Login API
  Future<Map<String, dynamic>> googleLogin({
    required String email,
    required String fullName,
    String? avatarUrl,
    String? googleId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'fullName': fullName,
          'avatarUrl': avatarUrl ?? '',
          'googleId': googleId ?? '',
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final token = data['token'] ?? data['data']?['token'];
        final rawData = data['data'] is Map ? data['data'] : null;
        final userData = data['user'] ?? rawData?['user'] ?? rawData ?? data;

        if (token != null) {
          await saveToken(token);
        }

        return {
          'success': true,
          'token': token,
          'user': userData != null ? User.fromJson(userData) : null,
          'message': data['message'] ?? 'Google login successful',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Google login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  // Gửi mã OTP xác nhận đặt lại mật khẩu về Email
  Future<Map<String, dynamic>> sendResetPasswordOtp(String email) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.sendEmailOtp}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'type': 'RESET_PASSWORD',
        }),
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message'] ?? (response.statusCode == 200 ? 'Đã gửi mã OTP qua email' : 'Không thể gửi mã OTP'),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối máy chủ: $e',
      };
    }
  }

  // Xác thực mã OTP
  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
    String type = 'RESET_PASSWORD',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.verifyEmailOtp}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'otp': otp.trim(),
          'type': type,
        }),
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message'] ?? (response.statusCode == 200 ? 'Xác thực OTP thành công' : 'Mã OTP không chính xác hoặc đã hết hạn'),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối máy chủ: $e',
      };
    }
  }

  // Đặt lại mật khẩu với mã OTP
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.resetPassword}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'otp': otp.trim(),
          'newPassword': newPassword,
        }),
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message'] ?? (response.statusCode == 200 ? 'Đặt lại mật khẩu thành công' : 'Đặt lại mật khẩu thất bại'),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối máy chủ: $e',
      };
    }
  }
}

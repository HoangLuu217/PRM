import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';
import '../models/user_model.dart';

class AuthService {
  static const String _tokenKey = 'jwt_token';
  static const String _roleKey = 'user_role';
  static const String _userKey = 'cached_user_profile';
  static const String _pendingRoleKey = 'pending_oauth_role';

  // Lưu và lấy role tạm thời khi chuẩn bị chuyển hướng Google OAuth
  Future<void> savePendingOAuthRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingRoleKey, role);
  }

  Future<String?> getPendingOAuthRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingRoleKey);
  }

  Future<void> clearPendingOAuthRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingRoleKey);
  }

  // Helper tạo headers chuẩn kèm bypass cho localtunnel
  Map<String, String> _headers([String? token]) {
    final map = {
      'Content-Type': 'application/json',
      'Bypass-Tunnel-Reminder': 'true',
    };
    if (token != null && token.isNotEmpty) {
      map['Authorization'] = 'Bearer $token';
    }
    return map;
  }

  // Save token & role locally
  Future<void> saveToken(String token, [String? role]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    if (role != null && role.isNotEmpty) {
      await prefs.setString(_roleKey, role);
    }
  }

  Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }

  Future<String?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<User?> getCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString(_userKey);
      if (userStr != null && userStr.isNotEmpty) {
        final map = jsonDecode(userStr);
        return User.fromJson(map);
      }
    } catch (_) {}
    return null;
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
    await prefs.remove(_roleKey);
    await prefs.remove(_userKey);
    await prefs.remove(_pendingRoleKey);
  }

  // Login API
  Future<Map<String, dynamic>> login(String email, String password, {String? role}) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}'),
        headers: _headers(),
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'password': password,
          if (role != null && role.isNotEmpty) 'role': role,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final token = data['token'] ?? data['data']?['token'];
        final rawData = data['data'] is Map ? data['data'] : null;
        final userData = data['user'] ?? rawData?['user'] ?? rawData ?? data;

        final userObj = userData != null ? User.fromJson(userData) : null;
        if (token != null) {
          await saveToken(token, userObj?.role);
        }
        if (userObj != null) {
          await saveUser(userObj);
        }

        return {
          'success': true,
          'token': token,
          'user': userObj,
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
  // Gửi mã OTP xác nhận đăng ký tài khoản về Email
  Future<Map<String, dynamic>> sendRegisterOtp(
    String email, {
    String? fullName,
    String? role,
    String? phone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.sendEmailOtp}'),
        headers: _headers(),
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'fullName': fullName?.trim() ?? '',
          'role': role,
          'phone': phone?.trim() ?? '',
          'type': 'REGISTER',
          'recaptchaToken': 'dev_recaptcha_bypass_token',
        }),
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message'] ?? (response.statusCode == 200 ? 'Đã gửi mã xác thực OTP qua email' : 'Không thể gửi mã OTP'),
        'isNetworkError': false,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối máy chủ: $e',
        'isNetworkError': true,
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
        headers: _headers(),
        body: jsonEncode(requestBody),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['success'] == true) {
          final token = data['token'] ?? data['data']?['token'];
          final rawData = data['data'] is Map ? data['data'] : null;
          final userData = data['user'] ?? rawData?['user'] ?? rawData ?? data;

          final userObj = userData != null ? User.fromJson(userData) : null;
          if (token != null) {
            await saveToken(token, userObj?.role);
          }
          if (userObj != null) {
            await saveUser(userObj);
          }

          return {
            'success': true,
            'token': token,
            'user': userObj,
            'message': data['message'] ?? 'Registration successful',
            'isNetworkError': false,
          };
        }
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Registration failed',
        'isNetworkError': false,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: $e',
        'isNetworkError': true,
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
        headers: _headers(token),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawData = data['data'] is Map ? data['data'] : null;
        final userData = data['user'] ?? rawData?['user'] ?? rawData ?? data;
        if (userData != null) {
          final user = User.fromJson(userData);
          if (user.role.isNotEmpty) {
            await saveRole(user.role);
          }
          await saveUser(user);
          return user;
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await removeToken();
        return null;
      }
      return await getCachedUser();
    } catch (e) {
      // Khi mất mạng hoặc timeout, lấy thông tin user đã lưu trong bộ nhớ cục bộ
      return await getCachedUser();
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
        headers: _headers(token),
        body: jsonEncode(updateData),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final rawData = data['data'] is Map ? data['data'] : null;
        final userData = data['user'] ?? rawData?['user'] ?? rawData ?? data;
        final userObj = userData != null ? User.fromJson(userData) : null;
        if (userObj != null) {
          await saveUser(userObj);
        }
        return {
          'success': true,
          'user': userObj,
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
    String? role,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/auth/google'),
        headers: _headers(),
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'fullName': fullName,
          'avatarUrl': avatarUrl ?? '',
          'googleId': googleId ?? '',
          if (role != null && role.isNotEmpty) 'role': role,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        return {
          'success': false,
          'message': 'Máy chủ backend phản hồi lỗi (${response.statusCode}): ${response.reasonPhrase ?? 'Tunnel/Server Unavailable'}. Vui lòng kiểm tra API_BASE_URL trong file .env',
        };
      }

      final dynamic data;
      try {
        data = jsonDecode(response.body);
      } catch (jsonErr) {
        return {
          'success': false,
          'message': 'Định dạng phản hồi không hợp lệ từ backend: $jsonErr. Vui lòng kiểm tra API_BASE_URL.',
        };
      }

      if (data['success'] == true) {
        final token = data['token'] ?? data['data']?['token'];
        final rawData = data['data'] is Map ? data['data'] : null;
        final userData = data['user'] ?? rawData?['user'] ?? rawData ?? data;

        final userObj = userData != null ? User.fromJson(userData) : null;
        if (token != null) {
          await saveToken(token, userObj?.role);
        }
        if (userObj != null) {
          await saveUser(userObj);
        }

        return {
          'success': true,
          'token': token,
          'user': userObj,
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
        'message': 'Lỗi kết nối máy chủ backend: $e',
      };
    }
  }

  // Gửi mã OTP xác nhận đặt lại mật khẩu về Email
  Future<Map<String, dynamic>> sendResetPasswordOtp(String email) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.sendEmailOtp}'),
        headers: _headers(),
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
        headers: _headers(),
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
        headers: _headers(),
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

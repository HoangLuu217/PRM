import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/supabase_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final SupabaseAuthService _supabaseAuthService = SupabaseAuthService();

  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _token != null && _user != null;
  String get userRole => _user?.role.toUpperCase().trim() ?? 'USER';

  bool get isOwner {
    if (_user == null) return false;
    final r = _user!.role.toUpperCase().trim();
    return r == 'MERCHANT' ||
        r == 'OWNER' ||
        r == 'ADMIN' ||
        _user!.business != null ||
        _user!.fullName.toLowerCase().contains('chủ quán') ||
        _user!.fullName.toLowerCase().contains('owner');
  }

  // Check auth status on app start (Splash Screen)
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Kiểm tra Supabase Auth trước nếu có
      if (SupabaseAuthService.isConfigured()) {
        final supabaseUser = _supabaseAuthService.getCurrentUser();
        if (supabaseUser != null) {
          _user = supabaseUser;
          _token = SupabaseAuthService.client.auth.currentSession?.accessToken ?? 'supabase_session';
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      // 2. Kiểm tra token từ local storage (Backend JWT)
      _token = await _authService.getToken();
      if (_token != null) {
        _user = await _authService.getProfile();
        if (_user == null) {
          await _authService.removeToken();
          _token = null;
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
      _token = null;
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Login action
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Nếu cấu hình Supabase, ưu tiên đăng nhập qua Supabase
    if (SupabaseAuthService.isConfigured()) {
      final supaResult = await _supabaseAuthService.signIn(email: email, password: password);
      if (supaResult['success'] == true) {
        _token = supaResult['token'];
        _user = supaResult['user'];
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return true;
      }
    }

    final result = await _authService.login(email, password);

    _isLoading = false;
    if (result['success'] == true) {
      _token = result['token'];
      _user = result['user'];
      _errorMessage = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'] ?? 'Login failed';
      notifyListeners();
      return false;
    }
  }

  // Gửi mã OTP xác nhận đăng ký tài khoản
  Future<Map<String, dynamic>> sendRegisterOtp(String email, {String? fullName}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.sendRegisterOtp(email, fullName: fullName);
      _isLoading = false;
      if (result['success'] != true) {
        _errorMessage = result['message'];
      }
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  // Register action
  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    String role = 'USER',
    String? phone,
    String? otpCode,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (SupabaseAuthService.isConfigured()) {
      final supaResult = await _supabaseAuthService.signUp(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        phone: phone,
      );

      if (supaResult['success'] == true) {
        _token = supaResult['token'];
        _user = supaResult['user'];
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return true;
      }
    }

    final result = await _authService.register(
      fullName: fullName,
      email: email,
      password: password,
      role: role,
      phone: phone,
      otpCode: otpCode,
    );

    _isLoading = false;
    if (result['success'] == true) {
      _token = result['token'];
      _user = result['user'];
      _errorMessage = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'] ?? 'Registration failed';
      notifyListeners();
      return false;
    }
  }

  // Update Profile action
  Future<bool> updateProfile(Map<String, dynamic> updateData) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.updateProfile(updateData);

    _isLoading = false;
    if (result['success'] == true) {
      _user = result['user'] ?? _user;
      _errorMessage = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'] ?? 'Update failed';
      notifyListeners();
      return false;
    }
  }

  // Logout action
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _supabaseAuthService.signOut();
    await _authService.removeToken();
    _token = null;
    _user = null;
    _isLoading = false;
    notifyListeners();
  }

  // Google Login action (Hỗ trợ cả Backend Google & Supabase OAuth)
  Future<bool> googleLogin({
    required String email,
    required String fullName,
    String? avatarUrl,
    String? googleId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.googleLogin(
      email: email,
      fullName: fullName,
      avatarUrl: avatarUrl,
      googleId: googleId,
    );

    _isLoading = false;
    if (result['success'] == true) {
      _token = result['token'];
      _user = result['user'];
      _errorMessage = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'] ?? 'Google login failed';
      notifyListeners();
      return false;
    }
  }

  // Đăng nhập Google trực tiếp qua Supabase OAuth
  Future<bool> signInWithSupabaseGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _supabaseAuthService.signInWithGoogle();
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Gửi mã OTP xác nhận quên mật khẩu
  Future<Map<String, dynamic>> sendResetPasswordOtp(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.sendResetPasswordOtp(email);
      _isLoading = false;
      if (result['success'] != true) {
        _errorMessage = result['message'];
      }
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  // Xác thực mã OTP trước khi cho phép nhập mật khẩu mới
  Future<Map<String, dynamic>> verifyResetPasswordOtp({
    required String email,
    required String otp,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.verifyOtp(
        email: email,
        otp: otp,
        type: 'RESET_PASSWORD',
      );
      _isLoading = false;
      if (result['success'] != true) {
        _errorMessage = result['message'];
      }
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  // Đặt lại mật khẩu với mã OTP
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.resetPassword(
        email: email,
        otp: otp,
        newPassword: newPassword,
      );
      _isLoading = false;
      if (result['success'] != true) {
        _errorMessage = result['message'];
      }
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'message': e.toString()};
    }
  }
}

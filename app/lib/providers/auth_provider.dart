import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/supabase_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final SupabaseAuthService _supabaseAuthService = SupabaseAuthService();

  User? _user;
  String? _token;
  String? _savedRole;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _token != null && _user != null;
  bool get isLoggedIn => isAuthenticated;
  String get userRole => _user?.role.toUpperCase().trim() ?? _savedRole?.toUpperCase().trim() ?? 'USER';

  bool get isOwner {
    if (_user != null) {
      return _user!.isOwner;
    }
    final saved = (_savedRole ?? '').toUpperCase().trim();
    if (saved == 'USER' || saved == 'CUSTOMER') return false;
    return saved == 'MERCHANT' || saved == 'OWNER' || saved == 'BUSINESS_OWNER' || saved == 'ADMIN';
  }

  // Check auth status on app start (Splash Screen)
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _savedRole = await _authService.getSavedRole();
      final pendingRole = await _authService.getPendingOAuthRole();

      // 1. Kiểm tra token từ local storage (Backend JWT)
      _token = await _authService.getToken();
      if (_token != null) {
        _user = await _authService.getProfile();
        if (_user != null) {
          if (pendingRole == 'MERCHANT' && _user!.role != 'MERCHANT') {
            await _authService.clearPendingOAuthRole();
            final updated = await _authService.updateProfile({'role': 'MERCHANT'});
            if (updated['success'] == true && updated['user'] != null) {
              _user = updated['user'];
            }
          }
          _savedRole = _user!.role;
          await _authService.saveRole(_savedRole!);
          // Đồng bộ FCM token nếu phiên đăng nhập còn hiệu lực
          try {
            NotificationService().syncTokenWithBackend();
          } catch (_) {}
          _isLoading = false;
          notifyListeners();
          return;
        } else {
          await _authService.removeToken();
          _token = null;
        }
      }

      // 2. Nếu chưa có Backend token nhưng có phiên Supabase, tự động đồng bộ sang Backend
      if (SupabaseAuthService.isConfigured()) {
        final supabaseUser = _supabaseAuthService.getCurrentUser();
        if (supabaseUser != null && supabaseUser.email.isNotEmpty) {
          if (pendingRole != null) {
            await _authService.clearPendingOAuthRole();
          }
          final supaRaw = SupabaseAuthService.client.auth.currentUser;
          final metadata = supaRaw?.userMetadata ?? {};
          final targetRole = pendingRole ?? _savedRole ?? metadata['role']?.toString();
          final res = await _authService.googleLogin(
            email: supabaseUser.email,
            fullName: metadata['full_name'] ?? metadata['name'] ?? supabaseUser.fullName,
            avatarUrl: metadata['avatar_url'] ?? metadata['picture'] ?? supabaseUser.avatarUrl,
            googleId: metadata['sub'] ?? supabaseUser.id,
            role: targetRole,
          );
          if (res['success'] == true) {
            _token = res['token'];
            _user = res['user'];
            _savedRole = _user?.role ?? targetRole;
            if (_savedRole != null && _savedRole!.isNotEmpty) {
              await _authService.saveRole(_savedRole!);
            }
            _isLoading = false;
            notifyListeners();
            return;
          }
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
  Future<bool> login(String email, String password, {String? role}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // 1. Luôn ưu tiên đăng nhập qua Node.js REST API backend (MongoDB)
    final result = await _authService.login(email, password, role: role);

    if (result['success'] == true) {
      _token = result['token'];
      _user = result['user'];
      _savedRole = _user?.role ?? role;
      if (_savedRole != null && _savedRole!.isNotEmpty) {
        await _authService.saveRole(_savedRole!);
      }
      _errorMessage = null;
      _isLoading = false;

      // Đồng bộ phiên đăng nhập Supabase ngầm (nếu có cấu hình)
      if (SupabaseAuthService.isConfigured()) {
        try {
          await _supabaseAuthService.signIn(email: email, password: password);
        } catch (_) {}
      }

      // Tự động đẩy FCM Device Token lên backend để nhận Push Notification
      try {
        NotificationService().syncTokenWithBackend();
      } catch (e) {
        debugPrint('[Notification Sync Error]: $e');
      }

      notifyListeners();
      return true;
    }

    // 2. Dự phòng: Đăng nhập qua Supabase nếu tài khoản chỉ có trên Supabase
    if (SupabaseAuthService.isConfigured()) {
      final supaResult = await _supabaseAuthService.signIn(email: email, password: password);
      if (supaResult['success'] == true) {
        _token = supaResult['token'];
        _user = supaResult['user'];
        _savedRole = role ?? _user?.role;
        if (_savedRole != null && _savedRole!.isNotEmpty) {
          await _authService.saveRole(_savedRole!);
        }
        _isLoading = false;
        _errorMessage = null;

        // Tự động đẩy FCM Device Token lên backend
        try {
          NotificationService().syncTokenWithBackend();
        } catch (e) {
          debugPrint('[Notification Sync Error]: $e');
        }

        notifyListeners();
        return true;
      }
    }

    _isLoading = false;
    _errorMessage = result['message'] ?? 'Email hoặc mật khẩu không chính xác';
    notifyListeners();
    return false;
  }

  // Gửi mã OTP xác nhận đăng ký tài khoản
  Future<Map<String, dynamic>> sendRegisterOtp(
    String email, {
    String? fullName,
    String? role,
    String? phone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.sendRegisterOtp(
        email,
        fullName: fullName,
        role: role,
        phone: phone,
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

    // 1. Luôn ưu tiên đăng ký qua Node.js REST API backend (MongoDB)
    final result = await _authService.register(
      fullName: fullName,
      email: email,
      password: password,
      role: role,
      phone: phone,
      otpCode: otpCode,
    );

    if (result['success'] == true) {
      _token = result['token'];
      _user = result['user'];
      _savedRole = _user?.role ?? role;
      if (_savedRole != null && _savedRole!.isNotEmpty) {
        await _authService.saveRole(_savedRole!);
      }
      _errorMessage = null;
      _isLoading = false;

      // Đồng bộ tạo tài khoản trên Supabase (nếu có cấu hình)
      if (SupabaseAuthService.isConfigured()) {
        try {
          await _supabaseAuthService.signUp(
            email: email,
            password: password,
            fullName: fullName,
            role: role,
            phone: phone,
          );
        } catch (_) {}
      }

      notifyListeners();
      return true;
    }

    // 2. Dự phòng: Chỉ đăng ký qua Supabase NẾU LỖI MẠNG (backend Node.js không phản hồi)
    // Tuyệt đối không fallback nếu backend đã trả về lỗi (tài khoản đã tồn tại, OTP không đúng,...)
    final isNetworkError = result['isNetworkError'] == true ||
        (result['message'] != null && result['message'].toString().contains('Connection error'));

    if (isNetworkError && SupabaseAuthService.isConfigured()) {
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
        _savedRole = role;
        if (_savedRole != null && _savedRole!.isNotEmpty) {
          await _authService.saveRole(_savedRole!);
        }
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return true;
      }
    }

    _isLoading = false;
    _errorMessage = result['message'] ?? 'Registration failed';
    notifyListeners();
    return false;
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
    _savedRole = null;
    _isLoading = false;
    notifyListeners();
  }

  // Google Login action (Hỗ trợ cả Backend Google & Supabase OAuth)
  Future<bool> googleLogin({
    required String email,
    required String fullName,
    String? avatarUrl,
    String? googleId,
    String? role,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.googleLogin(
      email: email,
      fullName: fullName,
      avatarUrl: avatarUrl,
      googleId: googleId,
      role: role,
    );

    _isLoading = false;
    if (result['success'] == true) {
      _token = result['token'];
      _user = result['user'];
      _savedRole = _user?.role ?? role;
      if (_savedRole != null && _savedRole!.isNotEmpty) {
        await _authService.saveRole(_savedRole!);
      }
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

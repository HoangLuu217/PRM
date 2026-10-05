import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../core/constants/supabase_constants.dart';
import '../models/user_model.dart';

class SupabaseAuthService {
  static SupabaseClient get client => Supabase.instance.client;

  static bool isConfigured() {
    return SupabaseConstants.url.isNotEmpty &&
        !SupabaseConstants.url.contains('your-project-id') &&
        SupabaseConstants.anonKey.isNotEmpty &&
        !SupabaseConstants.anonKey.contains('your-anon-key');
  }

  // Đăng ký tài khoản qua Supabase Auth
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String fullName,
    String role = 'USER',
    String? phone,
  }) async {
    try {
      if (!isConfigured()) {
        return {
          'success': false,
          'message': 'Supabase chưa được cấu hình URL/AnonKey trong supabase_constants.dart',
        };
      }

      final AuthResponse res = await client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'role': role,
          'phone': phone ?? '',
        },
      );

      final supabaseUser = res.user;
      if (supabaseUser != null) {
        final user = User(
          id: supabaseUser.id,
          fullName: fullName,
          email: supabaseUser.email ?? email,
          phone: phone,
          role: role,
          authProvider: 'SUPABASE',
          status: 'ACTIVE',
        );

        return {
          'success': true,
          'token': res.session?.accessToken,
          'user': user,
          'message': 'Đăng ký Supabase thành công!',
        };
      }

      return {'success': false, 'message': 'Đăng ký thất bại'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi Supabase: $e'};
    }
  }

  // Đăng nhập Email & Password qua Supabase Auth
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      if (!isConfigured()) {
        return {
          'success': false,
          'message': 'Supabase chưa được cấu hình URL/AnonKey trong supabase_constants.dart',
        };
      }

      final AuthResponse res = await client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final supabaseUser = res.user;
      if (supabaseUser != null) {
        final metadata = supabaseUser.userMetadata ?? {};
        final user = User(
          id: supabaseUser.id,
          fullName: metadata['full_name'] ?? metadata['name'] ?? email.split('@')[0],
          email: supabaseUser.email ?? email,
          phone: metadata['phone'] ?? supabaseUser.phone,
          role: metadata['role'] ?? 'USER',
          avatarUrl: metadata['avatar_url'] ?? metadata['picture'],
          authProvider: 'SUPABASE',
          status: 'ACTIVE',
        );

        return {
          'success': true,
          'token': res.session?.accessToken,
          'user': user,
          'message': 'Đăng nhập Supabase thành công!',
        };
      }

      return {'success': false, 'message': 'Email hoặc mật khẩu không chính xác'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi Supabase: $e'};
    }
  }

  // Đăng nhập Google qua Supabase OAuth (Hỗ trợ Web và Mobile)
  Future<bool> signInWithGoogle() async {
    try {
      if (!isConfigured()) {
        throw Exception('Supabase chưa được cấu hình URL/AnonKey trong supabase_constants.dart');
      }

      final bool success = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : SupabaseConstants.redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      return success;
    } catch (e) {
      debugPrint('[Supabase Google Sign-In Error]: $e');
      rethrow;
    }
  }

  // Lấy thông tin phiên người dùng hiện tại
  User? getCurrentUser() {
    final supabaseUser = client.auth.currentUser;
    if (supabaseUser == null) return null;

    final metadata = supabaseUser.userMetadata ?? {};
    return User(
      id: supabaseUser.id,
      fullName: metadata['full_name'] ?? metadata['name'] ?? supabaseUser.email?.split('@')[0] ?? 'User',
      email: supabaseUser.email ?? '',
      phone: metadata['phone'] ?? supabaseUser.phone,
      role: metadata['role'] ?? 'USER',
      avatarUrl: metadata['avatar_url'] ?? metadata['picture'],
      authProvider: 'SUPABASE',
      status: 'ACTIVE',
    );
  }

  // Gửi email đặt lại mật khẩu qua Supabase Auth
  Future<Map<String, dynamic>> resetPasswordForEmail(String email) async {
    try {
      if (!isConfigured()) {
        return {
          'success': false,
          'message': 'Supabase chưa được cấu hình',
        };
      }
      await client.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: kIsWeb ? null : SupabaseConstants.redirectUrl,
      );
      return {
        'success': true,
        'message': 'Đã gửi hướng dẫn đặt lại mật khẩu tới email của bạn!',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi Supabase: $e'};
    }
  }

  // Đăng xuất khỏi Supabase
  Future<void> signOut() async {
    try {
      if (isConfigured()) {
        await client.auth.signOut();
      }
    } catch (e) {
      debugPrint('[Supabase SignOut Error]: $e');
    }
  }
}

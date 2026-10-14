import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../core/constants/supabase_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_auth_service.dart';
import '../customer/customer_home_screen.dart';
import '../owner/owner_dashboard_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isGoogleLoggingIn = false;
  String _selectedRole = kIsWeb ? 'MERCHANT' : 'USER'; // Trên Web mặc định là Cổng Chủ Quán (MERCHANT)
  StreamSubscription<AuthState>? _supabaseAuthSubscription;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  void _onEmailChanged() {
    final email = _emailController.text.trim().toLowerCase();
    if (kIsWeb ||
        email.contains('owner') ||
        email.startsWith('chu') ||
        email.contains('merchant') ||
        email.contains('admin') ||
        email.contains('quanly')) {
      if (_selectedRole != 'MERCHANT' && mounted) {
        setState(() => _selectedRole = 'MERCHANT');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _selectedRole = 'MERCHANT';
    }
    _emailController.addListener(_onEmailChanged);

    // Hiệu ứng Animation mở đầu mượt mà
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animController.forward();
    });

    // Lắng nghe sự kiện đăng nhập khi hoàn tất OAuth Web Browser Flow
    if (SupabaseAuthService.isConfigured()) {
      _supabaseAuthSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        if (data.event == AuthChangeEvent.signedIn && mounted) {
          final session = data.session;
          final supaUser = session?.user;
          if (supaUser != null && supaUser.email != null && supaUser.email!.isNotEmpty) {
            final authService = AuthService();
            final pendingRole = await authService.getPendingOAuthRole();
            await authService.clearPendingOAuthRole();
            if (!mounted) return;

            final metadata = supaUser.userMetadata ?? {};
            final email = supaUser.email!;
            final fullName = metadata['full_name'] ??
                metadata['name'] ??
                email.split('@')[0];
            final avatarUrl = metadata['avatar_url'] ?? metadata['picture'];
            final googleId = metadata['sub'] ?? supaUser.id;

            final isOwnerEmail = email.toLowerCase().contains('owner') ||
                email.toLowerCase().startsWith('chu') ||
                email.toLowerCase().contains('merchant');
            final effectiveRole = (pendingRole == 'MERCHANT' || isOwnerEmail) ? 'MERCHANT' : null;

            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            final success = await authProvider.googleLogin(
              email: email,
              fullName: fullName,
              avatarUrl: avatarUrl,
              googleId: googleId,
              role: effectiveRole,
            );

            if (!mounted) return;
            if (success) {
              if (effectiveRole == 'MERCHANT') {
                _selectedRole = 'MERCHANT';
              }
              _navigateByRole(authProvider.userRole);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(authProvider.errorMessage ?? 'Đăng nhập Google thất bại'),
                  backgroundColor: const Color(0xFFE53935),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _animController.dispose();
    _supabaseAuthSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _navigateByRole(String role) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (authProvider.user != null) {
      userProvider.setUser(authProvider.user);
    }

    final userRole = (authProvider.user?.role ?? role).toUpperCase().trim();
    final userEmail = (authProvider.user?.email ?? _emailController.text).toLowerCase().trim();
    final userName = (authProvider.user?.fullName ?? '').toLowerCase().trim();

    final isMerchant = authProvider.isOwner ||
        _selectedRole == 'MERCHANT' ||
        userRole == 'MERCHANT' ||
        userRole == 'OWNER' ||
        userRole == 'BUSINESS_OWNER' ||
        userRole == 'ADMIN' ||
        (authProvider.user?.business != null) ||
        userEmail.contains('owner') ||
        userEmail.startsWith('chu') ||
        userEmail.contains('merchant') ||
        userEmail.contains('admin') ||
        userEmail.contains('quanly') ||
        userName.contains('chủ') ||
        userName.contains('owner');

    if (isMerchant) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OwnerDashboardScreen()),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
        (route) => false,
      );
    }
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim().toLowerCase();
      final isOwnerEmail = email.contains('owner') ||
          email.startsWith('chu') ||
          email.contains('merchant') ||
          email.contains('admin') ||
          email.contains('quanly');
      final effectiveRole = isOwnerEmail
          ? 'MERCHANT'
          : (_selectedRole == 'MERCHANT' ? 'MERCHANT' : null);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.login(
        _emailController.text,
        _passwordController.text,
        role: effectiveRole,
      );

      if (!mounted) return;

      if (success) {
        _navigateByRole(authProvider.userRole);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(authProvider.errorMessage ?? 'Đăng nhập thất bại')),
              ],
            ),
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _handleGoogleLogin() async {
    if (_isGoogleLoggingIn) return;

    setState(() {
      _isGoogleLoggingIn = true;
    });

    try {
      if (!SupabaseAuthService.isConfigured()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Supabase chưa được cấu hình URL/AnonKey trong file .env'),
            backgroundColor: Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _isGoogleLoggingIn = false;
        });
        return;
      }

      // Đăng xuất phiên Supabase cũ nếu có để người dùng luôn được chọn tài khoản
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}

      // Lưu role được chọn trước khi chuyển hướng OAuth (Web reload làm mất State bộ nhớ)
      final effectiveRole = _selectedRole == 'MERCHANT' ? 'MERCHANT' : 'USER';
      final authService = AuthService();
      await authService.savePendingOAuthRole(effectiveRole);

      // Mở quy trình đăng nhập Google OAuth (Mở tab/cửa sổ ngoài để không làm đứt phiên debug của tab chính)
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: SupabaseConstants.authRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
        queryParams: const {
          'prompt': 'select_account',
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi mở trình duyệt đăng nhập Google: $e'),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoggingIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Ảnh Nền background.png từ thư mục public
          Positioned.fill(
            child: Image.asset(
              'public/background.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0F172A),
                      Color(0xFF1E293B),
                      Color(0xFF0F172A),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Lớp phủ Gradient Tối nhẹ để background.png hiển thị rõ ràng và form nổi bật
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.60),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),

          // 4. Nội dung Form Đăng Nhập Glassmorphism
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo & Header Brand
                          _buildBrandHeader(),
                          const SizedBox(height: 28),

                          // Glassmorphism Card Container
                          ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 26.0, vertical: 28.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.28),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.75),
                                      blurRadius: 40,
                                      offset: const Offset(0, 18),
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFF0072FF).withValues(alpha: 0.20),
                                      blurRadius: 32,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  kIsWeb
                                      ? 'Đăng Nhập Quản Trị'
                                      : (_selectedRole == 'MERCHANT' ? 'Cổng Quản Trị Quán F&B' : 'Đăng Nhập'),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  kIsWeb
                                      ? 'Hệ thống quản lý dành cho Đối tác & Chủ quán F&B'
                                      : (_selectedRole == 'MERCHANT'
                                          ? 'Dành riêng cho Chủ Quán & Quản trị viên cơ sở F&B'
                                          : 'Chào mừng bạn trở lại với FConnect F&B'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                                if (!kIsWeb) ...[
                                  const SizedBox(height: 20),
                                  _buildRoleSelector(),
                                  const SizedBox(height: 20),
                                ] else ...[
                                  const SizedBox(height: 24),
                                ],

                                // Email Input Field
                                _buildTextField(
                                  controller: _emailController,
                                  labelText: 'Địa chỉ Email',
                                  hintText: 'name@example.com',
                                  icon: Icons.alternate_email_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Vui lòng nhập email';
                                    }
                                    if (!value.contains('@') || !value.contains('.')) {
                                      return 'Email không đúng định dạng';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Password Input Field
                                _buildTextField(
                                  controller: _passwordController,
                                  labelText: 'Mật khẩu',
                                  hintText: '••••••••',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.white.withValues(alpha: 0.6),
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  validator: (value) {
                                    if (value == null || value.length < 6) {
                                      return 'Mật khẩu phải từ 6 ký tự trở lên';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),

                                // Forgot Password Link
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(50, 30),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Quên mật khẩu?',
                                      style: TextStyle(
                                        color: Color(0xFF38BDF8),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Nút Đăng nhập Gradient
                                _buildGradientLoginButton(authProvider),
                                const SizedBox(height: 20),

                                // Divider "Hoặc đăng nhập với"
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(color: Colors.white.withValues(alpha: 0.18)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text(
                                        'hoặc tiếp tục với',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.55),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(color: Colors.white.withValues(alpha: 0.18)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),

                                // Google Sign-in Button
                                _buildGoogleSignInButton(authProvider),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                          // Footer: Chưa có tài khoản -> Đăng ký
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Bạn chưa có tài khoản? ',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 14,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                  );
                                },
                                child: const Text(
                                  'Đăng ký ngay',
                                  style: TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
        ],
      ),
    );
  }

  // Widget Header Logo & Brand từ file public/logo.png
  Widget _buildBrandHeader() {
    return Column(
      children: [
        Container(
          width: 86,
          height: 86,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00C6FF).withValues(alpha: 0.40),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'public/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.restaurant_menu_rounded,
                size: 44,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'FConnect',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Nền tảng Ẩm thực & Đặt bàn Thông minh',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFFE2E8F0),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  // Widget TextField chuẩn xu hướng 2026
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        labelStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF38BDF8),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 13.5,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF38BDF8), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFF87171), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFF87171), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11.5, fontWeight: FontWeight.w500),
      ),
      validator: validator,
    );
  }

  // Widget Bộ chọn Vai trò: Khách hàng vs Chủ quán F&B (Chỉ dùng cho Mobile)
  Widget _buildRoleSelector() {
    final isMerchant = _selectedRole == 'MERCHANT';
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMerchant ? const Color(0xFFEA580C).withValues(alpha: 0.4) : const Color(0xFF334155),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          // Tab 1: Khách hàng
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedRole = 'USER'),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !isMerchant ? const Color(0xFF2563EB) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: !isMerchant
                      ? [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.45),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 17,
                      color: !isMerchant ? Colors.white : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Khách hàng',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: !isMerchant ? Colors.white : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tab 2: Chủ quán F&B
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedRole = 'MERCHANT'),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isMerchant ? const Color(0xFFEA580C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isMerchant
                      ? [
                          BoxShadow(
                            color: const Color(0xFFEA580C).withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.storefront_rounded,
                      size: 17,
                      color: isMerchant ? Colors.white : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Chủ quán F&B',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isMerchant ? Colors.white : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget Nút Login Gradient Electric Cyan / Royal Blue hoặc Sunset Orange cho Chủ Quán
  Widget _buildGradientLoginButton(AuthProvider authProvider) {
    final isMerchant = kIsWeb || _selectedRole == 'MERCHANT';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: isMerchant
              ? const [Color(0xFFEA580C), Color(0xFFF97316), Color(0xFFFB923C)]
              : const [Color(0xFF00C6FF), Color(0xFF0072FF), Color(0xFF1D4ED8)],
        ),
        boxShadow: [
          BoxShadow(
            color: (isMerchant ? const Color(0xFFEA580C) : const Color(0xFF0072FF)).withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: authProvider.isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: authProvider.isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isMerchant ? Icons.storefront_rounded : Icons.login_rounded,
                    size: 19,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      kIsWeb
                          ? 'Đăng Nhập'
                          : (_selectedRole == 'MERCHANT' ? 'Đăng Nhập Cổng Chủ Quán' : 'Đăng Nhập'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // Widget Nút Google Sign-in Glassmorphism
  Widget _buildGoogleSignInButton(AuthProvider authProvider) {
    final bool isBusy = authProvider.isLoading || _isGoogleLoggingIn;
    final isMerchant = kIsWeb || _selectedRole == 'MERCHANT';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMerchant ? const Color(0xFFEA580C).withValues(alpha: 0.45) : const Color(0xFF334155),
          width: 1.2,
        ),
      ),
      child: OutlinedButton(
        onPressed: isBusy ? null : _handleGoogleLogin,
        style: OutlinedButton.styleFrom(
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: isBusy && _isGoogleLoggingIn
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Google Icon Logo
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.g_mobiledata_rounded,
                      color: Color(0xFF4285F4),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      kIsWeb
                          ? 'Đăng nhập với Google'
                          : (_selectedRole == 'MERCHANT' ? 'Đăng nhập Google (Chủ Quán)' : 'Đăng nhập với Google'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

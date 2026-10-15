import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../auth/login_screen.dart';
import '../customer/customer_home_screen.dart';
import 'product/owner_product_list_screen.dart';
import 'widgets/merchant_onboarding_dialog.dart';

class OwnerDashboardScreen extends StatefulWidget {
  final bool showOnboardingImmediately;
  final int initialTabIndex;

  const OwnerDashboardScreen({
    super.key,
    this.showOnboardingImmediately = false,
    this.initialTabIndex = 0,
  });

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  late int _selectedTab;
  bool _hasCheckedOnboarding = false;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptOnboarding();
    });
  }

  void _checkAndPromptOnboarding() {
    if (_hasCheckedOnboarding || !mounted) return;
    _hasCheckedOnboarding = true;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final hasBusiness = user?.business != null &&
        (user?.business?['name']?.toString() ?? '').trim().isNotEmpty;

    // Nếu tài khoản là Khách hàng (USER) và không sở hữu cơ sở F&B:
    // Trên Web: Đăng xuất và đưa về LoginScreen (cổng web chỉ dành cho Chủ quán)
    // Trên Mobile: Chuyển sang Giao diện Khách hàng (CustomerHomeScreen)
    if (!authProvider.isOwner && !hasBusiness) {
      if (kIsWeb) {
        authProvider.logout();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
        );
      }
      return;
    }

    if (widget.showOnboardingImmediately || !hasBusiness) {
      MerchantOnboardingDialog.show(context, onCompleted: () {
        if (mounted) setState(() {});
      });
    }
  }

  void _openOnboardingForm() {
    MerchantOnboardingDialog.show(context, onCompleted: () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _launchGoogleMaps(String url) async {
    if (url.trim().isEmpty) return;
    try {
      final uri = Uri.parse(url.trim());
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Launch map url error: $e');
    }
  }

  void _showStorefrontPreview(Map<String, dynamic>? biz, User? user) {
    final businessName = biz?['name']?.toString() ?? 'Nhà Hàng Của Bạn';
    final categoryName = biz?['category']?.toString() ?? 'F&B Restaurant';
    final district = biz?['address']?['district']?.toString() ?? biz?['district']?.toString() ?? 'Hải Châu';
    final city = biz?['address']?['city']?.toString() ?? biz?['city']?.toString() ?? 'Đà Nẵng';
    final street = biz?['address']?['street']?.toString() ?? 'Chi nhánh chính';
    final addressFull = '$street, $district, $city';
    final minPrice = biz?['priceRange']?['min'] ?? 20000;
    final maxPrice = biz?['priceRange']?['max'] ?? 100000;
    final priceText = '${(minPrice / 1000).toInt()}k – ${(maxPrice / 1000).toInt()}k VNĐ';
    final vibesList = biz?['vibes'];
    final vibes = (vibesList is List && vibesList.isNotEmpty)
        ? List<String>.from(vibesList)
        : <String>['Yên tĩnh / Làm việc', 'Ấm cúng / Gia đình'];
    final coverVal = biz?['coverImageUrl']?.toString() ?? '';
    final coverImageUrl = coverVal.startsWith('http')
        ? coverVal
        : 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80';
    final logoVal = biz?['logoUrl']?.toString() ?? '';
    final logoUrl = logoVal.startsWith('http')
        ? logoVal
        : 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=300&q=80';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: 580,
          constraints: const BoxConstraints(maxHeight: 700),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Modal
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.remove_red_eye_rounded, color: Color(0xFF2563EB), size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Xem Trước Trang Quán (Customer Storefront View)',
                        style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),

              // Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cover Image & Logo Overlap
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            height: 180,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: NetworkImage(coverImageUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.1),
                                    Colors.white.withValues(alpha: 0.95),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 14,
                            right: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fiber_manual_record_rounded, color: Colors.white, size: 10),
                                  SizedBox(width: 5),
                                  Text('Đang mở cửa', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -32,
                            left: 20,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFF2563EB), width: 2.5),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                              ),
                              child: CircleAvatar(
                                radius: 32,
                                backgroundColor: const Color(0xFFEFF6FF),
                                backgroundImage: NetworkImage(logoUrl),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // Restaurant Info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    businessName,
                                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 16),
                                      SizedBox(width: 4),
                                      Text('4.9 (128)', style: TextStyle(color: Color(0xFFD97706), fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              categoryName,
                              style: const TextStyle(color: Color(0xFF2563EB), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, color: Color(0xFF64748B), size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    addressFull,
                                    style: const TextStyle(color: Color(0xFF475569), fontSize: 12.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.payments_outlined, color: Color(0xFF64748B), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  priceText,
                                  style: const TextStyle(color: Color(0xFF475569), fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Vibes Badges
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: vibes.map((v) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Text(v, style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 11.5, fontWeight: FontWeight.w500)),
                              )).toList(),
                            ),
                            const SizedBox(height: 20),

                            // Mock Customer Booking Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: null,
                                    icon: const Icon(Icons.table_restaurant_rounded, size: 18),
                                    label: const Text('Đặt Bàn Ngay (Demo)'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      disabledBackgroundColor: const Color(0xFF2563EB),
                                      disabledForegroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: null,
                                    icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
                                    label: const Text('Xem Menu Món'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF2563EB),
                                      disabledForegroundColor: const Color(0xFF2563EB),
                                      side: const BorderSide(color: Color(0xFF2563EB)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 18),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Đây là mô phỏng giao diện khách hàng nhìn thấy trên ứng dụng FConnect khi tìm kiếm hoặc ghé thăm trang của bạn.',
                                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQrCodeDialog(Map<String, dynamic>? biz) {
    final businessName = biz?['name']?.toString() ?? 'Nhà Hàng Đối Tác FConnect';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.qr_code_2_rounded, color: Color(0xFF2563EB), size: 22),
                      SizedBox(width: 8),
                      Text('Mã QR Bàn & Menu Số', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                businessName,
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Quét mã để xem thực đơn và gọi món trực tiếp',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Mock Stylized QR Graphic
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12)],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.qr_code_rounded, size: 175, color: const Color(0xFF0F172A)),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'FConnect Smart Dining QR',
                      style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.white),
                                SizedBox(width: 10),
                                Text('Đã lưu mã QR vào danh sách in ấn!'),
                              ],
                            ),
                            backgroundColor: const Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Tải ảnh QR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final passFormKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (stfCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFE2E8F0))),
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Đổi Mật Khẩu Chủ Quán', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          content: Form(
            key: passFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentPassController,
                  obscureText: true,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu hiện tại',
                    labelStyle: const TextStyle(color: Color(0xFF64748B)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập mật khẩu hiện tại' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newPassController,
                  obscureText: true,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu mới (từ 6 ký tự)',
                    labelStyle: const TextStyle(color: Color(0xFF64748B)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                  ),
                  validator: (v) => v == null || v.length < 6 ? 'Mật khẩu phải từ 6 ký tự' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmPassController,
                  obscureText: true,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Xác nhận mật khẩu mới',
                    labelStyle: const TextStyle(color: Color(0xFF64748B)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                  ),
                  validator: (v) => v != newPassController.text ? 'Mật khẩu xác nhận không khớp' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (passFormKey.currentState!.validate()) {
                        setDialogState(() => isSaving = true);
                        final authProvider = Provider.of<AuthProvider>(dialogCtx, listen: false);
                        final success = await authProvider.updateProfile({
                          'currentPassword': currentPassController.text,
                          'newPassword': newPassController.text,
                        });

                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Đổi mật khẩu thành công!' : (authProvider.errorMessage ?? 'Lỗi đổi mật khẩu')),
                            backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditOwnerAccountDialog(User? user) {
    final nameController = TextEditingController(text: user?.fullName ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (stfCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFE2E8F0))),
          title: const Row(
            children: [
              Icon(Icons.manage_accounts_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Cập Nhật Hồ Sơ Chủ Quán', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Họ và tên chủ sở hữu',
                    labelStyle: const TextStyle(color: Color(0xFF64748B)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập họ và tên' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Số điện thoại liên hệ',
                    labelStyle: const TextStyle(color: Color(0xFF64748B)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập số điện thoại' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => isSaving = true);
                        final authProvider = Provider.of<AuthProvider>(dialogCtx, listen: false);
                        final userProvider = Provider.of<UserProvider>(dialogCtx, listen: false);

                        final success = await authProvider.updateProfile({
                          'fullName': nameController.text.trim(),
                          'phone': phoneController.text.trim(),
                        });

                        if (success && authProvider.user != null) {
                          userProvider.setUser(authProvider.user);
                        }

                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        if (!mounted) return;

                        setState(() {});

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Cập nhật tài khoản thành công!' : (authProvider.errorMessage ?? 'Lỗi cập nhật')),
                            backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Cập nhật'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Đăng xuất tài khoản', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi cổng FConnect Partner?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: isDesktop ? _buildDesktopLayout(user) : _buildMobileLayout(user),
          bottomNavigationBar: isDesktop ? null : _buildMobileBottomNav(),
        );
      },
    );
  }

  // ==========================================
  // DESKTOP LAYOUT (SIDEBAR + CONTENT SHELL)
  // ==========================================
  Widget _buildDesktopLayout(User? user) {
    return Row(
      children: [
        // Sidebar Cố Định Bên Trái (White + Blue)
        Container(
          width: 260,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            children: [
              // Sidebar Header Brand
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FConnect',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'PARTNER PORTAL',
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFE2E8F0), height: 1),

              // Navigation Links List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  children: [
                    _buildSidebarItem(0, Icons.dashboard_rounded, 'Tổng quan', 'Member 5'),
                    _buildSidebarItem(1, Icons.restaurant_menu_rounded, 'Thực đơn & Món', 'Member 3'),
                    _buildSidebarItem(2, Icons.event_seat_rounded, 'Bàn & Đặt chỗ', 'Member 4'),
                    _buildSidebarItem(3, Icons.receipt_long_rounded, 'Đơn hàng', 'Member 4'),
                    _buildSidebarItem(4, Icons.chat_bubble_outline_rounded, 'Tin nhắn & CSKH', 'Member 5'),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text(
                        'PHÂN HỆ CỦA BẠN (MEMBER 1)',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    _buildSidebarItem(5, Icons.store_mall_directory_rounded, 'Hồ sơ Quán & Cài đặt', 'Member 1', highlight: true),
                  ],
                ),
              ),

              // Sidebar Footer Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                ),
                child: Column(
                  children: [
                    // Nút Đăng xuất
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () => _handleLogout(context),
                        icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFEF4444)),
                        label: const Text('Đăng xuất', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Content Area Bên Phải
        Expanded(
          child: Column(
            children: [
              // Top Bar Desktop (Clean White)
              Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getTabTitle(_selectedTab),
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Row(
                      children: [
                        // Chip Vai Trò
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified_user_rounded, color: Color(0xFF2563EB), size: 14),
                              SizedBox(width: 6),
                              Text('Chủ Quán F&B', style: TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Avatar
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF2563EB),
                          child: Text(
                            (user?.fullName.isNotEmpty == true ? user!.fullName[0] : 'O').toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Body Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(28),
                  child: _buildCurrentTabContent(user),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String title, String memberTag, {bool highlight = false}) {
    final isSelected = _selectedTab == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ListTile(
        dense: true,
        onTap: () => setState(() => _selectedTab = index),
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : const Color(0xFF64748B),
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF334155),
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withValues(alpha: 0.22) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            memberTag,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // MOBILE LAYOUT (APPBAR + CONTENT + BOTTOM NAV)
  // ==========================================
  Widget _buildMobileLayout(User? user) {
    return Column(
      children: [
        AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          shadowColor: Colors.black12,
          foregroundColor: const Color(0xFF0F172A),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getTabTitle(_selectedTab),
                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
              tooltip: 'Đăng xuất',
              onPressed: () => _handleLogout(context),
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: _buildCurrentTabContent(user),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedTab > 4 ? 4 : _selectedTab,
        onTap: (index) {
          if (index == 4) {
            setState(() => _selectedTab = 5); // Tab Hồ sơ quán
          } else {
            setState(() => _selectedTab = index);
          }
        },
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: const Color(0xFF94A3B8),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded, size: 20),
            label: 'Tổng quan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu_rounded, size: 20),
            label: 'Thực đơn',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_seat_rounded, size: 20),
            label: 'Đặt bàn',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_rounded, size: 20),
            label: 'Đơn hàng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_rounded, size: 20),
            label: 'Hồ sơ Quán',
          ),
        ],
      ),
    );
  }

  String _getTabTitle(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return 'Tổng Quan Hoạt Động';
      case 1:
        return 'Quản Lý Thực Đơn';
      case 2:
        return 'Quản Lý Bàn & Đặt Chỗ';
      case 3:
        return 'Quản Lý Đơn Hàng';
      case 4:
        return 'Hộp Thư Khách Hàng';
      case 5:
        return 'Hồ Sơ Quán & Cài Đặt';
      default:
        return 'FConnect Partner';
    }
  }

  // ==========================================
  // DISPATCHER HIỂN THỊ NỘI DUNG TỪNG TAB
  // ==========================================
  Widget _buildCurrentTabContent(User? user) {
    switch (_selectedTab) {
      case 0:
        return _buildTab0DashboardSkeleton();
      case 1:
        return const OwnerProductListScreen();
      case 2:
        return _buildTab2BookingSkeleton();
      case 3:
        return _buildTab3OrderSkeleton();
      case 4:
        return _buildTab4ChatSkeleton();
      case 5:
      default:
        return _buildTab5BusinessProfile(user);
    }
  }

  // =========================================================================
  // TAB 0: TỔNG QUAN / DASHBOARD (SƯỜN CHO THÀNH VIÊN 5 - DASHBOARD & METRICS)
  // =========================================================================
  Widget _buildTab0DashboardSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSkeletonHeader(
          moduleTitle: 'Tổng Quan Hoạt Động Quán',
          memberTag: 'Thành viên 5 (Dashboard & Communication)',
          description: 'Khung sườn thống kê doanh thu, tần suất đặt bàn và thông báo hệ thống.',
        ),
        const SizedBox(height: 18),

        // KPI Metric Cards Wireframe
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 500;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isWide ? 4 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isWide ? 1.5 : 1.35,
              children: [
                _buildKpiCardSkeleton('Doanh thu hôm nay', '--- đ', Icons.payments_rounded, const Color(0xFFFBBF24)),
                _buildKpiCardSkeleton('Đặt bàn mới', '-- khách', Icons.bookmark_added_rounded, const Color(0xFF38BDF8)),
                _buildKpiCardSkeleton('Bàn đang phục vụ', '-- / --', Icons.table_restaurant_rounded, const Color(0xFF4ADE80)),
                _buildKpiCardSkeleton('Tin nhắn mới', '--', Icons.chat_bubble_outline_rounded, const Color(0xFFA78BFA)),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        // Placeholder Biểu đồ & Hoạt động
        _buildPlaceholderCard(
          icon: Icons.insights_rounded,
          title: 'Khung Sườn Biểu Đồ & Thống Kê',
          subtitle: 'Module này thuộc trách nhiệm của Thành viên 5. Khi hoàn thiện, Thành viên 5 sẽ kết nối NotificationProvider và Dashboard Service để vẽ biểu đồ và hiển thị số liệu thực.',
          actionLabel: 'Làm mới số liệu mẫu',
          onAction: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sườn Dashboard sẵn sàng cho Thành viên 5 tích hợp!')),
            );
          },
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 2: QUẢN LÝ BÀN & ĐẶT CHỖ (SƯỜN CHO THÀNH VIÊN 4 - BOOKINGS & TABLES)
  // =========================================================================
  Widget _buildTab2BookingSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSkeletonHeader(
          moduleTitle: 'Quản Lý Bàn & Đặt Chỗ',
          memberTag: 'Thành viên 4 (Booking & Order)',
          description: 'Khung sườn quản lý sơ đồ bàn và tiếp nhận yêu cầu đặt chỗ của thực khách.',
        ),
        const SizedBox(height: 18),

        // Filter Bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('Tất cả yêu cầu', true),
              _buildFilterChip('Chờ xác nhận (3)', false),
              _buildFilterChip('Đã nhận bàn (5)', false),
              _buildFilterChip('Đã hoàn tất (8)', false),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildSampleListItem('Khách: Nguyễn Văn A • 4 người', 'Thời gian: 19:30 Hôm nay • Bàn số 04 • Trạng thái: Chờ xác nhận', Icons.event_seat_rounded),
        _buildSampleListItem('Khách: Trần Thị B • 2 người', 'Thời gian: 20:00 Hôm nay • Bàn số 01 (View cửa sổ) • Trạng thái: Đã nhận', Icons.event_available_rounded),

        const SizedBox(height: 16),
        _buildPlaceholderCard(
          icon: Icons.table_restaurant_rounded,
          title: 'Khung Sườn TableProvider & BookingProvider',
          subtitle: 'Phân hệ quản lý bàn và xác nhận lịch đặt chỗ theo PROJECT.md sẽ do Thành viên 4 kết nối cơ sở dữ liệu.',
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 3: QUẢN LÝ ĐƠN HÀNG (SƯỜN CHO THÀNH VIÊN 4 - ORDERS)
  // =========================================================================
  Widget _buildTab3OrderSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSkeletonHeader(
          moduleTitle: 'Quản Lý Đơn Hàng Gọi Món',
          memberTag: 'Thành viên 4 (Booking & Order)',
          description: 'Khung sườn theo dõi đơn gọi món tại bàn, chế biến và thanh toán.',
        ),
        const SizedBox(height: 18),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('Đang chế biến (2)', true),
              _buildFilterChip('Đang phục vụ (4)', false),
              _buildFilterChip('Đã thanh toán (15)', false),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildSampleListItem('Đơn #ORD-1042 • Bàn 04', '3 món • Tổng: 185,000đ • Phương thức: Tiền mặt • Đang chế biến', Icons.receipt_long_rounded),
        _buildSampleListItem('Đơn #ORD-1041 • Bàn 02', '5 món • Tổng: 340,000đ • Phương thức: Chuyển khoản • Đang phục vụ', Icons.done_all_rounded),

        const SizedBox(height: 16),
        _buildPlaceholderCard(
          icon: Icons.shopping_bag_outlined,
          title: 'Khung Sườn OrderProvider',
          subtitle: 'Phân hệ theo dõi trạng thái đơn hàng và xuất hóa đơn theo PROJECT.md do Thành viên 4 phụ trách.',
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 4: HỘP THƯ TIN NHẮN (SƯỜN CHO THÀNH VIÊN 5 - CHAT & COMMS)
  // =========================================================================
  Widget _buildTab4ChatSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSkeletonHeader(
          moduleTitle: 'Hộp Thư Trò Chuyện Với Khách',
          memberTag: 'Thành viên 5 (Communication)',
          description: 'Khung sườn trao đổi trực tiếp giữa chủ quán và thực khách đặt bàn.',
        ),
        const SizedBox(height: 18),

        _buildSampleListItem('Khách: Lê Hữu Tuấn', '"Quán mình còn bàn ngoài trời tối nay không ạ?" • 5 phút trước', Icons.chat_rounded),
        _buildSampleListItem('Khách: Hoàng Mai', '"Em đã thanh toán tiền cọc đơn đặt bàn rồi nhé quán" • 30 phút trước', Icons.chat_outlined),

        const SizedBox(height: 16),
        _buildPlaceholderCard(
          icon: Icons.forum_rounded,
          title: 'Khung Sườn ChatProvider',
          subtitle: 'Phân hệ tin nhắn thời gian thực và thông báo đẩy theo PROJECT.md do Thành viên 5 đảm nhận.',
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 5: HỒ SƠ QUÁN & CÀI ĐẶT (TRÁCH NHIỆM CHÍNH CỦA THÀNH VIÊN 1)
  // =========================================================================
  Widget _buildTab5BusinessProfile(User? user) {
    final biz = user?.business;
    final hasBusiness = biz != null && (biz['name']?.toString() ?? '').trim().isNotEmpty;

    final businessName = hasBusiness
        ? (biz['name']?.toString() ?? 'Chưa đặt tên quán')
        : 'Chưa hoàn thiện hồ sơ cơ sở F&B';

    final description = biz?['description']?.toString() ??
        'Hệ thống quán ẩm thực chất lượng cao, phục vụ các món ăn và đồ uống tinh hoa tại Đà Nẵng.';

    final categoryName = biz?['category']?.toString() ?? 'Nhà hàng ẩm thực';
    final district = biz?['address']?['district']?.toString() ??
        biz?['district']?.toString() ??
        'Hải Châu';
    final city = biz?['address']?['city']?.toString() ??
        biz?['city']?.toString() ??
        'Đà Nẵng';
    final street = biz?['address']?['street']?.toString() ?? 'Chi nhánh chính';
    final addressFull = street.isNotEmpty ? '$street, $district, $city' : '$district, $city';
    final phone = biz?['phone']?.toString() ?? user?.phone ?? '0901234567';
    final googleMapsUrl = biz?['googleMapsUrl']?.toString() ?? '';

    final minPrice = biz?['priceRange']?['min'] ?? 20000;
    final maxPrice = biz?['priceRange']?['max'] ?? 100000;
    final priceText = '${(minPrice / 1000).toInt()}k – ${(maxPrice / 1000).toInt()}k VNĐ';

    final vibesList = biz?['vibes'];
    final vibes = (vibesList is List && vibesList.isNotEmpty)
        ? List<String>.from(vibesList)
        : <String>['Yên tĩnh / Làm việc', 'Ấm cúng / Gia đình', 'Không gian thoáng đãng'];

    final purposesList = biz?['purposes'];
    final purposes = (purposesList is List && purposesList.isNotEmpty)
        ? List<String>.from(purposesList)
        : <String>['Gặp gỡ bạn bè', 'Bữa ăn gia đình', 'Hẹn hò cặp đôi'];

    final logoVal = biz?['logoUrl']?.toString() ?? '';
    final logoUrl = logoVal.startsWith('http')
        ? logoVal
        : 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=300&q=80';

    final coverVal = biz?['coverImageUrl']?.toString() ?? '';
    final coverImageUrl = coverVal.startsWith('http')
        ? coverVal
        : 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Hero Restaurant Header Card (Cover, Logo, Title, Quick Actions)
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 18,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover Image Banner with Status Chips
              Stack(
                children: [
                  Container(
                    height: 190,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(coverImageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.08),
                            Colors.white.withValues(alpha: 0.95),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 18,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fiber_manual_record_rounded, color: Colors.white, size: 10),
                              SizedBox(width: 6),
                              Text('Đang mở cửa', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded, color: Color(0xFF2563EB), size: 15),
                              SizedBox(width: 4),
                              Text('Đặt bàn nhanh', style: TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Bottom Identity Info Row
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Avatar Logo Overlapping
                    Transform.translate(
                      offset: const Offset(0, -32),
                      child: Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFF2563EB), width: 2.5),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                        ),
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: const Color(0xFFEFF6FF),
                          backgroundImage: NetworkImage(logoUrl),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),

                    // Restaurant Title & Rating
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  businessName,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.verified_rounded, color: Color(0xFF2563EB), size: 20),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                categoryName,
                                style: const TextStyle(color: Color(0xFF2563EB), fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_outlined, color: Color(0xFF64748B), size: 15),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$district, $city',
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Quick Action Buttons (White & Blue)
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _openOnboardingForm,
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text('Sửa thông tin'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showStorefrontPreview(biz, user),
                          icon: const Icon(Icons.remove_red_eye_rounded, size: 17, color: Color(0xFF2563EB)),
                          label: const Text('Xem trước', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showQrCodeDialog(biz),
                          icon: const Icon(Icons.qr_code_rounded, size: 17, color: Color(0xFF2563EB)),
                          label: const Text('QR Menu bàn', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Responsive 2-Column Body
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktopTwoCol = constraints.maxWidth >= 900;

            final leftColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Single Unified Component: THÔNG TIN & KHÔNG GIAN QUÁN
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 12,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.storefront_rounded, color: Color(0xFF2563EB), size: 22),
                              SizedBox(width: 8),
                              Text(
                                'THÔNG TIN & KHÔNG GIAN QUÁN',
                                style: TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: _openOnboardingForm,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF2563EB)),
                                SizedBox(width: 4),
                                Text(
                                  'Chỉnh sửa',
                                  style: TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      const Row(
                        children: [
                          Icon(Icons.place_rounded, color: Color(0xFF2563EB), size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Địa chỉ & Liên hệ',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildProfileDetailRow(Icons.location_on_outlined, 'Địa chỉ quán:', addressFull),
                      _buildProfileDetailRow(Icons.phone_in_talk_rounded, 'Hotline đặt bàn:', phone),
                      _buildProfileDetailRow(Icons.payments_outlined, 'Khoảng giá:', priceText),
                      if (googleMapsUrl.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(Icons.map_outlined, size: 18, color: Color(0xFF64748B)),
                              const SizedBox(width: 10),
                              const SizedBox(
                                width: 140,
                                child: Text(
                                  'Bản đồ vị trí:',
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _launchGoogleMaps(googleMapsUrl),
                                    icon: const Icon(Icons.open_in_new_rounded, size: 13),
                                    label: const Text('Mở Google Maps'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),
                      const Divider(color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 14),

                      const Row(
                        children: [
                          Icon(Icons.palette_rounded, color: Color(0xFF2563EB), size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Không gian, Vibe & Tiện ích',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: const Border(left: BorderSide(color: Color(0xFF2563EB), width: 3.5)),
                        ),
                        child: Text(
                          description,
                          style: const TextStyle(color: Color(0xFF334155), fontSize: 13.5, height: 1.45),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text('Không gian & Vibe quán:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: vibes.map((v) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.spa_rounded, color: Color(0xFF1D4ED8), size: 14),
                              const SizedBox(width: 6),
                              Text(v, style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 16),

                      const Text('Phù hợp cho mục đích:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: purposes.map((p) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.groups_rounded, color: Color(0xFF15803D), size: 15),
                              const SizedBox(width: 6),
                              Text(p, style: const TextStyle(color: Color(0xFF15803D), fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 16),

                      const Text('Tiện ích phục vụ tại quán:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        runSpacing: 10,
                        children: [
                          _buildAmenityBadge(Icons.wifi_rounded, 'Wifi tốc độ cao'),
                          _buildAmenityBadge(Icons.ac_unit_rounded, 'Máy lạnh / Điều hòa'),
                          _buildAmenityBadge(Icons.local_parking_rounded, 'Bãi đỗ xe rộng rãi'),
                          _buildAmenityBadge(Icons.credit_card_rounded, 'Thanh toán thẻ / QR'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );

            final rightColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Card C: Tài khoản Chủ sở hữu & Bảo mật
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 12,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.manage_accounts_rounded, color: Color(0xFF2563EB), size: 22),
                              SizedBox(width: 8),
                              Text(
                                'TÀI KHOẢN CHỦ SỞ HỮU',
                                style: TextStyle(color: Color(0xFF2563EB), fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: const Text('MERCHANT', style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // User Identity Tile
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: const Color(0xFF2563EB),
                            child: Text(
                              (user?.fullName.isNotEmpty == true ? user!.fullName[0] : 'O').toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.fullName ?? 'Chủ Quán Đối Tác',
                                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user?.email ?? 'chưa cập nhật email',
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 12),
                      _buildProfileDetailRow(Icons.badge_rounded, 'Họ và tên:', user?.fullName ?? 'Chưa cập nhật'),
                      _buildProfileDetailRow(Icons.email_rounded, 'Email đăng nhập:', user?.email ?? 'Chưa cập nhật'),
                      _buildProfileDetailRow(Icons.phone_rounded, 'Số điện thoại:', user?.phone?.isNotEmpty == true ? user!.phone! : 'Chưa thiết lập'),
                      const SizedBox(height: 14),

                      // Account Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showChangePasswordDialog,
                              icon: const Icon(Icons.lock_reset_rounded, size: 16, color: Color(0xFF2563EB)),
                              label: const Text('Đổi mật khẩu', style: TextStyle(color: Color(0xFF2563EB), fontSize: 12.5, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showEditOwnerAccountDialog(user),
                              icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF334155)),
                              label: const Text('Sửa tài khoản', style: TextStyle(color: Color(0xFF334155), fontSize: 12.5, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );

            if (isDesktopTwoCol) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: leftColumn),
                  const SizedBox(width: 20),
                  Expanded(flex: 5, child: rightColumn),
                ],
              );
            } else {
              return Column(
                children: [
                  leftColumn,
                  const SizedBox(height: 18),
                  rightColumn,
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildAmenityBadge(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF2563EB), size: 16),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Color(0xFF334155), fontSize: 12.5, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonHeader({required String moduleTitle, required String memberTag, required String description}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Text(
                moduleTitle,
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w800),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  memberTag,
                  style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildKpiCardSkeleton(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildSampleListItem(String title, String subtitle, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8), size: 18),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2563EB) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF64748B),
          fontSize: 12.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: const Color(0xFF2563EB).withValues(alpha: 0.7)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5, height: 1.4),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2563EB)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(actionLabel, style: const TextStyle(color: Color(0xFF2563EB))),
            ),
          ],
        ],
      ),
    );
  }
}

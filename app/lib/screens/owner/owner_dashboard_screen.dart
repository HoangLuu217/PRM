import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../auth/profile_screen.dart';
import 'widgets/merchant_onboarding_dialog.dart';

class OwnerDashboardScreen extends StatefulWidget {
  final bool showOnboardingImmediately;

  const OwnerDashboardScreen({
    super.key,
    this.showOnboardingImmediately = false,
  });

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  bool _hasCheckedOnboarding = false;

  @override
  void initState() {
    super.initState();
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

    if (widget.showOnboardingImmediately || !hasBusiness) {
      MerchantOnboardingDialog.show(context, onCompleted: () {
        if (mounted) setState(() {});
      });
    }
  }

  void _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Đăng xuất tài khoản', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi FConnect Partner?'),
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

  void _openOnboardingForm() {
    MerchantOnboardingDialog.show(context, onCompleted: () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final biz = user?.business;
    final hasBusiness = biz != null && (biz['name']?.toString() ?? '').trim().isNotEmpty;

    final businessName = hasBusiness
        ? (biz['name']?.toString() ?? 'Quán F&B Partner')
        : 'Cơ sở F&B chưa hoàn thiện';

    final categoryName = biz?['category']?.toString() ??
        (biz?['categories'] is List && (biz!['categories'] as List).isNotEmpty
            ? biz['categories'][0].toString()
            : 'F&B');

    final district = biz?['address']?['district']?.toString() ??
        biz?['district']?.toString() ??
        'Đà Nẵng';

    final street = biz?['address']?['street']?.toString() ?? '';

    final minPrice = biz?['priceRange']?['min'] ?? 20000;
    final maxPrice = biz?['priceRange']?['max'] ?? 100000;
    final priceText = '${(minPrice / 1000).toInt()}k – ${(maxPrice / 1000).toInt()}k';

    final vibes = (biz?['vibes'] is List) ? List<String>.from(biz!['vibes']) : <String>[];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.storefront_rounded, color: Color(0xFFFB923C), size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'FConnect Partner',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF38BDF8)),
            tooltip: 'Cập nhật thông tin quán',
            onPressed: _openOnboardingForm,
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
            tooltip: 'Hồ sơ tài khoản',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFF87171)),
            tooltip: 'Đăng xuất',
            onPressed: () => _handleLogout(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Onboarding Prompt Banner (nếu chưa hoàn thiện hồ sơ)
                  if (!hasBusiness)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.add_business_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Hoàn thiện hồ sơ cơ sở F&B',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Điền thông tin quán để mở bán và đón khách đặt bàn trên FConnect ngay hôm nay!',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _openOnboardingForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1D4ED8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            child: const Text('Nhập ngay', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                  // 2. Welcome Hero Banner
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: hasBusiness
                            ? [const Color(0xFFEA580C), const Color(0xFFC2410C), const Color(0xFF9A3412)]
                            : [const Color(0xFF334155), const Color(0xFF1E293B)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: hasBusiness
                              ? const Color(0xFFEA580C).withValues(alpha: 0.35)
                              : Colors.black.withValues(alpha: 0.2),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    hasBusiness ? Icons.verified_rounded : Icons.pending_actions_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    hasBusiness ? 'ĐỐI TÁC CHÍNH THỨC' : 'CHỜ HOÀN THIỆN HỒ SƠ',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: _openOnboardingForm,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: hasBusiness ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  hasBusiness ? '• Đang mở cửa' : 'Chỉnh sửa hồ sơ',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          businessName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Quản lý: ${user?.fullName ?? "Chủ nhà hàng"} • ${user?.email ?? ""}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        if (hasBusiness) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _buildHeroTag(Icons.category_rounded, categoryName),
                              _buildHeroTag(Icons.location_on_rounded, street.isNotEmpty ? '$street, $district' : district),
                              _buildHeroTag(Icons.payments_rounded, priceText),
                              if (vibes.isNotEmpty)
                                _buildHeroTag(Icons.eco_rounded, vibes.first),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Metrics KPI Grid
                  const Text(
                    'HOẠT ĐỘNG HÔM NAY',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),

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
                          _buildKpiCard(
                            title: 'Đặt bàn mới',
                            value: '12',
                            icon: Icons.bookmark_added_rounded,
                            color: const Color(0xFF38BDF8),
                          ),
                          _buildKpiCard(
                            title: 'Bàn đang phục vụ',
                            value: '8 / 15',
                            icon: Icons.table_restaurant_rounded,
                            color: const Color(0xFF4ADE80),
                          ),
                          _buildKpiCard(
                            title: 'Doanh thu ước tính',
                            value: '4.8M',
                            icon: Icons.attach_money_rounded,
                            color: const Color(0xFFFBBF24),
                          ),
                          _buildKpiCard(
                            title: 'Tin nhắn chờ',
                            value: '3',
                            icon: Icons.chat_bubble_outline_rounded,
                            color: const Color(0xFFA78BFA),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // 4. Quick Actions Management
                  const Text(
                    'QUẢN LÝ VẬN HÀNH',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildActionTile(
                    title: 'Hồ sơ Nhà hàng & Cài đặt Quán',
                    subtitle: 'Cập nhật tên quán, mô hình kinh doanh, địa chỉ, định vị Google Maps',
                    icon: Icons.storefront_rounded,
                    accentColor: const Color(0xFFF97316),
                    onTap: _openOnboardingForm,
                  ),
                  const SizedBox(height: 10),

                  _buildActionTile(
                    title: 'Quản lý Đặt bàn & Khách đến',
                    subtitle: 'Xem danh sách yêu cầu đặt chỗ, thời gian, số lượng khách',
                    icon: Icons.event_available_rounded,
                    accentColor: const Color(0xFF38BDF8),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Chức năng Quản lý Đặt bàn đang đồng bộ theo phân công Member 4'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  _buildActionTile(
                    title: 'Quản lý Thực đơn & Món ăn',
                    subtitle: 'Cập nhật danh mục món, đổi giá, chuyển trạng thái còn/hết hàng',
                    icon: Icons.restaurant_menu_rounded,
                    accentColor: const Color(0xFF34D399),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Chức năng Quản lý Menu đang đồng bộ theo phân công Member 3'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  // 5. Footer Note
                  Center(
                    child: Text(
                      'FConnect PRM393 • Multi-Platform Flutter Architecture',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.35),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
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
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

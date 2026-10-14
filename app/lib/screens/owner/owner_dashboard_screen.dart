import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../customer/customer_home_screen.dart';
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

  void _switchToCustomerView() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
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
          backgroundColor: const Color(0xFF0B132B),
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
        // Sidebar Cố Định Bên Trái
        Container(
          width: 260,
          color: const Color(0xFF1C2541),
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
                        color: const Color(0xFFEA580C),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEA580C).withValues(alpha: 0.4),
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
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'PARTNER PORTAL',
                          style: TextStyle(
                            color: Color(0xFFFB923C),
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
              const Divider(color: Color(0xFF3A506B), height: 1),

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
                          color: Color(0xFF6FFFE9),
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
                  border: Border(top: BorderSide(color: Color(0xFF3A506B), width: 1)),
                ),
                child: Column(
                  children: [
                    // Nút Chuyển Giao diện Khách
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _switchToCustomerView,
                        icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: Color(0xFF38BDF8)),
                        label: const Text('Xem giao diện Khách', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12.5, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Nút Đăng xuất
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () => _handleLogout(context),
                        icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFF87171)),
                        label: const Text('Đăng xuất', style: TextStyle(color: Color(0xFFF87171), fontSize: 13, fontWeight: FontWeight.w600)),
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
              // Top Bar Desktop
              Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                decoration: const BoxDecoration(
                  color: Color(0xFF1C2541),
                  border: Border(bottom: BorderSide(color: Color(0xFF3A506B), width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getTabTitle(_selectedTab),
                      style: const TextStyle(
                        color: Colors.white,
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
                            color: const Color(0xFFEA580C).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified_user_rounded, color: Color(0xFFFB923C), size: 14),
                              SizedBox(width: 6),
                              Text('Chủ Quán F&B', style: TextStyle(color: Color(0xFFFB923C), fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Avatar
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF38BDF8),
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
        color: isSelected
            ? (highlight ? const Color(0xFFEA580C) : const Color(0xFF0072FF))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        onTap: () => setState(() => _selectedTab = index),
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF0B132B),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            memberTag,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
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
          backgroundColor: const Color(0xFF1C2541),
          elevation: 0,
          foregroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                _getTabTitle(_selectedTab),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF38BDF8)),
              tooltip: 'Xem giao diện Khách',
              onPressed: _switchToCustomerView,
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFF87171)),
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
        color: Color(0xFF1C2541),
        border: Border(top: BorderSide(color: Color(0xFF3A506B), width: 1)),
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
        backgroundColor: Colors.transparent,
        selectedItemColor: const Color(0xFFFB923C),
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
        return _buildTab1MenuSkeleton();
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
  // TAB 5: HỒ SƠ QUÁN & CÀI ĐẶT (TRÁCH NHIỆM CHÍNH CỦA THÀNH VIÊN 1 - HOÀN THIỆN)
  // =========================================================================
  Widget _buildTab5BusinessProfile(User? user) {
    final biz = user?.business;
    final hasBusiness = biz != null && (biz['name']?.toString() ?? '').trim().isNotEmpty;

    final businessName = hasBusiness
        ? (biz['name']?.toString() ?? 'Chưa đặt tên quán')
        : 'Chưa hoàn thiện hồ sơ cơ sở F&B';

    final categoryName = biz?['category']?.toString() ?? 'F&B Restaurant';
    final district = biz?['address']?['district']?.toString() ??
        biz?['district']?.toString() ??
        'Đà Nẵng';
    final street = biz?['address']?['street']?.toString() ?? '';
    final addressFull = street.isNotEmpty ? '$street, $district' : district;

    final minPrice = biz?['priceRange']?['min'] ?? 20000;
    final maxPrice = biz?['priceRange']?['max'] ?? 100000;
    final priceText = '${(minPrice / 1000).toInt()}k – ${(maxPrice / 1000).toInt()}k VNĐ';
    final vibes = (biz?['vibes'] is List) ? List<String>.from(biz!['vibes']) : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Member 1 Badge & Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0072FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_ind_rounded, color: Color(0xFF38BDF8), size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phân Hệ: Hồ Sơ Cơ Sở & Quản Lý Vai Trò',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Module phụ trách: Thành viên 1 (Authentication, Business Profile & Role Navigation)',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 1. Thẻ Thông Tin Cơ Sở Quán F&B
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF3A506B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded, color: Color(0xFFFB923C), size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'THÔNG TIN QUÁN ĂN / NHÀ HÀNG',
                        style: TextStyle(color: Color(0xFFFB923C), fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _openOnboardingForm,
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: Text(hasBusiness ? 'Sửa thông tin' : 'Điền hồ sơ ngay'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEA580C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                businessName,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              _buildProfileDetailRow(Icons.category_rounded, 'Mô hình:', categoryName),
              _buildProfileDetailRow(Icons.location_on_rounded, 'Địa chỉ:', addressFull),
              _buildProfileDetailRow(Icons.payments_rounded, 'Khoảng giá:', priceText),
              if (vibes.isNotEmpty)
                _buildProfileDetailRow(Icons.eco_rounded, 'Không gian & Vibe:', vibes.join(', ')),
              _buildProfileDetailRow(Icons.check_circle_outline_rounded, 'Trạng thái:', hasBusiness ? 'Đã hoàn thiện hồ sơ đối tác' : 'Chờ bổ sung thông tin cơ sở'),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 2. Thẻ Thông Tin Chủ Sở Hữu (Tài Khoản)
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF3A506B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_rounded, color: Color(0xFF38BDF8), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'TÀI KHOẢN CHỦ SỞ HỮU',
                    style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildProfileDetailRow(Icons.badge_rounded, 'Họ và tên:', user?.fullName ?? 'Chưa cập nhật'),
              _buildProfileDetailRow(Icons.email_rounded, 'Email đăng nhập:', user?.email ?? 'Chưa cập nhật'),
              _buildProfileDetailRow(Icons.phone_rounded, 'Số điện thoại:', user?.phone?.isNotEmpty == true ? user!.phone! : 'Chưa thiết lập'),
              _buildProfileDetailRow(Icons.security_rounded, 'Vai trò hệ thống:', user?.role ?? 'MERCHANT'),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 3. Khung Điều Hướng Vai Trò (Role Navigation - Yêu cầu PRM393)
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF3A506B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.alt_route_rounded, color: Color(0xFF34D399), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'ĐIỀU HƯỚNG VAI TRÒ (ROLE NAVIGATION)',
                    style: TextStyle(color: Color(0xFF34D399), fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'FConnect cho phép chuyển đổi chế độ xem để kiểm thử trải nghiệm đặt món và duyệt quán của khách hàng:',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _switchToCustomerView,
                icon: const Icon(Icons.people_alt_rounded, size: 18),
                label: const Text('Chuyển Sang Giao Diện Khách Hàng (Customer View)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
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
  // TAB 1: THỰC ĐƠN & MÓN ĂN (SƯỜN CHO THÀNH VIÊN 3 - MENU & PRODUCT)
  // =========================================================================
  Widget _buildTab1MenuSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSkeletonHeader(
          moduleTitle: 'Quản Lý Thực Đơn & Món Ăn',
          memberTag: 'Thành viên 3 (Menu & Cart)',
          description: 'Khung sườn quản lý danh mục món, giá bán và trạng thái còn/hết hàng.',
        ),
        const SizedBox(height: 18),

        // Toolbar Skeleton (Tìm kiếm + Bộ lọc + Thêm món)
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2541),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3A506B)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 18),
                    SizedBox(width: 8),
                    Text('Tìm kiếm món ăn trong thực đơn...', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thành viên 3 sẽ tích hợp MenuProvider để thêm món mới')),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Thêm Món'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Danh Sách Món Ăn Dạng Khung Sườn Mẫu
        _buildSampleListItem('Món ăn #1 (Ví dụ: Cơm gà xối mỡ giòn da)', 'Giá: 55,000đ • Danh mục: Đồ ăn chính • Còn hàng', Icons.fastfood_rounded),
        _buildSampleListItem('Món ăn #2 (Ví dụ: Trà sữa trân châu Ô Long)', 'Giá: 35,000đ • Danh mục: Đồ uống • Còn hàng', Icons.local_cafe_rounded),
        _buildSampleListItem('Món ăn #3 (Ví dụ: Lẩu hải sản chua cay)', 'Giá: 220,000đ • Danh mục: Lẩu & Nướng • Tạm hết hàng', Icons.ramen_dining_rounded),

        const SizedBox(height: 16),
        _buildPlaceholderCard(
          icon: Icons.restaurant_menu_rounded,
          title: 'Khung Sườn MenuProvider',
          subtitle: 'Phân hệ quản lý món ăn và danh mục theo PROJECT.md sẽ do Thành viên 3 triển khai kết nối API Backend.',
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
  // REUSABLE HELPER WIDGETS
  // =========================================================================
  Widget _buildSkeletonHeader({required String moduleTitle, required String memberTag, required String description}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A506B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                moduleTitle,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0072FF).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
                ),
                child: Text(
                  memberTag,
                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildKpiCardSkeleton(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A506B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildSampleListItem(String title, String subtitle, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3A506B)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF38BDF8), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
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
        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF3A506B)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
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
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF3A506B), style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: const Color(0xFF38BDF8).withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, height: 1.4),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF38BDF8)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(actionLabel, style: const TextStyle(color: Color(0xFF38BDF8))),
            ),
          ],
        ],
      ),
    );
  }
}

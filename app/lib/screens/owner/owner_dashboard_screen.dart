import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/table_provider.dart';
import '../auth/profile_screen.dart';
import 'owner_booking_screen.dart';
import 'owner_order_screen.dart';
import 'owner_table_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  void _loadDashboardData() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    String? branchId;
    if (user?.business != null) {
      final biz = user!.business!;
      if (biz['branches'] is List && (biz['branches'] as List).isNotEmpty) {
        final b = (biz['branches'] as List)[0];
        if (b is Map) branchId = (b['_id'] ?? b['id'])?.toString();
      }
      if (branchId == null && biz['primaryBranch'] is Map) {
        branchId = (biz['primaryBranch']['_id'] ?? biz['primaryBranch']['id'])?.toString();
      }
      branchId ??= (biz['_id'] ?? biz['id'])?.toString();
    }

    Provider.of<BookingProvider>(context, listen: false).fetchOwnerBookings();
    Provider.of<TableProvider>(context, listen: false).fetchTables(branchId: branchId);
    Provider.of<OrderProvider>(context, listen: false).fetchOwnerOrders();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final bookingProvider = Provider.of<BookingProvider>(context);
    final tableProvider = Provider.of<TableProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = authProvider.user;

    final businessName = user?.business?['name']?.toString() ?? 'FConnect Business';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Owner Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới dữ liệu',
            onPressed: _loadDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.person_rounded),
            tooltip: 'Hồ sơ',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadDashboardData(),
        color: const Color(0xFF0072FF),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Store Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0072FF).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF0072FF).withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.storefront_rounded, color: Color(0xFF38BDF8), size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            businessName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Chủ sở hữu: ${user?.fullName ?? "Chủ nhà hàng"}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Chỉ số tổng quan (Quick stats)
              const Text(
                'Tổng quan hôm nay',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatItem('Đặt bàn chờ duyệt', '${bookingProvider.pendingCount}', const Color(0xFFF59E0B), Icons.event_available_rounded),
                  const SizedBox(width: 12),
                  _buildStatItem('Đơn hàng cần làm', '${orderProvider.pendingOrdersCount + orderProvider.preparingOrdersCount}', const Color(0xFF0072FF), Icons.receipt_long_rounded),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatItem('Bàn đang trống', '${tableProvider.availableCount}/${tableProvider.totalTables}', const Color(0xFF10B981), Icons.table_restaurant_rounded),
                  const SizedBox(width: 12),
                  _buildStatItem('Tổng đơn hôm nay', '${orderProvider.todayOrdersCount}', const Color(0xFF8B5CF6), Icons.local_fire_department_rounded),
                ],
              ),
              const SizedBox(height: 28),

              // Menu quản lý chính (3 Module của Member 4)
              const Text(
                'Nghiệp vụ vận hành cửa hàng',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 14),

              // 1. Quản lý Đặt bàn
              _buildFeatureTile(
                title: 'Quản lý Đặt bàn (Booking)',
                subtitle: 'Xem danh sách khách đặt, xác nhận, xếp bàn & check-in',
                icon: Icons.calendar_month_rounded,
                accentColor: const Color(0xFF38BDF8),
                badgeText: bookingProvider.pendingCount > 0 ? '${bookingProvider.pendingCount} mới' : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OwnerBookingScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),

              // 2. Quản lý Bàn ăn
              _buildFeatureTile(
                title: 'Quản lý Bàn ăn (Table)',
                subtitle: 'Danh sách bàn, số người, trạng thái & thêm/sửa/xóa bàn',
                icon: Icons.table_restaurant_rounded,
                accentColor: const Color(0xFF10B981),
                badgeText: '${tableProvider.totalTables} bàn',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OwnerTableScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),

              // 3. Quản lý Đơn hàng
              _buildFeatureTile(
                title: 'Quản lý Đơn món (Order)',
                subtitle: 'Xác nhận đơn, chế biến, sẵn sàng, phục vụ & hoàn tất',
                icon: Icons.soup_kitchen_rounded,
                accentColor: const Color(0xFFF97316),
                badgeText: orderProvider.pendingOrdersCount > 0 ? '${orderProvider.pendingOrdersCount} chờ làm' : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OwnerOrderScreen()),
                  );
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.6)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accentColor, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badgeText != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

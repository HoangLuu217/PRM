import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/booking_model.dart';
import '../../../providers/booking_provider.dart';
import 'booking_detail_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabs = [
    'Tất cả',
    'Chờ xác nhận',
    'Đã xác nhận',
    'Hoàn thành',
    'Đã hủy'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BookingProvider>(context, listen: false).fetchMyBookings();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<BookingModel> _filterBookings(List<BookingModel> list, int tabIndex) {
    switch (tabIndex) {
      case 1:
        return list.where((b) => b.isPending).toList();
      case 2:
        return list.where((b) => b.isConfirmed || b.isCheckedIn).toList();
      case 3:
        return list.where((b) => b.isCompleted).toList();
      case 4:
        return list.where((b) => b.isCancelled || b.isRejected).toList();
      default:
        return list;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Lịch đặt bàn của tôi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF0072FF),
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          indicatorColor: const Color(0xFF0072FF),
          indicatorWeight: 3,
          tabs: _tabs.map((title) => Tab(text: title)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(_tabs.length, (tabIndex) {
          final filtered = _filterBookings(bookingProvider.myBookings, tabIndex);

          if (bookingProvider.isLoading && bookingProvider.myBookings.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0072FF)),
            );
          }

          if (filtered.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => bookingProvider.fetchMyBookings(),
              color: const Color(0xFF0072FF),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0072FF).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.table_restaurant_outlined, size: 40, color: Color(0xFF0072FF)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Chưa có đơn đặt bàn nào',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Khám phá nhà hàng và đặt bàn ngay hôm nay!',
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => bookingProvider.fetchMyBookings(),
            color: const Color(0xFF0072FF),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final booking = filtered[i];
                return _buildBookingCard(booking);
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBookingCard(BookingModel b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: b)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#${b.bookingCode}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: b.statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: b.statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        b.statusLabel,
                        style: TextStyle(color: b.statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Tên nhà hàng
                Text(
                  b.businessName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (b.branchAddress != null && b.branchAddress!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          b.branchAddress!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),

                // Chi tiết thời gian, số người & bàn
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF0072FF)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${b.startTime} • ${b.bookingDate}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.people_outline_rounded, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          '${b.guestCount} người',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ],
                ),

                if (b.canCustomerCancel) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => _showCancelDialog(b),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        ),
                        child: const Text('Hủy đặt bàn', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCancelDialog(BookingModel b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận hủy đặt bàn?'),
        content: Text('Bạn có chắc chắn muốn hủy đơn đặt bàn #${b.bookingCode} tại ${b.businessName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Không'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await Provider.of<BookingProvider>(context, listen: false).cancelBooking(b.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Đã hủy đặt bàn thành công' : 'Không thể hủy đặt bàn'),
                    backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Hủy đặt bàn'),
          ),
        ],
      ),
    );
  }
}

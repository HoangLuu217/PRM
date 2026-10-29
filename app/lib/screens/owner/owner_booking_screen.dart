import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/booking_model.dart';
import '../../../providers/booking_provider.dart';

class OwnerBookingScreen extends StatefulWidget {
  const OwnerBookingScreen({super.key});

  @override
  State<OwnerBookingScreen> createState() => _OwnerBookingScreenState();
}

class _OwnerBookingScreenState extends State<OwnerBookingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabs = [
    'Tất cả',
    'Chờ xác nhận',
    'Đã xác nhận',
    'Đã nhận bàn',
    'Hoàn tất',
    'Đã hủy / Từ chối'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookings();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadBookings() {
    Provider.of<BookingProvider>(context, listen: false).fetchOwnerBookings();
  }

  List<BookingModel> _filterBookings(List<BookingModel> list, int tabIndex) {
    switch (tabIndex) {
      case 1:
        return list.where((b) => b.isPending).toList();
      case 2:
        return list.where((b) => b.isConfirmed).toList();
      case 3:
        return list.where((b) => b.isCheckedIn).toList();
      case 4:
        return list.where((b) => b.isCompleted).toList();
      case 5:
        return list.where((b) => b.isCancelled || b.isRejected).toList();
      default:
        return list;
    }
  }

  void _updateStatusDirect(BookingModel b, String status, String actionTitle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$actionTitle?'),
        content: Text('Bạn có chắc chắn muốn thực hiện thao tác "$actionTitle" cho đơn đặt bàn #${b.bookingCode}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await Provider.of<BookingProvider>(context, listen: false)
                  .updateOwnerBookingStatus(b.id, status);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Thành công'),
                    backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'REJECTED' || status == 'CANCELLED' ? const Color(0xFFEF4444) : const Color(0xFF0072FF),
              foregroundColor: Colors.white,
            ),
            child: Text(actionTitle),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = Provider.of<BookingProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Quản lý Đặt bàn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF0072FF),
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
          indicatorColor: const Color(0xFF0072FF),
          indicatorWeight: 3,
          tabs: _tabs.map((title) => Tab(text: title)).toList(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: TabBarView(
            controller: _tabController,
            children: List.generate(_tabs.length, (tabIndex) {
              final filtered = _filterBookings(bookingProvider.ownerBookings, tabIndex);

              if (bookingProvider.isLoading && bookingProvider.ownerBookings.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF0072FF)));
              }

              if (filtered.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async => _loadBookings(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                      const Center(
                        child: Column(
                          children: [
                            Icon(Icons.event_note_outlined, size: 48, color: Color(0xFF94A3B8)),
                            SizedBox(height: 12),
                            Text('Không có đơn đặt bàn nào trong mục này',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _loadBookings(),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 850;
                    if (isDesktop) {
                      final rows = <Widget>[];
                      for (int i = 0; i < filtered.length; i += 2) {
                        final b1 = filtered[i];
                        final b2 = (i + 1 < filtered.length) ? filtered[i + 1] : null;
                        rows.add(
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: _buildOwnerBookingCard(b1)),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: b2 != null
                                        ? _buildOwnerBookingCard(b2)
                                        : const SizedBox(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      return ListView(
                        padding: const EdgeInsets.all(20),
                        children: rows,
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) => _buildOwnerBookingCard(filtered[i]),
                    );
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerBookingCard(BookingModel b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mã đặt bàn & Badge trạng thái
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                    child: Text('#${b.bookingCode}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155))),
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
                child: Text(b.statusLabel, style: TextStyle(color: b.statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tên khách hàng & SĐT
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF0072FF).withValues(alpha: 0.1),
                child: const Icon(Icons.person, color: Color(0xFF0072FF), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.userName ?? 'Khách đặt bàn', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                    if (b.userPhone != null && b.userPhone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('SĐT: ${b.userPhone}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Ngày, Giờ, Bàn & Số khách
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF0072FF)),
                    const SizedBox(width: 6),
                    Text('${b.startTime} • ${b.bookingDate}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B))),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.people_outline, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text('${b.guestCount} khách', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF475569))),
                ],
              ),
            ],
          ),

          if (b.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Ghi chú: ${b.note}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
          ],

          if (b.preOrder != null && b.preOrder!.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.restaurant_rounded, size: 14, color: Color(0xFF0072FF)),
                      const SizedBox(width: 6),
                      Text(
                        'Món đặt trước (${b.preOrder!.items.length} món) • ${b.preOrder!.total.toString().replaceAllMapped(RegExp(r'(\\d{1,3})(?=(\\d{3})+(?!\\d))'), (m) => '${m[1]}.')} đ',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E3A8A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    b.preOrder!.items.map((it) => '${it.quantity}x ${it.productName}').join(', '),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],

          // Nút thao tác của Owner
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (b.isPending) ...[
                OutlinedButton(
                  onPressed: () => _updateStatusDirect(b, 'REJECTED', 'Từ chối'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: const Text('Từ chối', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _updateStatusDirect(b, 'CONFIRMED', 'Xác nhận đặt bàn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0072FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                  child: const Text('Xác nhận & Xếp bàn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ] else if (b.isConfirmed) ...[
                OutlinedButton(
                  onPressed: () => _updateStatusDirect(b, 'CANCELLED', 'Hủy bàn'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: const Text('Hủy bàn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _updateStatusDirect(b, 'CHECKED_IN', 'Check-in nhận bàn'),
                  icon: const Icon(Icons.login_rounded, size: 16),
                  label: const Text('Khách nhận bàn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                ),
              ] else if (b.isCheckedIn) ...[
                ElevatedButton.icon(
                  onPressed: () => _updateStatusDirect(b, 'COMPLETED', 'Hoàn tất trả bàn'),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Hoàn tất trả bàn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

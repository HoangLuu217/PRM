import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/booking_model.dart';
import '../../../models/table_model.dart';
import '../../../providers/booking_provider.dart';
import '../../../providers/table_provider.dart';

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

  /// Modal xác nhận đặt bàn & gán/chọn bàn ăn
  void _showConfirmBookingDialog(BookingModel b) {
    final tableProvider = Provider.of<TableProvider>(context, listen: false);
    TableModel? selectedTable;

    // Tải danh sách bàn trống cho slot này
    tableProvider.fetchAvailableTables(
      branchId: b.branchId,
      bookingDate: b.bookingDate,
      startTime: b.startTime,
      guestCount: b.guestCount,
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final tables = tableProvider.availableTables;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF0072FF)),
                const SizedBox(width: 8),
                Text('Xác nhận #${b.bookingCode}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Khách: ${b.userName ?? "Khách hàng"} • ${b.guestCount} người', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Thời gian: ${b.startTime} • ${b.bookingDate}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  const SizedBox(height: 16),
                  const Text('Chọn bàn ăn cho khách:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  const SizedBox(height: 8),
                  if (tableProvider.isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                  else if (tables.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                      child: const Text('Không có bàn trống phù hợp, hoặc bàn đã được chỉ định tự động.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    )
                  else
                    ...tables.map((t) {
                      return RadioListTile<TableModel?>(
                        value: t,
                        groupValue: selectedTable,
                        onChanged: (val) => setDialogState(() => selectedTable = val),
                        title: Text('${t.name} (${t.capacity} chỗ)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text(t.location, style: const TextStyle(fontSize: 11)),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeColor: const Color(0xFF0072FF),
                      );
                    }),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final res = await Provider.of<BookingProvider>(context, listen: false)
                      .updateOwnerBookingStatus(
                    b.id,
                    'CONFIRMED',
                    tableId: selectedTable?.id ?? b.tableId,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res['message'] ?? 'Đã xác nhận đặt bàn'),
                        backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0072FF), foregroundColor: Colors.white),
                child: const Text('Xác nhận đặt bàn'),
              ),
            ],
          );
        },
      ),
    );
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
      body: TabBarView(
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
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.event_note_outlined, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        const Text('Không có đơn đặt bàn nào trong mục này', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _loadBookings(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final b = filtered[i];
                return _buildOwnerBookingCard(b);
              },
            ),
          );
        }),
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
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.table_restaurant, size: 15, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              Text(
                b.tableName != null ? 'Bàn: ${b.tableName}' : 'Chưa gán bàn cụ thể',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: b.tableName != null ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
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
                        'Món khách đặt trước (${b.preOrder!.items.length} món - ${b.preOrder!.total.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ):',
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
                  onPressed: () => _showConfirmBookingDialog(b),
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

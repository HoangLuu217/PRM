import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/order_model.dart';
import '../../../providers/order_provider.dart';

class OwnerOrderScreen extends StatefulWidget {
  const OwnerOrderScreen({super.key});

  @override
  State<OwnerOrderScreen> createState() => _OwnerOrderScreenState();
}

class _OwnerOrderScreenState extends State<OwnerOrderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabs = [
    'Tất cả',
    'Chờ xác nhận',
    'Đang chuẩn bị',
    'Sẵn sàng lên món',
    'Đã phục vụ',
    'Hoàn tất',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadOrders() {
    Provider.of<OrderProvider>(context, listen: false).fetchOwnerOrders();
  }

  List<OrderModel> _filterOrders(List<OrderModel> list, int tabIndex) {
    switch (tabIndex) {
      case 1:
        return list.where((o) => o.isPending).toList();
      case 2:
        return list.where((o) => o.isConfirmed || o.isPreparing).toList();
      case 3:
        return list.where((o) => o.isReady).toList();
      case 4:
        return list.where((o) => o.isServed).toList();
      case 5:
        return list.where((o) => o.isCompleted).toList();
      default:
        return list;
    }
  }

  String _formatPrice(int amount) {
    return '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ';
  }

  void _progressOrderStatus(OrderModel o, String nextStatus, String actionTitle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$actionTitle?'),
        content: Text('Xác nhận chuyển trạng thái đơn #${o.orderCode} sang "$actionTitle"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await Provider.of<OrderProvider>(context, listen: false)
                  .updateOrderStatus(o.id, nextStatus);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Cập nhật thành công!'),
                    backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: nextStatus == 'CANCELLED' ? const Color(0xFFEF4444) : const Color(0xFF0072FF),
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
    final orderProvider = Provider.of<OrderProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Quản lý Đơn hàng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
          final filtered = _filterOrders(orderProvider.ownerOrders, tabIndex);

          if (orderProvider.isLoading && orderProvider.ownerOrders.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF0072FF)));
          }

          if (filtered.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _loadOrders(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        const Text('Không có đơn hàng nào trong mục này', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _loadOrders(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final order = filtered[i];
                return _buildOwnerOrderCard(order);
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOwnerOrderCard(OrderModel o) {
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
          // Mã đơn & Loại đơn & Badge trạng thái
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                    child: Text('#${o.orderCode}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155))),
                  ),
                  const SizedBox(width: 8),
                  Text(o.orderTypeLabel, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: o.statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: o.statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(o.statusLabel, style: TextStyle(color: o.statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tên khách hàng & Bàn
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.userName ?? 'Khách đặt món', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                    if (o.userPhone != null && o.userPhone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('SĐT: ${o.userPhone}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                    ],
                  ],
                ),
              ),
              if (o.tableName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.table_restaurant, size: 14, color: Color(0xFF0072FF)),
                      const SizedBox(width: 4),
                      Text('Bàn ${o.tableName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0072FF))),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Danh sách món ăn
          ...o.items.map((it) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                    child: Text('${it.quantity}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0072FF))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      it.productName + (it.sizeName != null ? ' (${it.sizeName})' : ''),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                    ),
                  ),
                  Text(_formatPrice(it.subtotal), style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // Tổng tiền
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tổng hóa đơn:', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              Text(_formatPrice(o.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0072FF))),
            ],
          ),
          if (o.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Ghi chú: ${o.note}', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic)),
          ],

          // Nút tiến độ theo flow: PENDING -> CONFIRMED -> PREPARING -> READY -> SERVED -> COMPLETED
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (o.isPending || o.isConfirmed) ...[
                OutlinedButton(
                  onPressed: () => _progressOrderStatus(o, 'CANCELLED', 'Hủy đơn'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: const Text('Hủy đơn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 8),
              ],
              if (o.nextOwnerStatus != null)
                ElevatedButton.icon(
                  onPressed: () => _progressOrderStatus(o, o.nextOwnerStatus!, o.nextOwnerStatusLabel!),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: Text(o.nextOwnerStatusLabel!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0072FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

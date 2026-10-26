import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/order_model.dart';
import '../../../providers/order_provider.dart';

class OrderTrackingScreen extends StatefulWidget {
  final OrderModel order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late OrderModel _currentOrder;
  bool _isRefreshing = false;

  final List<Map<String, dynamic>> _steps = [
    {
      'status': 'PENDING',
      'title': 'Đã gửi đơn hàng',
      'subtitle': 'Đơn hàng đã được tiếp nhận và chờ nhà hàng xác nhận',
      'icon': Icons.send_rounded,
    },
    {
      'status': 'CONFIRMED',
      'title': 'Nhà hàng đã xác nhận',
      'subtitle': 'Bếp đã tiếp nhận đơn và chuẩn bị nguyên liệu',
      'icon': Icons.check_circle_outline_rounded,
    },
    {
      'status': 'PREPARING',
      'title': 'Đang chế biến món ăn',
      'subtitle': 'Các đầu bếp đang tận tâm thực hiện món ngon cho bạn',
      'icon': Icons.outdoor_grill_rounded,
    },
    {
      'status': 'READY',
      'title': 'Món ăn đã sẵn sàng',
      'subtitle': 'Món ăn đã hoàn thiện và chuẩn bị mang lên bàn',
      'icon': Icons.room_service_rounded,
    },
    {
      'status': 'SERVED',
      'title': 'Đã phục vụ tại bàn',
      'subtitle': 'Món ăn đã được phục vụ trọn vẹn, chúc bạn ngon miệng!',
      'icon': Icons.restaurant_rounded,
    },
    {
      'status': 'COMPLETED',
      'title': 'Đơn hàng hoàn tất',
      'subtitle': 'Cảm ơn quý khách đã thưởng thức dịch vụ tại FConnect',
      'icon': Icons.celebration_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
  }

  Future<void> _refreshStatus() async {
    setState(() => _isRefreshing = true);
    final fresh = await Provider.of<OrderProvider>(context, listen: false)
        .getOrderById(_currentOrder.id);
    if (mounted) {
      setState(() {
        if (fresh != null) _currentOrder = fresh;
        _isRefreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _currentOrder.trackingStepIndex;
    final isCancelled = _currentOrder.isCancelled;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Theo dõi đơn hàng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0072FF)),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới tiến trình',
            onPressed: _isRefreshing ? null : _refreshStatus,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Thẻ Tiêu đề tiến trình
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0072FF).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'MÃ ĐƠN: #${_currentOrder.orderCode}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _currentOrder.statusLabel,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentOrder.businessName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currentOrder.tableName != null
                        ? 'Phục vụ tại: Bàn ${_currentOrder.tableName}'
                        : 'Loại đơn: ${_currentOrder.orderTypeLabel}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Nếu đơn bị hủy
            if (isCancelled)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 32),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Đơn hàng đã bị hủy', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B), fontSize: 15)),
                          SizedBox(height: 4),
                          Text('Đơn hàng này không còn tiếp tục thực hiện nữa.', style: TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              // Vertical Stepper
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: List.generate(_steps.length, (idx) {
                    final step = _steps[idx];
                    final isDone = idx <= currentStep;
                    final isCurrent = idx == currentStep;
                    final isLast = idx == _steps.length - 1;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cột Icon và Đường kẻ
                        Column(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCurrent
                                    ? const Color(0xFF0072FF)
                                    : isDone
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFE2E8F0),
                                boxShadow: isCurrent
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF0072FF).withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                step['icon'] as IconData,
                                color: isDone ? Colors.white : const Color(0xFF94A3B8),
                                size: 18,
                              ),
                            ),
                            if (!isLast)
                              Container(
                                width: 2,
                                height: 42,
                                color: isDone && idx < currentStep
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFE2E8F0),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),

                        // Cột Nội dung
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        step['title'] as String,
                                        style: TextStyle(
                                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                          fontSize: 14.5,
                                          color: isCurrent
                                              ? const Color(0xFF0072FF)
                                              : isDone
                                                  ? const Color(0xFF0F172A)
                                                  : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                    if (isCurrent)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0072FF).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Text(
                                          'Hiện tại',
                                          style: TextStyle(
                                            color: Color(0xFF0072FF),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  step['subtitle'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDone ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

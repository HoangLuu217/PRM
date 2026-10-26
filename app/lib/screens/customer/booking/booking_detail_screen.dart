import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../models/booking_model.dart';
import '../../../models/order_model.dart';
import '../../../providers/booking_provider.dart';
import '../../../services/booking_service.dart';
import '../../../services/order_service.dart';

class BookingDetailScreen extends StatefulWidget {
  final BookingModel booking;

  const BookingDetailScreen({super.key, required this.booking});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late BookingModel _booking;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _refreshBooking();
  }

  Future<void> _refreshBooking() async {
    try {
      final fresh = await BookingService().getBookingById(_booking.id);
      if (fresh != null && mounted) {
        setState(() {
          _booking = fresh;
        });
      }
    } catch (_) {}
  }

  String _formatCurrency(int amount) {
    return '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ';
  }

  @override
  Widget build(BuildContext context) {
    final canAddDishes = _booking.status == 'PENDING' || _booking.status == 'CONFIRMED';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Chi tiết đặt bàn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: () async {
              setState(() => _isLoading = true);
              await _refreshBooking();
              if (mounted) setState(() => _isLoading = false);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0072FF)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Thẻ vé đặt bàn (Booking Ticket)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Phần trên của vé
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('FConnect Booking Pass', style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 0.5)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _booking.statusLabel,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _booking.businessName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'MÃ: #${_booking.bookingCode}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
                              ),
                            ],
                          ),
                        ),

                        // Đường răng cưa vé
                        Row(
                          children: List.generate(
                            20,
                            (i) => Expanded(
                              child: Container(
                                height: 2,
                                color: i % 2 == 0 ? const Color(0xFFCBD5E1) : Colors.transparent,
                              ),
                            ),
                          ),
                        ),

                        // Phần dưới của vé
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _buildInfoRow('Ngày dùng bữa', _booking.bookingDate, Icons.calendar_month_rounded),
                              const Divider(height: 24, color: Color(0xFFF1F5F9)),
                              _buildInfoRow('Khung giờ', _booking.startTime, Icons.access_time_rounded),
                              const Divider(height: 24, color: Color(0xFFF1F5F9)),
                              _buildInfoRow('Số lượng khách', '${_booking.guestCount} người', Icons.people_alt_rounded),
                              const Divider(height: 24, color: Color(0xFFF1F5F9)),
                              _buildInfoRow('Bàn ăn đã chọn', _booking.tableName ?? 'Nhà hàng tự sắp xếp', Icons.table_restaurant_rounded),
                              if (_booking.branchAddress != null && _booking.branchAddress!.isNotEmpty) ...[
                                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                                _buildInfoRow('Địa chỉ cơ sở', _booking.branchAddress!, Icons.location_on_rounded),
                              ],
                              if (_booking.note.isNotEmpty) ...[
                                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                                _buildInfoRow('Ghi chú thực khách', _booking.note, Icons.note_alt_rounded),
                              ],

                              // Danh sách món ăn đã đặt trước (nếu có)
                              if (_booking.preOrder != null && _booking.preOrder!.items.isNotEmpty) ...[
                                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                                _buildPreOrderSection(_booking.preOrder!),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nút Chọn thêm món vào đơn đặt bàn này (Dành cho booking cũ)
                  if (canAddDishes) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => _openAddDishesModal(context),
                        icon: const Icon(Icons.restaurant_menu_rounded, size: 20),
                        label: Text(
                          _booking.preOrder != null ? 'Chọn thêm món vào đơn đặt bàn' : 'Đặt món trước cho bàn này',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0072FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Nút hủy đặt bàn
                  if (_booking.canCustomerCancel)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => _handleCancel(context),
                        icon: const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444)),
                        label: const Text('Hủy đặt bàn', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0072FF)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreOrderSection(OrderModel preOrder) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.restaurant_rounded, size: 18, color: Color(0xFF0072FF)),
                  SizedBox(width: 8),
                  Text(
                    'Thực đơn đặt trước',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  preOrder.statusLabel,
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...preOrder.items.map((it) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${it.productName}  x${it.quantity}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    _formatCurrency(it.subtotal),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 18, color: Color(0xFFCBD5E1)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tổng tiền món:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B))),
              Text(
                _formatCurrency(preOrder.total),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0072FF)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Modal Chọn thêm món từ thực đơn vào booking cũ
  void _openAddDishesModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddDishesModalSheet(
        booking: _booking,
        onDishesAdded: () {
          _refreshBooking();
        },
      ),
    );
  }

  void _handleCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hủy đặt bàn?'),
        content: const Text('Bạn có chắc chắn muốn hủy đặt bàn này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Không')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await Provider.of<BookingProvider>(context, listen: false).cancelBooking(_booking.id);
              if (context.mounted) {
                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã hủy đặt bàn'), backgroundColor: Color(0xFF10B981)),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Không thể hủy đặt bàn'), backgroundColor: Color(0xFFEF4444)),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );
  }
}

class _AddDishesModalSheet extends StatefulWidget {
  final BookingModel booking;
  final VoidCallback onDishesAdded;

  const _AddDishesModalSheet({
    required this.booking,
    required this.onDishesAdded,
  });

  @override
  State<_AddDishesModalSheet> createState() => _AddDishesModalSheetState();
}

class _AddDishesModalSheetState extends State<_AddDishesModalSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _products = [];
  final Map<String, int> _selectedQuantities = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/products?businessId=${widget.booking.businessId}');
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['data'] as List<dynamic>?) ?? [];
        if (mounted) {
          setState(() {
            _products = list.map((e) => e as Map<String, dynamic>).toList();
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  int get _totalAmount {
    int sum = 0;
    for (final p in _products) {
      final id = (p['_id'] ?? p['id'] ?? '').toString();
      final qty = _selectedQuantities[id] ?? 0;
      final price = (p['price'] as num?)?.toInt() ?? 0;
      sum += price * qty;
    }
    return sum;
  }

  int get _totalCount {
    int sum = 0;
    for (final q in _selectedQuantities.values) {
      sum += q;
    }
    return sum;
  }

  String _formatCurrency(int amount) {
    return '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ';
  }

  Future<void> _submitAddDishes() async {
    if (_totalCount == 0) return;

    setState(() => _isSubmitting = true);

    final List<Map<String, dynamic>> orderItems = [];
    for (final p in _products) {
      final id = (p['_id'] ?? p['id'] ?? '').toString();
      final qty = _selectedQuantities[id] ?? 0;
      if (qty > 0) {
        orderItems.add({
          'productId': id,
          'quantity': qty,
          'selectedOptions': [],
        });
      }
    }

    final res = await OrderService().createOrder(
      businessId: widget.booking.businessId,
      branchId: widget.booking.branchId,
      bookingId: widget.booking.id,
      tableId: widget.booking.tableId,
      items: orderItems,
      note: 'Thực khách chọn thêm món cho đơn #${widget.booking.bookingCode}',
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      widget.onDishesAdded();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Đã thêm món vào đơn đặt bàn thành công!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Thêm món thất bại'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding + 16),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              const Icon(Icons.restaurant_menu_rounded, color: Color(0xFF0072FF), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chọn thêm món - ${widget.booking.businessName}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Text(
            'Chọn các món yêu thích để nhà hàng chuẩn bị sẵn trước khi bạn đến:',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),

          // Danh sách món
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0072FF)))
                : _products.isEmpty
                    ? const Center(
                        child: Text('Thực đơn chưa có món khả dụng.', style: TextStyle(color: Color(0xFF64748B))),
                      )
                    : ListView.separated(
                        itemCount: _products.length,
                        separatorBuilder: (context, index) => const Divider(height: 16, color: Color(0xFFF8FAFC)),
                        itemBuilder: (ctx, idx) {
                          final prod = _products[idx];
                          final id = (prod['_id'] ?? prod['id'] ?? '').toString();
                          final name = prod['name']?.toString() ?? 'Món ăn';
                          final price = (prod['price'] as num?)?.toInt() ?? 0;
                          final img = prod['imageUrl']?.toString();
                          final desc = prod['description']?.toString() ?? '';
                          final qty = _selectedQuantities[id] ?? 0;

                          return Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  img ?? 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=200&q=80',
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 60,
                                    height: 60,
                                    color: const Color(0xFFF1F5F9),
                                    child: const Icon(Icons.fastfood_rounded, color: Color(0xFF94A3B8), size: 28),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                    ),
                                    if (desc.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        desc,
                                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatCurrency(price),
                                      style: const TextStyle(color: Color(0xFF0072FF), fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  if (qty > 0) ...[
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          if (qty > 1) {
                                            _selectedQuantities[id] = qty - 1;
                                          } else {
                                            _selectedQuantities.remove(id);
                                          }
                                        });
                                      },
                                      icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444), size: 22),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(
                                        '$qty',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                  ],
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedQuantities[id] = qty + 1;
                                      });
                                    },
                                    icon: const Icon(Icons.add_circle, color: Color(0xFF0072FF), size: 24),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
          ),
          const SizedBox(height: 12),

          // Thanh Bottom xác nhận
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Đã chọn: $_totalCount món', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text(
                      _formatCurrency(_totalAmount),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0072FF)),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: (_totalCount > 0 && !_isSubmitting) ? _submitAddDishes : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0072FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Thêm vào đặt bàn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

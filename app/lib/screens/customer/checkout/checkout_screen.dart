import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/order_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/checkout_service.dart';
import '../../../widgets/price_summary.dart';
import '../customer_home_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _noteController = TextEditingController();
  final CheckoutService _checkoutService = CheckoutService();

  String _selectedOrderType = 'PRE_ORDER';
  String _selectedPaymentMethod = 'PAYOS_QR';
  bool _isSubmitting = false;

  final Map<String, String> _orderTypeLabels = {
    'PRE_ORDER': 'Đặt món trước (Pre-order)',
    'DINE_IN': 'Ăn tại quán (Dine-in)',
    'PICKUP': 'Tự đến lấy (Pickup)',
    'DELIVERY': 'Giao hàng (Delivery)',
  };

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': 'PAYOS_QR',
      'title': 'Chuyển khoản VietQR / PayOS',
      'subtitle': 'Quét mã QR tự động xác nhận trong 3 giây',
      'icon': Icons.qr_code_scanner_rounded,
      'color': Color(0xFF0072FF),
      'badge': 'Khuyên dùng',
    },
    {
      'id': 'MOMO',
      'title': 'Ví MoMo',
      'subtitle': 'Thanh toán tức thì qua ví điện tử MoMo',
      'icon': Icons.account_balance_wallet_rounded,
      'color': Color(0xFFA50064),
      'badge': null,
    },
    {
      'id': 'CARD',
      'title': 'Thẻ Quốc tế / ATM Nội địa',
      'subtitle': 'Hỗ trợ thẻ Visa, Mastercard, JCB & thẻ Napas',
      'icon': Icons.credit_card_rounded,
      'color': Color(0xFF2563EB),
      'badge': null,
    },
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    if (_isSubmitting) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    if (cartProvider.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giỏ hàng trống!')),
      );
      return;
    }

    if (authProvider.token == null || authProvider.token!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để tiến hành đặt hàng')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final payload = {
        'businessId': cartProvider.businessId,
        if (cartProvider.branchId != null) 'branchId': cartProvider.branchId,
        'orderType': _selectedOrderType,
        'paymentMethod': _selectedPaymentMethod,
        'note': _noteController.text.trim(),
        'items': cartProvider.items.map((item) => item.toJson()).toList(),
      };

      final order = await _checkoutService.createOrder(payload, authProvider.token!);

      // Clear cart on backend & local
      cartProvider.clearCart(token: authProvider.token);

      if (!mounted) return;

      if (_selectedPaymentMethod == 'PAYOS_QR') {
        _showPayOSQRModal(order);
      } else if (_selectedPaymentMethod == 'MOMO') {
        _showMoMoPaymentModal(order);
      } else if (_selectedPaymentMethod == 'CARD') {
        _showCardPaymentModal(order);
      } else {
        _showSuccessDialog(order.orderCode, paymentTitle: 'Tiền mặt khi nhận món');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đặt hàng thất bại: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// Modal Thanh toán Chuyển khoản VietQR / PayOS
  void _showPayOSQRModal(OrderModel order) {
    final amount = order.total > 0 ? order.total : 50000;
    final orderCode = order.orderCode;
    // Thay đổi thông tin ngân hàng thực tế từ backend PayOS Service (MBBank: 1021072004 - LUONG DANG HOANG LUU)
    final qrUrl =
        'https://api.vietqr.io/image/970422-1021072004-compact2.jpg?amount=$amount&addInfo=${Uri.encodeComponent("COC BAN $orderCode")}&accountName=${Uri.encodeComponent("LUONG DANG HOANG LUU")}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_2_rounded, color: Color(0xFF0072FF), size: 28),
                  const SizedBox(width: 8),
                  const Text(
                    'Thanh toán qua VietQR / PayOS',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Mở App Ngân hàng bất kỳ để quét mã thanh toán',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),

              // QR Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        qrUrl,
                        width: 210,
                        height: 210,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, prog) => prog == null
                            ? child
                            : const SizedBox(
                                width: 210,
                                height: 210,
                                child: Center(child: CircularProgressIndicator()),
                              ),
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 210,
                          height: 210,
                          color: Colors.grey[100],
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_rounded, size: 80, color: Color(0xFF0072FF)),
                              Text('VietQR Gateway', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Số tiền: ${_formatPrice(amount.toDouble())}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0072FF)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Bank info breakdown
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildCopyableRow('Ngân hàng:', 'MBBank (Quân Đội)', 'MBBank'),
                    const Divider(height: 12),
                    _buildCopyableRow('Số tài khoản:', '1021072004', '1021072004'),
                    const Divider(height: 12),
                    _buildCopyableRow('Chủ tài khoản:', 'LUONG DANG HOANG LUU', 'LUONG DANG HOANG LUU'),
                    const Divider(height: 12),
                    _buildCopyableRow('Nội dung CK:', 'COC BAN $orderCode', 'COC BAN $orderCode'),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Confirm button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Tắt Modal Bottom Sheet
                    Navigator.pop(ctx);
                    
                    // Xóa hết back stack hiện tại (về Trang chủ CustomerHomeScreen) và hiện hộp thoại thành công
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => CustomerHomeScreen()),
                      (route) => false,
                    );
                    
                    // (Tùy chọn) Hiện thông báo nhẹ
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đơn hàng đã thanh toán thành công và chuyển đến nhà bếp!'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                  label: const Text(
                    'Tôi đã chuyển khoản xong',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0072FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Modal Thanh toán MoMo
  void _showMoMoPaymentModal(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFA50064), size: 48),
            const SizedBox(height: 12),
            const Text('Thanh toán ví MoMo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Số tiền thanh toán: ${_formatPrice(order.total.toDouble())}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFA50064)),
            ),
            const SizedBox(height: 16),
            const Text('Chuyển tiếp đến ứng dụng MoMo để hoàn tất thanh toán.', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA50064),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showSuccessDialog(order.orderCode, paymentTitle: 'Ví MoMo');
                },
                child: const Text('Xác nhận thanh toán MoMo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Modal Thanh toán Thẻ Ngân hàng / Visa
  void _showCardPaymentModal(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.credit_card_rounded, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Text('Thanh toán Thẻ Quốc tế / ATM', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Số thẻ',
                  hintText: '4111 2222 3333 4444',
                  prefixIcon: Icon(Icons.payment_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Hạn dùng (MM/YY)',
                        hintText: '12/28',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'CVV/CVC',
                        hintText: '123',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showSuccessDialog(order.orderCode, paymentTitle: 'Thẻ Quốc tế / ATM');
                  },
                  child: Text('Thanh toán ${_formatPrice(order.total.toDouble())}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCopyableRow(String label, String value, String copyValue) {
    return Row(
      children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)))),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: copyValue));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Đã sao chép: $copyValue'), duration: const Duration(seconds: 1)),
            );
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Icon(Icons.copy_rounded, size: 16, color: Color(0xFF0072FF)),
          ),
        ),
      ],
    );
  }

  void _showSuccessDialog(String orderCode, {String paymentTitle = 'Thành công'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF10B981), size: 64),
            SizedBox(height: 12),
            Text(
              'Đặt món & Thanh toán!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                'Mã đơn: #$orderCode',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 15),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Hình thức: $paymentTitle\nĐơn hàng đã được chuyển ngay cho nhà bếp chuẩn bị.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text('Về trang chủ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    final intPrice = price.toInt();
    return '${intPrice.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')}đ';
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Xác nhận & Thanh toán', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      body: cartProvider.isEmpty
          ? const Center(child: Text('Không có sản phẩm trong giỏ hàng'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Restaurant Name Banner
                  if (cartProvider.businessName != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.storefront_rounded, color: Color(0xFF2563EB), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Địa điểm phục vụ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                Text(
                                  cartProvider.businessName!,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 1. Order Type Selection
                  const Text('1. Hình thức nhận món', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: _orderTypeLabels.entries.map((entry) {
                        return Material(
                          color: Colors.transparent,
                          child: RadioListTile<String>(
                            title: Text(entry.value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            value: entry.key,
                            groupValue: _selectedOrderType,
                            activeColor: const Color(0xFF2563EB),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedOrderType = val);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 2. Selected Items Summary
                  const Text('2. Món ăn đã chọn', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cartProvider.items.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (ctx, idx) {
                        final item = cartProvider.items[idx];
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            title: Text('${item.quantity}x ${item.product.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: item.selectedSize != null || item.selectedOptions.isNotEmpty
                                ? Text(
                                    'Size: ${item.selectedSize?.name ?? "Chuẩn"}${item.selectedOptions.isNotEmpty ? ", ${item.selectedOptions.map((o) => o.value).join(', ')}" : ""}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  )
                                : null,
                            trailing: Text(
                              _formatPrice(item.itemSubtotal),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. Note Field
                  const Text('3. Ghi chú cho quán', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Ví dụ: Ít đường, không đá, mang thêm tương ớt...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Price Summary
                  PriceSummary(
                    subtotal: cartProvider.subtotal,
                    total: cartProvider.subtotal,
                  ),
                  const SizedBox(height: 24),

                  // Confirm and Pay Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Xác nhận & Thanh toán • ${_formatPrice(cartProvider.subtotal)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/checkout_service.dart';
import '../../../widgets/price_summary.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _noteController = TextEditingController();
  final CheckoutService _checkoutService = CheckoutService();

  String _selectedOrderType = 'PRE_ORDER';
  bool _isSubmitting = false;

  final Map<String, String> _orderTypeLabels = {
    'PRE_ORDER': 'Đặt món trước (Pre-order)',
    'DINE_IN': 'Ăn tại quán (Dine-in)',
    'PICKUP': 'Tự đến lấy (Pickup)',
    'DELIVERY': 'Giao hàng (Delivery)',
  };

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
        'branchId': cartProvider.branchId ?? cartProvider.businessId,
        'orderType': _selectedOrderType,
        'note': _noteController.text.trim(),
        'items': cartProvider.items.map((item) => item.toJson()).toList(),
      };

      final order = await _checkoutService.createOrder(payload, authProvider.token!);

      // Clear cart on backend & local
      cartProvider.clearCart(token: authProvider.token);

      if (mounted) {
        _showSuccessDialog(order.orderCode);
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

  void _showSuccessDialog(String orderCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 12),
            const Text(
              'Đặt hàng thành công!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: Text(
          'Mã đơn hàng của bạn là #$orderCode.\nCảm ơn bạn đã sử dụng FConnect!',
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx); // Close dialog
                Navigator.popUntil(context, (route) => route.isFirst); // Go to main screen
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
      appBar: AppBar(
        title: const Text('Xác nhận Đặt hàng', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: cartProvider.isEmpty
          ? const Center(child: Text('Không có sản phẩm trong giỏ hàng'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Restaurant Name
                  if (cartProvider.businessName != null) ...[
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            const Icon(Icons.storefront, color: Colors.deepOrange, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                cartProvider.businessName!,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Order Type Selection
                  const Text(
                    'Hình thức phục vụ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: _orderTypeLabels.entries.map((entry) {
                        return RadioListTile<String>(
                          title: Text(entry.value),
                          value: entry.key,
                          groupValue: _selectedOrderType,
                          activeColor: Colors.deepOrange,
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedOrderType = val;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Selected Items Summary
                  const Text(
                    'Tóm tắt món ăn',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cartProvider.items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final item = cartProvider.items[idx];
                        return ListTile(
                          title: Text('${item.quantity}x ${item.product.name}'),
                          subtitle: item.selectedSize != null || item.selectedOptions.isNotEmpty
                              ? Text(
                                  'Size: ${item.selectedSize?.name ?? "Chuẩn"}${item.selectedOptions.isNotEmpty ? ", ${item.selectedOptions.map((o) => o.value).join(', ')}" : ""}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                )
                              : null,
                          trailing: Text(
                            _formatPrice(item.itemSubtotal),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Note Field
                  const Text(
                    'Ghi chú cho quán',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: Ít đường, không cay, lấy thêm muỗng nĩa...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Price Summary
                  PriceSummary(
                    subtotal: cartProvider.subtotal,
                    total: cartProvider.subtotal,
                  ),
                  const SizedBox(height: 24),

                  // Confirm Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Xác nhận Đặt hàng - ${_formatPrice(cartProvider.subtotal)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

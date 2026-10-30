import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/order_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/booking_service.dart';
import '../../../services/checkout_service.dart';
import '../../../widgets/cart_item_tile.dart';
import '../checkout/checkout_screen.dart';
import '../order/my_orders_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CheckoutService _checkoutService = CheckoutService();
  final BookingService _bookingService = BookingService();
  final Set<String> _preparingBusinesses = {};

  Timer? _countdownTimer;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preparePendingOrdersAndQr();
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkPendingPayments();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _preparePendingOrdersAndQr() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null || token.isEmpty) return;

    final groups = cartProvider.groups;
    for (final group in groups) {
      final busId = group.businessId;
      if (_preparingBusinesses.contains(busId)) continue;

      OrderModel? pendingOrder = cartProvider.getPendingOrderForBusiness(busId);
      Map<String, String>? qrDetails = cartProvider.getPendingQrDetailsForBusiness(busId);

      if (pendingOrder != null && qrDetails != null) continue;

      _preparingBusinesses.add(busId);
      try {
        // 1. Nếu chưa có order chờ thanh toán trong RAM, tìm đơn PENDING mới tạo trong 15p hoặc tự khởi tạo từ Booking
        if (pendingOrder == null) {
          final myOrders = await _checkoutService.getMyOrders(token);
          for (final ord in myOrders) {
            final ageSec = ord.createdAt != null
                ? DateTime.now().difference(ord.createdAt!).inSeconds
                : 999999;
            if (ord.businessId == busId &&
                ord.paymentStatus.toUpperCase() == 'PENDING' &&
                ageSec < 15 * 60) {
              pendingOrder = ord;
              break;
            }
          }
        }

        if (pendingOrder == null) {
          final myBookings = await _bookingService.getMyBookings();
          final validBookings = myBookings.where((b) {
            return b.businessId == busId && (b.isPending || b.isConfirmed || b.isCheckedIn);
          }).toList();

          if (validBookings.isNotEmpty) {
            final activeBooking = validBookings.first;
            final payload = <String, dynamic>{
              'businessId': busId,
              'bookingId': activeBooking.id,
              'orderType': 'PRE_ORDER',
              'paymentMethod': 'PAYOS_QR',
              'note': '',
              'items': group.items.map((item) => item.toJson()).toList(),
            };
            if (group.branchId != null && group.branchId!.isNotEmpty) {
              payload['branchId'] = group.branchId;
            } else if (activeBooking.branchId.isNotEmpty) {
              payload['branchId'] = activeBooking.branchId;
            }
            if (activeBooking.tableId != null && activeBooking.tableId!.isNotEmpty) {
              payload['tableId'] = activeBooking.tableId;
            }
            pendingOrder = await _checkoutService.createOrder(payload, token);
          }
        }

        if (pendingOrder != null) {
          final amount = pendingOrder.total > 0 ? pendingOrder.total : group.subtotal.toInt();
          final memo = 'DAT MON ${pendingOrder.orderCode}';
          final payosData = await _checkoutService.createPayOSPaymentRequest(
            orderCode: pendingOrder.orderCode,
            amount: amount,
            description: memo,
          );
          final accNo = (payosData['accountNumber'] != null &&
                  payosData['accountNumber'] != '1021072004' &&
                  payosData['accountNumber']!.isNotEmpty)
              ? payosData['accountNumber']!
              : '0776101860';
          final accName = (payosData['accountName'] != null && payosData['accountName']!.isNotEmpty)
              ? payosData['accountName']!
              : 'DANG THANH TUNG';
          final desc = payosData['description'] ?? memo;
          final qrUrl =
              'https://img.vietqr.io/image/970422-$accNo-compact2.jpg?amount=$amount&addInfo=${Uri.encodeComponent(desc)}&accountName=${Uri.encodeComponent(accName)}';

          if (mounted) {
            cartProvider.setPendingOrderForBusiness(
              busId,
              pendingOrder,
              qrDetails: {
                'qrUrl': qrUrl,
                'accountNumber': accNo,
                'accountName': accName,
                'description': desc,
              },
            );
          }
        }
      } catch (_) {
      } finally {
        _preparingBusinesses.remove(busId);
      }
    }
  }

  Future<void> _checkPendingPayments() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null || token.isEmpty) return;

    for (final group in cartProvider.groups) {
      final pendingOrder = cartProvider.getPendingOrderForBusiness(group.businessId);
      if (pendingOrder == null) continue;

      final isPaid = await _checkoutService.checkPaymentStatus(pendingOrder.orderCode, token);
      if (isPaid && mounted) {
        _pollTimer?.cancel();
        _countdownTimer?.cancel();
        cartProvider.clearCartForBusiness(group.businessId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chuyển khoản thành công! Đơn hàng #${pendingOrder.orderCode} đã được xác nhận 🎉'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
        );
        return;
      }
    }
  }

  String _formatCurrency(double amount) {
    return '${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ';
  }

  Widget _buildCopyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã sao chép: $value'), duration: const Duration(seconds: 1)),
                  );
                },
                child: const Icon(Icons.copy_rounded, size: 15, color: Color(0xFF0072FF)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final groups = cartProvider.groups;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Giỏ hàng của bạn',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (groups.isNotEmpty)
              Text(
                '${groups.length} nhà hàng • ${cartProvider.totalQuantity} món',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          if (!cartProvider.isEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Xóa toàn bộ giỏ hàng',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Xóa giỏ hàng?'),
                    content: const Text('Bạn có chắc chắn muốn xóa toàn bộ sản phẩm trong giỏ hàng không?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Hủy'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () {
                          cartProvider.clearCart();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Xóa tất cả', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: cartProvider.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'Giỏ hàng của bạn đang trống',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hãy chọn món ăn yêu thích từ các nhà hàng nhé!',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.restaurant_menu),
                    label: const Text('Khám phá thực đơn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0072FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: groups.length,
              itemBuilder: (ctx, groupIdx) {
                final group = groups[groupIdx];
                final pendingOrder = cartProvider.getPendingOrderForBusiness(group.businessId);
                final qrDetails = cartProvider.getPendingQrDetailsForBusiness(group.businessId);
                final remSec = cartProvider.getRemainingSecondsForBusiness(group.businessId);
                final minStr = (remSec ~/ 60).toString().padLeft(2, '0');
                final secStr = (remSec % 60).toString().padLeft(2, '0');

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Quán
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.storefront_rounded, color: Color(0xFF0072FF), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.businessName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (pendingOrder != null)
                                    Text(
                                      'Mã đơn chờ thanh toán: #${pendingOrder.orderCode}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFFD97706),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0072FF).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${group.totalQuantity} món',
                                style: const TextStyle(
                                  color: Color(0xFF0072FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                              tooltip: 'Xóa giỏ hàng quán này',
                              onPressed: () {
                                cartProvider.clearCartForBusiness(group.businessId);
                              },
                            ),
                          ],
                        ),
                      ),

                      // Danh sách món ăn của quán này
                      ...group.items.map((item) {
                        final globalIdx = cartProvider.items.indexOf(item);
                        return CartItemTile(
                          item: item,
                          onQuantityChanged: (newQty) {
                            if (globalIdx != -1) {
                              cartProvider.updateQuantity(globalIdx, newQty);
                            }
                          },
                          onRemove: () {
                            if (globalIdx != -1) {
                              cartProvider.removeItem(globalIdx);
                            }
                          },
                        );
                      }),

                      const Divider(height: 1, color: Color(0xFFE2E8F0)),

                      // Tạm tính, Mã QR Thanh toán lại & Nút Thanh toán
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Tổng thanh toán:',
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  _formatCurrency(group.subtotal),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0072FF)),
                                ),
                              ],
                            ),

                            // Hiển thị trực tiếp mã QR của đơn hàng để người dùng quét thanh toán lại ngay trong Giỏ hàng
                            if (pendingOrder != null && qrDetails != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.qr_code_2_rounded, color: Color(0xFF0072FF), size: 20),
                                            SizedBox(width: 6),
                                            Text(
                                              'Mã QR thanh toán đơn hàng',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13.5,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.timer_outlined, size: 13, color: Color(0xFF0072FF)),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$minStr:$secStr',
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0072FF),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        qrDetails['qrUrl']!,
                                        width: 190,
                                        height: 190,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) => const SizedBox(
                                          width: 190,
                                          height: 190,
                                          child: Center(
                                            child: Icon(Icons.qr_code_rounded, size: 70, color: Color(0xFF0072FF)),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Column(
                                        children: [
                                          _buildCopyRow('Ngân hàng:', 'MBBank (Quân Đội)'),
                                          _buildCopyRow('Số tài khoản:', qrDetails['accountNumber'] ?? '0776101860'),
                                          _buildCopyRow('Chủ tài khoản:', qrDetails['accountName'] ?? 'DANG THANH TUNG'),
                                          _buildCopyRow('Nội dung CK:', qrDetails['description'] ?? 'DAT MON ${pendingOrder.orderCode}'),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFFBEB),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFFDE68A)),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD97706)),
                                          ),
                                          SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              'Quét mã QR để thanh toán — Tự động xác nhận khi nhận tiền',
                                              style: TextStyle(
                                                color: Color(0xFFB45309),
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  cartProvider.setActiveBusiness(group.businessId, group.businessName, brId: group.branchId);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CheckoutScreen(autoShowQr: pendingOrder != null),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0072FF),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                                label: Text(
                                  pendingOrder != null
                                      ? 'Thanh toán lại đơn #${pendingOrder.orderCode}'
                                      : 'Thanh toán tại ${group.businessName}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

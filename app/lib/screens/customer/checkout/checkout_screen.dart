import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/booking_model.dart';
import '../../../models/order_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/booking_service.dart';
import '../../../services/checkout_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/restaurant_service.dart';
import '../../../widgets/price_summary.dart';
import '../customer_home_screen.dart';
import '../order/my_orders_screen.dart';
import '../widgets/restaurant_modals.dart';

class CheckoutScreen extends StatefulWidget {
  final bool autoShowQr;

  const CheckoutScreen({super.key, this.autoShowQr = false});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _noteController = TextEditingController();
  final CheckoutService _checkoutService = CheckoutService();
  final BookingService _bookingService = BookingService();
  final RestaurantService _restaurantService = RestaurantService();

  BookingModel? _activeBooking;
  bool _isLoadingBooking = true;

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
  void initState() {
    super.initState();
    _fetchActiveBooking();
  }

  Future<void> _fetchActiveBooking() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (cartProvider.businessId == null) {
      if (mounted) setState(() => _isLoadingBooking = false);
      return;
    }

    try {
      final pendingBooking = cartProvider.getPendingBookingForBusiness(cartProvider.businessId!);
      BookingModel? resolvedBooking = pendingBooking;
      if (resolvedBooking == null) {
        final myBookings = await _bookingService.getMyBookings();
        final validBookings = myBookings.where((b) {
          final matchesBusiness = b.businessId == cartProvider.businessId;
          final isValidStatus = b.isPending || b.isConfirmed || b.isCheckedIn;
          return matchesBusiness && isValidStatus;
        }).toList();
        resolvedBooking = validBookings.isNotEmpty ? validBookings.first : null;
      }

      if (mounted) {
        setState(() {
          _activeBooking = resolvedBooking;
          _isLoadingBooking = false;
        });
        if (widget.autoShowQr && _activeBooking != null) {
          final busId = cartProvider.businessId!;
          final pendingOrder = cartProvider.getPendingOrderForBusiness(busId);
          if (pendingOrder != null) {
            _showPayOSQRModal(pendingOrder, businessId: busId);
          } else {
            _submitOrder();
          }
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingBooking = false);
      }
    }
  }

  void _openBookingModal() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (cartProvider.businessId == null) return;

    try {
      final restaurants = await _restaurantService.getRestaurants(city: 'Tất cả');
      final restaurant = restaurants.firstWhere(
        (r) => r.id == cartProvider.businessId,
        orElse: () => restaurants.first,
      );

      if (mounted) {
        RestaurantModals.showBooking(context, restaurant, restaurantService: _restaurantService);
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) _fetchActiveBooking();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải thông tin đặt bàn: $e')),
        );
      }
    }
  }

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

    if (_activeBooking == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn bắt buộc phải đặt bàn tại quán trước khi tiến hành đặt món!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final checkoutItems = cartProvider.activeItems;

      final effectiveBusinessId = (cartProvider.businessId != null && cartProvider.businessId!.isNotEmpty)
          ? cartProvider.businessId!
          : _activeBooking!.businessId;

      final effectiveBranchId = (cartProvider.branchId != null && cartProvider.branchId!.isNotEmpty)
          ? cartProvider.branchId
          : (_activeBooking!.branchId != null && _activeBooking!.branchId!.isNotEmpty ? _activeBooking!.branchId : null);

      final payload = <String, dynamic>{
        'businessId': effectiveBusinessId,
        'bookingId': _activeBooking!.id,
        'orderType': _selectedOrderType,
        'paymentMethod': _selectedPaymentMethod,
        'note': _noteController.text.trim(),
        'items': checkoutItems.map((item) => item.toJson()).toList(),
      };

      if (effectiveBranchId != null && effectiveBranchId.isNotEmpty) {
        payload['branchId'] = effectiveBranchId;
      }
      if (_activeBooking!.tableId != null && _activeBooking!.tableId!.isNotEmpty) {
        payload['tableId'] = _activeBooking!.tableId;
      }

      OrderModel? existingPending = _selectedPaymentMethod == 'PAYOS_QR'
          ? cartProvider.getPendingOrderForBusiness(effectiveBusinessId)
          : null;

      final OrderModel order = existingPending ??
          await _checkoutService.createOrder(payload, authProvider.token!);

      if (_selectedPaymentMethod == 'PAYOS_QR') {
        // Giữ lại đơn hàng & giỏ hàng cho đến khi thanh toán QR thành công (để nếu người dùng Back lại vẫn thấy trong Giỏ hàng)
        cartProvider.setPendingOrderForBusiness(effectiveBusinessId, order);
      } else {
        if (cartProvider.businessId != null) {
          cartProvider.clearCartForBusiness(cartProvider.businessId!);
        } else {
          cartProvider.clearCart(token: authProvider.token);
        }
      }

      if (!mounted) return;

      if (_selectedPaymentMethod == 'PAYOS_QR') {
        await _showPayOSQRModal(order, businessId: effectiveBusinessId);
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

  /// Modal Thanh toán Chuyển khoản VietQR / PayOS (Kết nối trực tiếp cổng PayOS MBBank)
  Future<void> _showPayOSQRModal(OrderModel order, {String? businessId}) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final effectiveBusId = businessId ?? order.businessId;
    final cachedQr = effectiveBusId.isNotEmpty
        ? cartProvider.getPendingQrDetailsForBusiness(effectiveBusId)
        : null;

    final amount = order.total > 0 ? order.total : 2000;
    final orderCode = order.orderCode;
    final defaultMemo = 'DAT MON $orderCode';

    String qrUrl;
    String accNo;
    String accName;
    String memo;

    if (cachedQr != null && cachedQr['accountNumber'] != null && cachedQr['accountNumber']!.isNotEmpty) {
      accNo = cachedQr['accountNumber']!;
      accName = cachedQr['accountName'] ?? 'DANG THANH TUNG';
      memo = cachedQr['description'] ?? defaultMemo;
      qrUrl = CheckoutService.buildQrImageUrl(
        bin: '970422',
        accountNumber: accNo,
        amount: amount,
        description: memo,
      );
    } else if (order.payosAccountNo != null && order.payosAccountNo!.isNotEmpty && order.payosAccountNo != '1021072004') {
      accNo = order.payosAccountNo!;
      accName = order.payosAccountName ?? 'DANG THANH TUNG';
      final bin = order.payosBin ?? '970422';
      memo = defaultMemo;
      qrUrl = CheckoutService.buildQrImageUrl(
        rawEmvQrCode: order.payosQrUrl,
        bin: bin,
        accountNumber: accNo,
        amount: amount,
        description: memo,
      );
    } else {
      final payosData = await _checkoutService.createPayOSPaymentRequest(
        orderCode: orderCode,
        amount: amount,
        description: defaultMemo,
      );

      if (!mounted) return;

      accNo = (payosData['accountNumber'] != null && payosData['accountNumber'] != '1021072004' && payosData['accountNumber']!.isNotEmpty)
          ? payosData['accountNumber']!
          : '0776101860';
      accName = (payosData['accountName'] != null && payosData['accountName']!.isNotEmpty)
          ? payosData['accountName']!
          : 'DANG THANH TUNG';
      memo = payosData['description']!;
      qrUrl = CheckoutService.buildQrImageUrl(
        bin: '970422',
        accountNumber: accNo,
        amount: amount,
        description: memo,
      );
    }

    if (effectiveBusId.isNotEmpty) {
      cartProvider.setPendingOrderForBusiness(
        effectiveBusId,
        order,
        qrDetails: {
          'qrUrl': qrUrl,
          'accountNumber': accNo,
          'accountName': accName,
          'description': memo,
        },
      );
    }

    Timer? pollTimer;
    Timer? countdownTimer;
    int remainingSeconds = effectiveBusId.isNotEmpty
        ? cartProvider.getRemainingSecondsForBusiness(effectiveBusId)
        : 15 * 60;
    bool isPaymentSuccess = false;
    bool isExpired = remainingSeconds <= 0;

    void onPaidVerified(BuildContext modalCtx, StateSetter setModalState) {
      if (isPaymentSuccess) return;
      pollTimer?.cancel();
      countdownTimer?.cancel();
      if (effectiveBusId.isNotEmpty) {
        cartProvider.completePaymentForBusiness(effectiveBusId);
      }
      if (modalCtx.mounted) {
        setModalState(() {
          isPaymentSuccess = true;
        });
      }
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        if (modalCtx.mounted) Navigator.pop(modalCtx);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
          (route) => route.isFirst,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thanh toán thành công! Đã xác nhận đặt bàn & đơn món #$orderCode 🎉'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      });
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
            if (isPaymentSuccess || !ctx.mounted) {
              timer.cancel();
              return;
            }
            if (remainingSeconds <= 1) {
              timer.cancel();
              pollTimer?.cancel();
              setModalState(() {
                remainingSeconds = 0;
                isExpired = true;
              });
            } else {
              setModalState(() {
                remainingSeconds--;
              });
            }
          });

          pollTimer ??= Timer.periodic(const Duration(seconds: 2), (timer) async {
            if (isPaymentSuccess || isExpired) {
              timer.cancel();
              return;
            }
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            if (authProvider.token == null) return;
            final isPaid = await _checkoutService.checkPaymentStatus(orderCode, authProvider.token!);
            if (isPaid && ctx.mounted) {
              onPaidVerified(ctx, setModalState);
            }
          });

          final minutesStr = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
          final secondsStr = (remainingSeconds % 60).toString().padLeft(2, '0');

          return WillPopScope(
            onWillPop: () async {
              pollTimer?.cancel();
              countdownTimer?.cancel();
              return true;
            },
            child: Container(
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
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isExpired ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 15,
                          color: isExpired ? const Color(0xFFDC2626) : const Color(0xFF0072FF),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isExpired ? 'Mã QR đã hết hạn (15:00)' : 'Mã QR hết hạn sau: $minutesStr:$secondsStr',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isExpired ? const Color(0xFFDC2626) : const Color(0xFF0072FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

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
                            errorBuilder: (context, error, stackTrace) {
                              final fallbackEmv = CheckoutService.buildVietQrEmvPayload(
                                bin: '970422',
                                accountNumber: accNo,
                                amount: amount,
                                description: memo,
                              );
                              return Image.network(
                                'https://api.qrserver.com/v1/create-qr-code/?size=300x300&margin=10&data=${Uri.encodeComponent(fallbackEmv)}',
                                width: 210,
                                height: 210,
                                fit: BoxFit.contain,
                              );
                            },
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
                        _buildCopyableRow('Số tài khoản:', accNo, accNo),
                        const Divider(height: 12),
                        _buildCopyableRow('Chủ tài khoản:', accName, accName),
                        const Divider(height: 12),
                        _buildCopyableRow('Nội dung CK:', memo, memo),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Realtime Status Indicator (Tự động cập nhật qua PayOS / Webhook, không cần bấm nút xác nhận)
                  if (isPaymentSuccess) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'CHUYỂN KHOẢN THÀNH CÔNG 🎉',
                            style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else if (isExpired) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Mã QR đã hết hiệu lực sau 15 phút. Vui lòng tạo lại giao dịch mới.',
                              style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 12.5),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () {
                          pollTimer?.cancel();
                          countdownTimer?.cancel();
                          Navigator.pop(ctx);
                        },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Đóng'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
    pollTimer?.cancel();
    countdownTimer?.cancel();
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
    // Bắn Heads-up Banner thông báo trực tiếp ra ngoài máy điện thoại
    NotificationService().showOrderSuccessNotification(orderCode: orderCode);
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
    final checkoutItems = cartProvider.activeItems;
    final checkoutSubtotal = cartProvider.activeSubtotal;

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

                  // Booking Enforcement Card
                  if (_isLoadingBooking)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 10),
                            Text('Đang kiểm tra lịch đặt bàn...', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    )
                  else if (_activeBooking != null)
                    Container(
                      padding: const EdgeInsets.all(14.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.event_seat_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Thông tin đặt bàn kèm món',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFFB45309)),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD97706),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Chờ thanh toán',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Mã: #${_activeBooking!.bookingCode.length > 12 ? _activeBooking!.bookingCode.substring(0, 12) : _activeBooking!.bookingCode} • ${_activeBooking!.bookingDate} (${_activeBooking!.startTime})',
                                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Số khách: ${_activeBooking!.guestCount} người${_activeBooking!.tableName != null ? " • Bàn: ${_activeBooking!.tableName}" : ""} • Xác nhận sau khi thanh toán',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF78350F)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(14.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Chưa có lịch đặt bàn tại quán này',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF991B1B)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Quy định nhà hàng: Bạn bắt buộc phải đặt bàn thành công trước khi tiến hành đặt món ăn!',
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF7F1D1D), height: 1.3),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _openBookingModal,
                              icon: const Icon(Icons.table_restaurant_rounded, size: 18),
                              label: const Text('Đặt bàn tại quán ngay', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // 1. Selected Items Summary
                  const Text('1. Món ăn đã chọn', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
                      itemCount: checkoutItems.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (ctx, idx) {
                        final item = checkoutItems[idx];
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

                  // 2. Note Field
                  const Text('2. Ghi chú cho quán', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
                    subtotal: checkoutSubtotal,
                    total: checkoutSubtotal,
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
                              'Xác nhận & Thanh toán • ${_formatPrice(checkoutSubtotal)}',
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

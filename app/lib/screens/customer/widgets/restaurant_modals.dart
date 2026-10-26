import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/booking_model.dart';
import '../../../models/restaurant_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/restaurant_service.dart';
import '../../auth/login_screen.dart';
import '../booking/booking_detail_screen.dart';
import '../booking/booking_screen.dart';
import '../restaurant_detail_screen.dart';

class RestaurantModals {
  /// Modal Đặt bàn nhanh kết nối Backend
  static void showBooking(
    BuildContext context,
    RestaurantModel r, {
    RestaurantService? restaurantService,
  }) {
    final service = restaurantService ?? RestaurantService();
    int guestCount = 2;
    final List<String> times = BookingScreen.generateTimeSlots(r.openTime, r.closeTime);
    String selectedTime = times.contains('19:00') ? '19:00' : (times.isNotEmpty ? times.first : '19:00');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.table_restaurant_rounded, color: Color(0xFF0072FF), size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đặt bàn tại ${r.name}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Số lượng khách
                const Text('Số lượng khách:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [1, 2, 4, 6, 8, 10].map((guestNum) {
                      final isSel = guestCount == guestNum;
                      return GestureDetector(
                        onTap: () => setModalState(() => guestCount = guestNum),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFF0072FF) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$guestNum người',
                            style: TextStyle(
                              color: isSel ? Colors.white : const Color(0xFF334155),
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Khung giờ đặt
                const Text('Khung giờ:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: times.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 2.2,
                    ),
                    itemBuilder: (ctx, idx) {
                      final t = times[idx];
                      final isSel = selectedTime == t;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedTime = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFF0072FF) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            t,
                            style: TextStyle(
                              color: isSel ? Colors.white : const Color(0xFF334155),
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 22),

                // Nút Xác nhận đặt bàn kết nối API Backend
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final token = await AuthService().getToken();
                      if (token == null || token.isEmpty) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Vui lòng đăng nhập để thực hiện đặt bàn'),
                            backgroundColor: const Color(0xFF0072FF),
                            behavior: SnackBarBehavior.floating,
                            action: SnackBarAction(
                              label: 'Đăng nhập',
                              textColor: Colors.white,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                                );
                              },
                            ),
                          ),
                        );
                        return;
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
                      final res = await service.createBooking(
                        businessId: r.id,
                        bookingDate: todayStr,
                        startTime: selectedTime,
                        guestCount: guestCount,
                      );
                      if (!context.mounted) return;
                      String errorMsg = res['message'] ?? 'Đặt bàn thất bại';
                      if (errorMsg.contains('Booking must be in the future')) {
                        errorMsg = 'Khung giờ đặt bàn phải sau thời điểm hiện tại. Vui lòng chọn giờ khác!';
                      }
                      if (res['success'] == true && res['booking'] is BookingModel) {
                        final booking = res['booking'] as BookingModel;
                        final bookingService = BookingService();
                        final depositRes = await bookingService.createDepositPaymentLink(booking.id);
                        if (!context.mounted) return;
                        
                        showDepositPaymentModal(
                          context,
                          booking: booking,
                          depositData: depositRes['data'] ?? {},
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFFEF4444),
                            content: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(child: Text(errorMsg)),
                              ],
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0072FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Xác nhận đặt bàn nhanh', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 10),

                // Nút mở màn hình đặt bàn đầy đủ chọn bàn theo sơ đồ
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingScreen(
                            restaurant: r,
                            initialGuests: guestCount,
                            initialTime: selectedTime,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.table_restaurant_outlined, size: 16, color: Color(0xFF0072FF)),
                    label: const Text(
                      'Tùy chọn ngày, ghi chú & tự chọn bàn ăn',
                      style: TextStyle(color: Color(0xFF0072FF), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Mở màn hình Xem chi tiết quán ăn chuẩn phong cách FConnect
  static void showDetails(BuildContext context, RestaurantModel r) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(restaurant: r),
      ),
    );
  }

  /// Modal Thanh toán Cọc bàn VietQR / PayOS
  static void showDepositPaymentModal(
    BuildContext context, {
    required BookingModel booking,
    required Map<String, dynamic> depositData,
  }) {
    final amount = depositData['depositAmount'] ?? 50000;
    final qrUrl = depositData['qrCode'] ??
        'https://api.vietqr.io/image/970422-1021072004-compact2.jpg?amount=$amount&addInfo=${Uri.encodeComponent("COC BAN ${booking.bookingCode}")}&accountName=${Uri.encodeComponent("LUONG DANG HOANG LUU")}';
    final accNo = (depositData['accountNumber'] ?? '1021072004').toString();
    final accName = (depositData['accountName'] ?? 'LUONG DANG HOANG LUU').toString();
    final memo = (depositData['description'] ?? 'COC BAN ${booking.bookingCode}').toString();

    Timer? pollTimer;
    bool isPaymentSuccess = false;
    final orderCode = depositData['orderCode'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // Polling Timer tự động kiểm tra giao dịch PayOS mỗi 3s
          if (orderCode != null && !isPaymentSuccess) {
            pollTimer ??= Timer.periodic(const Duration(seconds: 3), (timer) async {
              if (isPaymentSuccess) {
                timer.cancel();
                return;
              }
              final bookingService = BookingService();
              final isPaid = await bookingService.checkPaymentStatus(orderCode);
              if (isPaid && ctx.mounted) {
                timer.cancel();
                setModalState(() {
                  isPaymentSuccess = true;
                });

                // Tự động đóng modal và mở vé đặt bàn sau 1.5 giây
                Future.delayed(const Duration(milliseconds: 1500), () {
                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: booking)),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Xác nhận đặt cọc thành công! Bàn của bạn tại ${booking.businessName} đã được giữ chỗ 🎉'),
                      backgroundColor: const Color(0xFF10B981),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                });
              }
            });
          }

          return WillPopScope(
            onWillPop: () async {
              pollTimer?.cancel();
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
                        'Thanh toán Cọc bàn (VietQR / PayOS)',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quét mã QR để hoàn tất thanh toán cọc bàn tại ${booking.businessName}',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
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
                            width: 200,
                            height: 200,
                            fit: BoxFit.contain,
                            loadingBuilder: (_, child, prog) => prog == null
                                ? child
                                : const SizedBox(
                                    width: 200,
                                    height: 200,
                                    child: Center(child: CircularProgressIndicator()),
                                  ),
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 200,
                              height: 200,
                              color: Colors.grey[100],
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.qr_code_rounded, size: 70, color: Color(0xFF0072FF)),
                                  Text('VietQR Gateway', style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Tiền cọc: ${(amount as num).toInt().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')}đ',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0072FF)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Bank Details
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildCopyRow(context, 'Ngân hàng:', 'MBBank (Quân Đội)', 'MBBank'),
                        const Divider(height: 12),
                        _buildCopyRow(context, 'Số tài khoản:', accNo, accNo),
                        const Divider(height: 12),
                        _buildCopyRow(context, 'Chủ tài khoản:', accName, accName),
                        const Divider(height: 12),
                        _buildCopyRow(context, 'Nội dung CK:', memo, memo),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Status Indicator
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
                            'ĐÃ XÁC NHẬN TIỀN CỌC THÀNH CÔNG 🎉',
                            style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                        ],
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
  }

  static Widget _buildCopyRow(BuildContext context, String label, String value, String copyValue) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
        Row(
          children: [
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(width: 4),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: copyValue));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã sao chép $label'), duration: const Duration(seconds: 1)),
                );
              },
              child: const Icon(Icons.copy_rounded, size: 15, color: Color(0xFF0072FF)),
            ),
          ],
        ),
      ],
    );
  }
}


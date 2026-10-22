import 'package:flutter/material.dart';
import '../../../models/restaurant_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/restaurant_service.dart';
import '../../auth/login_screen.dart';
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
                Row(
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          content: Row(
                            children: [
                              Icon(
                                res['success'] == true ? Icons.check_circle_outline : Icons.error_outline,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  res['success'] == true
                                      ? 'Đặt bàn thành công! Mã: ${res['bookingCode']} lúc $selectedTime tại ${r.name}'
                                      : errorMsg,
                                ),
                              ),
                            ],
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
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
}


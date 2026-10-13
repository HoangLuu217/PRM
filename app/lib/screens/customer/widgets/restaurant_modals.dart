import 'package:flutter/material.dart';
import '../../../models/restaurant_model.dart';
import '../../../services/restaurant_service.dart';
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
    String selectedTime = '19:00';
    final List<String> times = [
      '11:30', '12:00', '12:30', '18:00', '18:30', '19:00', '19:30', '20:00'
    ];

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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: times.map((t) {
                    final isSel = selectedTime == t;
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedTime = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF0072FF) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            color: isSel ? Colors.white : const Color(0xFF334155),
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),

                // Nút Xác nhận đặt bàn kết nối API Backend
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
                      final res = await service.createBooking(
                        businessId: r.id,
                        bookingDate: todayStr,
                        startTime: selectedTime,
                        guestCount: guestCount,
                      );
                      if (!context.mounted) return;
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
                                      : (res['message'] ?? 'Đặt bàn thất bại'),
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
                    child: const Text('Xác nhận đặt bàn', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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


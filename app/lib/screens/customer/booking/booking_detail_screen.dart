import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/booking_model.dart';
import '../../../providers/booking_provider.dart';

class BookingDetailScreen extends StatelessWidget {
  final BookingModel booking;

  const BookingDetailScreen({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Chi tiết đặt bàn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
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
                                booking.statusLabel,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          booking.businessName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'MÃ: #${booking.bookingCode}',
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
                        _buildInfoRow('Ngày dùng bữa', booking.bookingDate, Icons.calendar_month_rounded),
                        const Divider(height: 24, color: Color(0xFFF1F5F9)),
                        _buildInfoRow('Khung giờ', booking.startTime, Icons.access_time_rounded),
                        const Divider(height: 24, color: Color(0xFFF1F5F9)),
                        _buildInfoRow('Số lượng khách', '${booking.guestCount} người', Icons.people_alt_rounded),
                        const Divider(height: 24, color: Color(0xFFF1F5F9)),
                        _buildInfoRow('Bàn ăn đã chọn', booking.tableName ?? 'Nhà hàng tự sắp xếp', Icons.table_restaurant_rounded),
                        if (booking.branchAddress != null && booking.branchAddress!.isNotEmpty) ...[
                          const Divider(height: 24, color: Color(0xFFF1F5F9)),
                          _buildInfoRow('Địa chỉ cơ sở', booking.branchAddress!, Icons.location_on_rounded),
                        ],
                        if (booking.note.isNotEmpty) ...[
                          const Divider(height: 24, color: Color(0xFFF1F5F9)),
                          _buildInfoRow('Ghi chú thực khách', booking.note, Icons.note_alt_rounded),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Nút hủy đặt bàn
            if (booking.canCustomerCancel)
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
              final success = await Provider.of<BookingProvider>(context, listen: false).cancelBooking(booking.id);
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

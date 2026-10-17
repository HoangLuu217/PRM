import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/restaurant_model.dart';
import '../../../models/table_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/booking_provider.dart';
import '../../../providers/table_provider.dart';
import '../../auth/login_screen.dart';
import 'my_bookings_screen.dart';

class BookingScreen extends StatefulWidget {
  final RestaurantModel restaurant;
  final String? initialDate;
  final String? initialTime;
  final int initialGuests;

  const BookingScreen({
    super.key,
    required this.restaurant,
    this.initialDate,
    this.initialTime,
    this.initialGuests = 2,
  });

  static int parseTimeToMinutes(String timeStr, int defaultMinutes) {
    try {
      final s = timeStr.trim();
      final match = RegExp(r'^(\d{1,2})[:hH](\d{2})?').firstMatch(s);
      if (match != null) {
        int hour = int.parse(match.group(1)!);
        int minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;
        final lower = s.toLowerCase();
        if (lower.contains('pm') && hour < 12) hour += 12;
        if (lower.contains('am') && hour == 12) hour = 0;
        return hour * 60 + minute;
      }
    } catch (_) {}
    return defaultMinutes;
  }

  static List<String> generateTimeSlots(String? openTime, String? closeTime) {
    final startMin = parseTimeToMinutes(openTime ?? '07:00', 7 * 60);
    int endMin = parseTimeToMinutes(closeTime ?? '22:00', 22 * 60);

    // Xử lý trường hợp quán mở qua đêm (ví dụ: mở 18:00, đóng 02:00 sáng hôm sau)
    if (endMin <= startMin) {
      endMin += 24 * 60;
    }

    final List<String> slots = [];
    for (int m = startMin; m <= endMin; m += 30) {
      final normalized = m % (24 * 60);
      final hour = (normalized ~/ 60).toString().padLeft(2, '0');
      final minute = (normalized % 60).toString().padLeft(2, '0');
      final slot = '$hour:$minute';
      if (!slots.contains(slot)) {
        slots.add(slot);
      }
    }

    if (slots.isEmpty) {
      return [
        '07:00', '07:30', '08:00', '08:30', '09:00', '09:30',
        '10:00', '10:30', '11:00', '11:30', '12:00', '12:30',
        '13:00', '13:30', '14:00', '14:30', '15:00', '15:30',
        '16:00', '16:30', '17:00', '17:30', '18:00', '18:30',
        '19:00', '19:30', '20:00', '20:30', '21:00', '21:30', '22:00'
      ];
    }
    return slots;
  }

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late DateTime _selectedDate;
  late String _selectedTime;
  late int _guestCount;
  TableModel? _selectedTable;
  final TextEditingController _noteController = TextEditingController();
  bool _isLoadingTables = false;

  late List<String> _timeSlots;

  @override
  void initState() {
    super.initState();
    _timeSlots = BookingScreen.generateTimeSlots(
      widget.restaurant.openTime,
      widget.restaurant.closeTime,
    );

    _selectedDate = widget.initialDate != null
        ? (DateTime.tryParse(widget.initialDate!) ?? DateTime.now())
        : DateTime.now();

    if (widget.initialTime != null && _timeSlots.contains(widget.initialTime)) {
      _selectedTime = widget.initialTime!;
    } else if (_timeSlots.contains('19:00')) {
      _selectedTime = '19:00';
    } else if (_timeSlots.isNotEmpty) {
      _selectedTime = _timeSlots.first;
    } else {
      _selectedTime = '19:00';
    }

    _guestCount = widget.initialGuests;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAvailableTables();
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String get _dateString =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

  Future<void> _loadAvailableTables() async {
    final branchId = widget.restaurant.branchId;
    if (branchId == null || branchId.isEmpty) return;

    setState(() => _isLoadingTables = true);
    await Provider.of<TableProvider>(context, listen: false).fetchAvailableTables(
      branchId: branchId,
      bookingDate: _dateString,
      startTime: _selectedTime,
      guestCount: _guestCount,
    );
    if (mounted) {
      setState(() {
        _isLoadingTables = false;
        _selectedTable = null; // reset selected table upon slot change
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0072FF),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadAvailableTables();
    }
  }

  Future<void> _submitBooking() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      final shouldLogin = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Yêu cầu đăng nhập', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Bạn cần đăng nhập tài khoản FConnect để hoàn tất đặt bàn tại nhà hàng.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Để sau'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0072FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Đăng nhập ngay'),
            ),
          ],
        ),
      );

      if (shouldLogin == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      return;
    }

    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);

    final res = await bookingProvider.createBooking(
      businessId: widget.restaurant.id,
      branchId: widget.restaurant.branchId,
      tableId: _selectedTable?.id,
      bookingDate: _dateString,
      startTime: _selectedTime,
      guestCount: _guestCount,
      note: _noteController.text.trim(),
    );

    if (!mounted) return;

    if (res['success'] == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Đặt bàn thành công!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Mã đặt bàn: ${res['bookingCode'] ?? 'Đã xác nhận'}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0072FF), fontSize: 15),
              ),
              const SizedBox(height: 10),
              Text(
                'Nhà hàng ${widget.restaurant.name} sẽ chuẩn bị bàn cho bạn vào lúc $_selectedTime ngày $_dateString.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Đóng'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0072FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Xem lịch đặt'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      String msg = res['message'] ?? 'Đặt bàn thất bại';
      if (msg.contains('Booking must be in the future')) {
        msg = 'Khung giờ đặt bàn phải sau thời điểm hiện tại. Vui lòng chọn khung giờ khác hoặc đổi ngày!';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tableProvider = Provider.of<TableProvider>(context);
    final bookingProvider = Provider.of<BookingProvider>(context);
    final availableTables = tableProvider.availableTables;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Đặt bàn F&B', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thông tin F&B
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: widget.restaurant.coverImageUrl != null
                        ? Image.network(
                            widget.restaurant.coverImageUrl!,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 70,
                              height: 70,
                              color: const Color(0xFFE2E8F0),
                              child: const Icon(Icons.restaurant, color: Color(0xFF94A3B8)),
                            ),
                          )
                        : Container(
                            width: 70,
                            height: 70,
                            color: const Color(0xFFE2E8F0),
                            child: const Icon(Icons.restaurant, color: Color(0xFF94A3B8)),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.restaurant.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.restaurant.address,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 14, color: Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.restaurant.openTime ?? "07:00"} - ${widget.restaurant.closeTime ?? "22:00"}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Bước 1: Chọn ngày
            _buildSectionHeader('1. Chọn ngày dùng bữa', Icons.calendar_today_rounded),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF0072FF), width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.event_available, color: Color(0xFF0072FF)),
                              const SizedBox(width: 10),
                              Text(
                                _dateString,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          const Text(
                            'Đổi ngày',
                            style: TextStyle(color: Color(0xFF0072FF), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Bước 2: Chọn khung giờ
            _buildSectionHeader('2. Chọn giờ dùng bữa', Icons.access_time_filled_rounded),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _timeSlots.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.2,
              ),
              itemBuilder: (context, index) {
                final time = _timeSlots[index];
                final isSel = _selectedTime == time;
                return InkWell(
                  onTap: () {
                    setState(() => _selectedTime = time);
                    _loadAvailableTables();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFF0072FF) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSel ? const Color(0xFF0072FF) : const Color(0xFFE2E8F0),
                        width: isSel ? 1.5 : 1,
                      ),
                      boxShadow: isSel
                          ? [
                              BoxShadow(
                                color: const Color(0xFF0072FF).withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      time,
                      style: TextStyle(
                        color: isSel ? Colors.white : const Color(0xFF334155),
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Bước 3: Số lượng khách
            _buildSectionHeader('3. Số lượng khách', Icons.people_alt_rounded),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [1, 2, 3, 4, 5, 6, 8, 10, 12, 16].map((count) {
                  final isSel = _guestCount == count;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      showCheckmark: false,
                      label: Text('$count người'),
                      selected: isSel,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _guestCount = count);
                          _loadAvailableTables();
                        }
                      },
                      selectedColor: const Color(0xFF0072FF),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : const Color(0xFF334155),
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: isSel ? const Color(0xFF0072FF) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Bước 4: Chọn bàn (Table)
            _buildSectionHeader('4. Chọn bàn (Tùy chọn)', Icons.table_restaurant_rounded),
            const SizedBox(height: 6),
            const Text(
              'Hệ thống tự động lọc các bàn còn trống phù hợp với số lượng khách của bạn:',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            if (_isLoadingTables)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: Color(0xFF0072FF)),
                ),
              )
            else if (availableTables.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF64748B)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Quán sẽ tự động sắp xếp bàn phù hợp nhất khi bạn đến nơi.',
                        style: TextStyle(color: Color(0xFF475569), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  RadioListTile<TableModel?>(
                    value: null,
                    groupValue: _selectedTable,
                    onChanged: (val) => setState(() => _selectedTable = val),
                    title: const Text('Nhà hàng tự động xếp bàn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Bàn ngẫu nhiên phù hợp số lượng người', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    activeColor: const Color(0xFF0072FF),
                    contentPadding: EdgeInsets.zero,
                  ),
                  ...availableTables.map((tbl) {
                    return RadioListTile<TableModel?>(
                      value: tbl,
                      groupValue: _selectedTable,
                      onChanged: (val) => setState(() => _selectedTable = val),
                      title: Text('${tbl.name} (${tbl.capacity} người)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('${tbl.location} • ${tbl.statusLabel}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      activeColor: const Color(0xFF0072FF),
                      contentPadding: EdgeInsets.zero,
                    );
                  }),
                ],
              ),
            const SizedBox(height: 20),

            // Bước 5: Ghi chú
            _buildSectionHeader('5. Ghi chú cho nhà hàng', Icons.edit_note_rounded),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Ví dụ: Đặt bàn góc yên tĩnh, sinh nhật, ghế em bé...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0072FF), width: 1.5)),
              ),
            ),
            const SizedBox(height: 32),

            // Nút Xác nhận đặt bàn
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: bookingProvider.isLoading ? null : _submitBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0072FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
                child: bookingProvider.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Xác nhận đặt bàn',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF0072FF)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
        ),
      ],
    );
  }
}

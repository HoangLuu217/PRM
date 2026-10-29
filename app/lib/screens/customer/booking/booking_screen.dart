import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../models/booking_model.dart';
import '../../../models/product_model.dart';
import '../../../models/restaurant_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/booking_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/table_provider.dart';
import '../../../services/booking_service.dart';
import '../../../services/order_service.dart';
import '../../auth/login_screen.dart';
import '../checkout/checkout_screen.dart';
import '../widgets/restaurant_modals.dart';
import 'my_bookings_screen.dart';

class BookingScreen extends StatefulWidget {
  final RestaurantModel restaurant;
  final String? initialDate;
  final String? initialTime;
  final int initialGuests;
  final Map<String, int>? initialSelectedDishes;

  const BookingScreen({
    super.key,
    required this.restaurant,
    this.initialDate,
    this.initialTime,
    this.initialGuests = 2,
    this.initialSelectedDishes,
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
  final TextEditingController _noteController = TextEditingController();

  late List<String> _timeSlots;

  // Thực đơn đặt trước
  bool _isLoadingMenu = true;
  List<Map<String, dynamic>> _menuProducts = [];
  final Map<String, int> _selectedDishQuantities = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialSelectedDishes != null) {
      _selectedDishQuantities.addAll(widget.initialSelectedDishes!);
    }

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
      _loadMenuProducts();
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadMenuProducts() async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/products?businessId=${widget.restaurant.id}');
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['data'] as List<dynamic>?) ?? [];
        if (mounted) {
          setState(() {
            _menuProducts = list.map((item) => item as Map<String, dynamic>).toList();
            _isLoadingMenu = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoadingMenu = false);
    }
  }

  int get _dishesTotal {
    int total = 0;
    for (final prod in _menuProducts) {
      final id = (prod['_id'] ?? prod['id'] ?? '').toString();
      final qty = _selectedDishQuantities[id] ?? 0;
      if (qty > 0) {
        final price = (prod['price'] as num?)?.toInt() ?? 0;
        total += price * qty;
      }
    }
    return total;
  }

  int get _dishesCount {
    int count = 0;
    for (final qty in _selectedDishQuantities.values) {
      count += qty;
    }
    return count;
  }

  String _formatCurrency(int amount) {
    return '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ';
  }

  String get _dateString =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
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
      setState(() {
        _selectedDate = picked;
      });

    }
  }

  void _submitBooking() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      final shouldLogin = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Yêu cầu đăng nhập'),
          content: const Text('Bạn cần đăng nhập để thực hiện đặt bàn và chọn món ăn.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0072FF),
                foregroundColor: Colors.white,
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
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    final res = await bookingProvider.createBooking(
      businessId: widget.restaurant.id,
      branchId: widget.restaurant.branchId,
      bookingDate: _dateString,
      startTime: _selectedTime,
      guestCount: _guestCount,
      note: _noteController.text.trim(),
    );

    if (!mounted) return;

    if (res['success'] == true) {
      final bookingCode = res['bookingCode'] ?? 'Đã xác nhận';
      final hasDishes = _dishesCount > 0 || (cartProvider.itemCount > 0 && cartProvider.businessId == widget.restaurant.id);

      // Nếu chọn món ngay tại màn hình đặt bàn, đồng bộ các món vào cartProvider
      if (_dishesCount > 0) {
        for (final p in _menuProducts) {
          final id = (p['_id'] ?? p['id'] ?? '').toString();
          final qty = _selectedDishQuantities[id] ?? 0;
          if (qty > 0) {
            final prodModel = ProductModel(
              id: id,
              category: p['category']?.toString() ?? 'Món ăn',
              name: p['name']?.toString() ?? 'Món ăn',
              description: p['description']?.toString() ?? '',
              price: (p['price'] as num?)?.toDouble() ?? 0.0,
              imageUrl: p['imageUrl']?.toString() ?? '',
            );
            cartProvider.addItem(
              product: prodModel,
              targetBusinessId: widget.restaurant.id,
              targetBusinessName: widget.restaurant.name,
              targetBranchId: widget.restaurant.branchId,
              quantity: qty,
            );
          }
        }
      }

      if (!mounted) return;

      // NẾU CÓ ĐẶT MÓN ÁN -> BẮT BUỘC CHUYỂN THẲNG SANG MÀN HÌNH THANH TOÁN MÓN
      if (hasDishes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Đặt bàn #$bookingCode thành công! Đang chuyển sang thanh toán món...'),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CheckoutScreen()),
        );
        return;
      }

      // NẾU CHỈ ĐẶT BÀN KHÔNG CHỌN MÓN -> HIỂN THỊ THÔNG BÁO THÀNH CÔNG THƯỜNG
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
                'Mã đặt bàn: #$bookingCode',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0072FF), fontSize: 15),
              ),
              const SizedBox(height: 10),
              Text(
                'Nhà hàng ${widget.restaurant.name} sẽ chuẩn bị bàn cho bạn vào lúc $_selectedTime ngày $_dateString.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0072FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                  label: const Text('Xem lịch sử đặt bàn của tôi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
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
    final bookingProvider = Provider.of<BookingProvider>(context);

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
                              color: const Color(0xFFF1F5F9),
                              child: const Icon(Icons.restaurant, color: Color(0xFF94A3B8)),
                            ),
                          )
                        : Container(
                            width: 70,
                            height: 70,
                            color: const Color(0xFFF1F5F9),
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
                            const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
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
                            const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF0072FF)),
                            const SizedBox(width: 4),
                            Text(
                              'Giờ mở cửa: ${widget.restaurant.openTime ?? '07:00'} - ${widget.restaurant.closeTime ?? '22:00'}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF0072FF)),
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
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.event, color: Color(0xFF0072FF), size: 20),
                        const SizedBox(width: 10),
                        Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Bước 2: Chọn khung giờ
            _buildSectionHeader('2. Chọn khung giờ', Icons.access_time_rounded),
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
              itemBuilder: (ctx, idx) {
                final time = _timeSlots[idx];
                final isSel = _selectedTime == time;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedTime = time);
                                },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFF0072FF) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSel ? const Color(0xFF0072FF) : const Color(0xFFE2E8F0),
                        width: isSel ? 1.5 : 1,
                      ),
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

            // Bước 4: Đặt trước món ăn (Tùy chọn)
            _buildSectionHeader('4. Chọn món đặt trước (Tùy chọn)', Icons.restaurant_menu_rounded),
            const SizedBox(height: 6),
            const Text(
              'Chọn trước món ăn để nhà hàng chuẩn bị sẵn sàng khi bạn tới bàn:',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),

            if (_isLoadingMenu)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: Color(0xFF0072FF)),
                ),
              )
            else if (_menuProducts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'Quán chưa cập nhật thực đơn hoặc bạn có thể gọi món trực tiếp khi tới nơi.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
              )
            else ...[
              // Banner tổng tiền món đã chọn
              if (_dishesCount > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF0072FF), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Đã chọn: $_dishesCount món',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), fontSize: 13),
                          ),
                        ],
                      ),
                      Text(
                        'Tạm tính: ${_formatCurrency(_dishesTotal)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0072FF), fontSize: 14),
                      ),
                    ],
                  ),
                ),

              // Danh sách món trong menu
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _menuProducts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (ctx, idx) {
                  final prod = _menuProducts[idx];
                  final id = (prod['_id'] ?? prod['id'] ?? '').toString();
                  final name = prod['name']?.toString() ?? 'Món ngon';
                  final price = (prod['price'] as num?)?.toInt() ?? 0;
                  final img = prod['imageUrl']?.toString();
                  final cat = prod['category']?.toString() ?? 'Món ăn';
                  final qty = _selectedDishQuantities[id] ?? 0;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: qty > 0 ? const Color(0xFF0072FF) : const Color(0xFFE2E8F0),
                        width: qty > 0 ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            img ?? 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=200&q=80',
                            width: 58,
                            height: 58,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 58,
                              height: 58,
                              color: const Color(0xFFF1F5F9),
                              child: const Icon(Icons.fastfood_rounded, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  cat,
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 3),
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
                                      _selectedDishQuantities[id] = qty - 1;
                                    } else {
                                      _selectedDishQuantities.remove(id);
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
                                  _selectedDishQuantities[id] = qty + 1;
                                });
                              },
                              icon: Icon(
                                qty > 0 ? Icons.add_circle : Icons.add_circle_outline,
                                color: const Color(0xFF0072FF),
                                size: 24,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
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
                    : Text(
                        _dishesCount > 0
                            ? 'Xác nhận đặt bàn & $_dishesCount món'
                            : 'Xác nhận đặt bàn',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

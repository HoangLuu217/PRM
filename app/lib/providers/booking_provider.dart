import 'package:flutter/foundation.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';

class BookingProvider with ChangeNotifier {
  final BookingService _bookingService = BookingService();

  List<BookingModel> _myBookings = [];
  List<BookingModel> _ownerBookings = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<BookingModel> get myBookings => _myBookings;
  List<BookingModel> get ownerBookings => _ownerBookings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Đếm nhanh booking theo status cho Dashboard
  int get pendingCount => _ownerBookings.where((b) => b.isPending).length;
  int get confirmedCount => _ownerBookings.where((b) => b.isConfirmed).length;
  int get checkedInCount => _ownerBookings.where((b) => b.isCheckedIn).length;

  /// Tải danh sách đặt bàn của khách hàng
  Future<void> fetchMyBookings() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _myBookings = await _bookingService.getMyBookings();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Tải danh sách đặt bàn cho chủ quán
  Future<void> fetchOwnerBookings({String? status, String? bookingDate, bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      _ownerBookings = await _bookingService.getOwnerBookings(
        status: status,
        bookingDate: bookingDate,
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  /// Khách hàng tạo đặt bàn
  Future<Map<String, dynamic>> createBooking({
    required String businessId,
    String? branchId,
    String? tableId,
    required String bookingDate,
    required String startTime,
    String? endTime,
    required int guestCount,
    String? note,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _bookingService.createBooking(
        businessId: businessId,
        branchId: branchId,
        tableId: tableId,
        bookingDate: bookingDate,
        startTime: startTime,
        endTime: endTime,
        guestCount: guestCount,
        note: note,
      );

      if (res['success'] == true && res['booking'] is BookingModel) {
        _myBookings.insert(0, res['booking'] as BookingModel);
      }

      return res;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Khách hàng hủy đặt bàn
  Future<bool> cancelBooking(String id) async {
    final res = await _bookingService.cancelBooking(id);
    if (res['success'] == true) {
      final index = _myBookings.indexWhere((b) => b.id == id);
      if (index != -1) {
        // Cập nhật trạng thái tại chỗ
        fetchMyBookings();
      }
      return true;
    }
    return false;
  }

  /// Chủ quán cập nhật trạng thái đặt bàn (Confirm, Reject, Cancel, Check-in, Complete)
  Future<Map<String, dynamic>> updateOwnerBookingStatus(
    String id,
    String status, {
    String? tableId,
  }) async {
    final res = await _bookingService.updateOwnerBookingStatus(
      id,
      status,
      tableId: tableId,
    );

    if (res['success'] == true && res['booking'] is BookingModel) {
      final updated = res['booking'] as BookingModel;
      final idx = _ownerBookings.indexWhere((b) => b.id == id);
      if (idx != -1) {
        _ownerBookings[idx] = updated;
      }
      notifyListeners();
    }

    return res;
  }
}

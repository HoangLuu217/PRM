import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/booking_model.dart';
import 'auth_service.dart';

class BookingService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Bypass-Tunnel-Reminder': 'true',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// 1. Khách hàng tạo đặt bàn mới (POST /api/bookings)
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
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.bookings}');

      final body = {
        'businessId': businessId,
        if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
        if (tableId != null && tableId.isNotEmpty) 'tableId': tableId,
        'bookingDate': bookingDate,
        'startTime': startTime,
        if (endTime != null && endTime.isNotEmpty) 'endTime': endTime,
        'guestCount': guestCount,
        'note': note ?? '',
      };

      debugPrint('[BookingService] -> POST $uri: $body');
      final res = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      debugPrint('[BookingService] <- Status: ${res.statusCode}');

      if (res.statusCode == 200 || res.statusCode == 201) {
        final bookingData = data['data'] ?? data['booking'];
        final model = bookingData != null ? BookingModel.fromJson(bookingData) : null;
        return {
          'success': true,
          'booking': model,
          'bookingCode': model?.bookingCode ?? 'FCB${DateTime.now().millisecondsSinceEpoch}',
          'message': data['message'] ?? 'Đặt bàn thành công!',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Đặt bàn thất bại (${res.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('[BookingService Error]: $e');
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  /// 2. Khách hàng xem lịch sử đặt bàn của mình (GET /api/bookings/me)
  Future<List<BookingModel>> getMyBookings() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.myBookings}');

      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['data'] as List<dynamic>?) ?? [];
        return list.map((item) => BookingModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[BookingService getMyBookings Error]: $e');
    }
    return [];
  }

  /// 3. Xem chi tiết 1 đơn đặt bàn (GET /api/bookings/:id)
  Future<BookingModel?> getBookingById(String id) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.bookings}/$id');

      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['data'] != null) {
          return BookingModel.fromJson(data['data']);
        }
      }
    } catch (e) {
      debugPrint('[BookingService getBookingById Error]: $e');
    }
    return null;
  }

  /// 4. Khách hàng hủy đặt bàn (PUT /api/bookings/:id)
  Future<Map<String, dynamic>> cancelBooking(String id) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.bookings}/$id');

      final res = await http
          .put(uri, headers: headers, body: jsonEncode({'status': 'CANCELLED'}))
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return {'success': true, 'message': 'Đã hủy đặt bàn thành công'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Không thể hủy đặt bàn'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  /// 5. Chủ quán xem danh sách đặt bàn (GET /api/owner/bookings)
  Future<List<BookingModel>> getOwnerBookings({String? status, String? bookingDate}) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty && status != 'ALL') {
        queryParams['status'] = status;
      }
      if (bookingDate != null && bookingDate.isNotEmpty) {
        queryParams['bookingDate'] = bookingDate;
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.ownerBookings}')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['data'] as List<dynamic>?) ?? [];
        return list.map((item) => BookingModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[BookingService getOwnerBookings Error]: $e');
    }
    return [];
  }

  /// 6. Chủ quán cập nhật trạng thái đặt bàn (PUT /api/owner/bookings/:id)
  /// Status flow: CONFIRMED, REJECTED, CANCELLED, CHECKED_IN, COMPLETED
  Future<Map<String, dynamic>> updateOwnerBookingStatus(
    String id,
    String status, {
    String? tableId,
  }) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.ownerBookings}/$id');

      final body = {
        'status': status,
        if (tableId != null && tableId.isNotEmpty) 'tableId': tableId,
      };

      debugPrint('[BookingService] -> PUT $uri: $body');
      final res = await http
          .put(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final model = data['data'] != null ? BookingModel.fromJson(data['data']) : null;
        return {'success': true, 'booking': model, 'message': 'Cập nhật thành công!'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Cập nhật thất bại (${res.statusCode})'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  /// 7. Tạo mã VietQR PayOS đặt cọc bàn (POST /api/payments/create-deposit-link)
  Future<Map<String, dynamic>> createDepositPaymentLink(String bookingId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConstants.baseUrl}/payments/create-deposit-link');

      final body = {'bookingId': bookingId};
      final res = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Không thể tạo mã thanh toán cọc'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối thanh toán cọc: $e'};
    }
  }

  /// 8. Kiểm tra trạng thái thanh toán PayOS theo orderCode
  Future<bool> checkPaymentStatus(dynamic orderCode) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConstants.baseUrl}/payments/status/$orderCode');

      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['data']?['isPaid'] == true || data['data']?['status'] == 'PAID';
      }
    } catch (e) {
      debugPrint('[checkPaymentStatus Error]: $e');
    }
    return false;
  }
}

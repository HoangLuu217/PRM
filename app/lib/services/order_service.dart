import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/order_model.dart';
import 'auth_service.dart';

class OrderService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// 1. Tạo đơn đặt món (POST /api/orders)
  Future<Map<String, dynamic>> createOrder({
    required String businessId,
    String? branchId,
    String? bookingId,
    String? tableId,
    String orderType = 'PRE_ORDER',
    required List<Map<String, dynamic>> items,
    int discount = 0,
    String? note,
  }) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.orders}');

      final body = {
        'businessId': businessId,
        if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
        if (bookingId != null && bookingId.isNotEmpty) 'bookingId': bookingId,
        if (tableId != null && tableId.isNotEmpty) 'tableId': tableId,
        'orderType': orderType,
        'items': items,
        'discount': discount,
        if (note != null && note.isNotEmpty) 'note': note,
      };

      debugPrint('[OrderService] -> POST $uri');
      final res = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final model = data['data'] != null ? OrderModel.fromJson(data['data']) : null;
        return {
          'success': true,
          'order': model,
          'orderCode': model?.orderCode,
          'message': 'Đặt món thành công!',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Đặt món thất bại (${res.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('[OrderService createOrder Error]: $e');
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  /// 2. Khách hàng xem danh sách đơn hàng của mình (GET /api/orders/me)
  Future<List<OrderModel>> getMyOrders() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.myOrders}');

      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['data'] as List<dynamic>?) ?? [];
        return list.map((item) => OrderModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[OrderService getMyOrders Error]: $e');
    }
    return [];
  }

  /// 3. Xem chi tiết đơn hàng (GET /api/orders/:id)
  Future<OrderModel?> getOrderById(String id) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.orders}/$id');

      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['data'] != null) {
          return OrderModel.fromJson(data['data']);
        }
      }
    } catch (e) {
      debugPrint('[OrderService getOrderById Error]: $e');
    }
    return null;
  }

  /// 4. Chủ quán xem danh sách đơn hàng của quán (GET /api/owner/orders)
  Future<List<OrderModel>> getOwnerOrders({String? status, String? orderType}) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty && status != 'ALL') {
        queryParams['status'] = status;
      }
      if (orderType != null && orderType.isNotEmpty) {
        queryParams['orderType'] = orderType;
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.ownerOrders}')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['data'] as List<dynamic>?) ?? [];
        return list.map((item) => OrderModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[OrderService getOwnerOrders Error]: $e');
    }
    return [];
  }

  /// 5. Chủ quán cập nhật tiến độ đơn hàng (PUT /api/owner/orders/:id/status)
  /// Flow: PENDING -> CONFIRMED -> PREPARING -> READY -> SERVED -> COMPLETED (hoặc CANCELLED)
  Future<Map<String, dynamic>> updateOrderStatus(String id, String status) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.ownerOrders}/$id/status');

      debugPrint('[OrderService] -> PUT $uri with status: $status');
      final res = await http
          .put(uri, headers: headers, body: jsonEncode({'status': status}))
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final model = data['data'] != null ? OrderModel.fromJson(data['data']) : null;
        return {'success': true, 'order': model, 'message': 'Cập nhật trạng thái thành công!'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Cập nhật thất bại (${res.statusCode})'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }
}

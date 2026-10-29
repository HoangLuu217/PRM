import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/order_model.dart';

class CheckoutService {
  final String baseUrl;

  CheckoutService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConstants.baseUrl;

  Map<String, String> _headers(String token) {
    return {
      'Content-Type': 'application/json',
      'Bypass-Tunnel-Reminder': 'true',
      'Authorization': 'Bearer $token',
    };
  }

  /// Create new order (Submit checkout)
  Future<OrderModel> createOrder(Map<String, dynamic> orderPayload, String token) async {
    final uri = Uri.parse('$baseUrl/orders');
    final response = await http
        .post(
          uri,
          headers: _headers(token),
          body: jsonEncode(orderPayload),
        )
        .timeout(const Duration(seconds: 25));

    final body = jsonDecode(response.body);
    if (response.statusCode == 201 || response.statusCode == 200) {
      if (body['success'] == true && body['data'] != null) {
        return OrderModel.fromJson(body['data'] as Map<String, dynamic>);
      }
    }
    final message = body['message'] ?? 'Đặt hàng không thành công';
    throw Exception(message);
  }

  /// Fetch user's order history
  Future<List<OrderModel>> getMyOrders(String token) async {
    final uri = Uri.parse('$baseUrl/orders/my');
    final response = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] is List) {
        final list = body['data'] as List<dynamic>;
        return list.map((item) => OrderModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    }
    return [];
  }

  /// Check PayOS payment status by orderCode
  Future<bool> checkPaymentStatus(dynamic orderCode, String token) async {
    try {
      final uri = Uri.parse('$baseUrl/payments/status/$orderCode');
      final response = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data']?['isPaid'] == true || body['data']?['status'] == 'PAID';
      }
    } catch (_) {}
    return false;
  }
}

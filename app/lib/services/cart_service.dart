import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/cart_item_model.dart';

class CartService {
  final String baseUrl;

  CartService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConstants.baseUrl;

  Map<String, String> _headers(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Get user cart for a specific branch
  Future<List<CartItemModel>> getCart(String branchId, String token) async {
    final uri = Uri.parse('$baseUrl/carts/$branchId');
    final response = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        final itemsData = body['data']['items'] as List<dynamic>? ?? [];
        return itemsData.map((i) => CartItemModel.fromJson(i as Map<String, dynamic>)).toList();
      }
    }
    return [];
  }

  /// Update / Sync cart items on backend
  Future<List<CartItemModel>> updateCart(String branchId, List<CartItemModel> items, String token) async {
    final uri = Uri.parse('$baseUrl/carts/$branchId');
    final payload = {
      'items': items.map((item) {
        return {
          'productId': item.product.id,
          'quantity': item.quantity,
          if (item.selectedSize != null) 'selectedSize': item.selectedSize!.toJson(),
          'selectedOptions': item.selectedOptions.map((o) => o.toJson()).toList(),
        };
      }).toList(),
    };

    final response = await http
        .put(
          uri,
          headers: _headers(token),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        final itemsData = body['data']['items'] as List<dynamic>? ?? [];
        return itemsData.map((i) => CartItemModel.fromJson(i as Map<String, dynamic>)).toList();
      }
    }
    throw Exception('Không thể cập nhật giỏ hàng trên máy chủ');
  }

  /// Clear cart for a branch
  Future<bool> clearCart(String branchId, String token) async {
    final uri = Uri.parse('$baseUrl/carts/$branchId');
    final response = await http.delete(uri, headers: _headers(token)).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['success'] == true;
    }
    return false;
  }
}

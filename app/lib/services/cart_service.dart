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

  /// GET /api/cart or GET /api/carts/:branchId
  Future<List<CartItemModel>> getCart(String branchId, String token) async {
    final uri = Uri.parse('$baseUrl/cart').replace(queryParameters: {'branchId': branchId});
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

  /// POST /api/cart - Add item to cart
  Future<bool> addToCart(
    CartItemModel item,
    String token, {
    String? branchId,
    String? businessId,
  }) async {
    final uri = Uri.parse('$baseUrl/cart');
    final payload = {
      'productId': item.product.id,
      'quantity': item.quantity,
      if (item.selectedSize != null) 'selectedSize': item.selectedSize!.toJson(),
      'selectedOptions': item.selectedOptions.map((o) => o.toJson()).toList(),
      if (branchId != null) 'branchId': branchId,
      if (businessId != null) 'businessId': businessId,
    };

    final response = await http
        .post(
          uri,
          headers: _headers(token),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 10));

    final body = jsonDecode(response.body);
    return response.statusCode == 201 || response.statusCode == 200 || body['success'] == true;
  }

  /// PUT /api/cart - Update / Sync cart items on backend
  Future<List<CartItemModel>> updateCart(String branchId, List<CartItemModel> items, String token) async {
    final uri = Uri.parse('$baseUrl/cart');
    final payload = {
      'branchId': branchId,
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

  /// DELETE /api/cart/:itemId - Delete single item from cart
  Future<bool> deleteCartItem(String itemId, String token) async {
    final uri = Uri.parse('$baseUrl/cart/$itemId');
    final response = await http.delete(uri, headers: _headers(token)).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['success'] == true;
    }
    return false;
  }

  /// DELETE /api/cart - Clear cart
  Future<bool> clearCart(String branchId, String token) async {
    final uri = Uri.parse('$baseUrl/cart').replace(queryParameters: {'branchId': branchId});
    final response = await http.delete(uri, headers: _headers(token)).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['success'] == true;
    }
    return false;
  }
}

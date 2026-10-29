import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/product_model.dart';

class ProductService {
  final String baseUrl;

  ProductService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConstants.baseUrl;

  Map<String, String> _headers([String? token]) {
    final headers = {
      'Content-Type': 'application/json',
      'Bypass-Tunnel-Reminder': 'true',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Get products list filtered by businessId, branchId, menuId, category, includeUnavailable
  Future<List<ProductModel>> getProducts({
    String? businessId,
    String? branchId,
    String? menuId,
    String? category,
    bool includeUnavailable = false,
  }) async {
    final queryParams = <String, String>{};
    if (businessId != null && businessId.isNotEmpty) queryParams['businessId'] = businessId;
    if (branchId != null && branchId.isNotEmpty) queryParams['branchId'] = branchId;
    if (menuId != null && menuId.isNotEmpty) queryParams['menuId'] = menuId;
    if (category != null && category.isNotEmpty) queryParams['category'] = category;
    if (includeUnavailable) queryParams['includeUnavailable'] = 'true';

    final uri = Uri.parse('$baseUrl/products').replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] is List) {
        final list = body['data'] as List<dynamic>;
        return list.map((item) => ProductModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    }
    throw Exception('Không thể tải danh sách sản phẩm (${response.statusCode})');
  }

  /// Get single product by ID
  Future<ProductModel> getProductById(String id) async {
    final uri = Uri.parse('$baseUrl/products/$id');
    final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        return ProductModel.fromJson(body['data'] as Map<String, dynamic>);
      }
    }
    throw Exception('Không tìm thấy thông tin sản phẩm');
  }

  /// Create new product (Owner / Staff)
  Future<ProductModel> createProduct(ProductModel product, String token) async {
    final uri = Uri.parse('$baseUrl/products');
    final response = await http
        .post(
          uri,
          headers: _headers(token),
          body: jsonEncode(product.toJson()),
        )
        .timeout(const Duration(seconds: 10));

    final body = jsonDecode(response.body);
    if (response.statusCode == 201 || response.statusCode == 200) {
      if (body['success'] == true && body['data'] != null) {
        return ProductModel.fromJson(body['data'] as Map<String, dynamic>);
      }
    }
    final message = body['message'] ?? 'Không thể tạo món ăn mới';
    throw Exception(message);
  }

  /// Update existing product (Owner / Staff)
  Future<ProductModel> updateProduct(String id, Map<String, dynamic> updateData, String token) async {
    final uri = Uri.parse('$baseUrl/products/$id');
    final response = await http
        .put(
          uri,
          headers: _headers(token),
          body: jsonEncode(updateData),
        )
        .timeout(const Duration(seconds: 10));

    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      if (body['success'] == true && body['data'] != null) {
        return ProductModel.fromJson(body['data'] as Map<String, dynamic>);
      }
    }
    final message = body['message'] ?? 'Không thể cập nhật món ăn';
    throw Exception(message);
  }

  /// Delete product (Owner / Staff)
  Future<bool> deleteProduct(String id, String token) async {
    final uri = Uri.parse('$baseUrl/products/$id');
    final response = await http
        .delete(
          uri,
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['success'] == true;
    }
    final body = jsonDecode(response.body);
    throw Exception(body['message'] ?? 'Không thể xóa món ăn');
  }
}

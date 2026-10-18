import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/restaurant_model.dart';
import 'auth_service.dart';

class FavoriteService {
  final AuthService _authService = AuthService();

  Map<String, String> _headers([String? token]) {
    final map = {
      'Content-Type': 'application/json',
      'Bypass-Tunnel-Reminder': 'true',
    };
    if (token != null && token.isNotEmpty) {
      map['Authorization'] = 'Bearer $token';
    }
    return map;
  }

  /// 1. Lấy danh sách quán ăn yêu thích của người dùng
  Future<List<RestaurantModel>> getFavorites() async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) return [];

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.favorites}');
      final response = await http
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['data'] as List<dynamic>?) ?? [];
        final List<RestaurantModel> restaurants = [];

        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final bizData = item['business'] ?? item['businessId'];
            if (bizData is Map<String, dynamic>) {
              restaurants.add(RestaurantModel.fromJson(bizData));
            }
          }
        }
        return restaurants;
      }
    } catch (e) {
      debugPrint('[FavoriteService Error getFavorites]: $e');
    }
    return [];
  }

  /// 2. Lấy danh sách ID các quán đã yêu thích để kiểm tra nhanh
  Future<Set<String>> getFavoriteIds() async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) return {};

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.favorites}/ids');
      final response = await http
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['data'] as List<dynamic>?) ?? [];
        return list.map((e) => e.toString()).toSet();
      }
    } catch (e) {
      debugPrint('[FavoriteService Error getFavoriteIds]: $e');
    }
    return {};
  }

  /// 3. Thêm quán vào danh sách yêu thích
  Future<Map<String, dynamic>> addFavorite(String businessId) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Vui lòng đăng nhập để lưu quán yêu thích'};
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.favorites}');
      final response = await http
          .post(
            uri,
            headers: _headers(token),
            body: jsonEncode({'businessId': businessId}),
          )
          .timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200 || response.statusCode == 201,
        'message': data['message'] ?? 'Đã thêm vào danh sách yêu thích',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  /// 4. Xóa quán khỏi danh sách yêu thích
  Future<Map<String, dynamic>> removeFavorite(String businessId) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Vui lòng đăng nhập'};
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.favorites}/$businessId');
      final response = await http
          .delete(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Đã xóa khỏi danh sách yêu thích',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  /// 5. Kiểm tra trạng thái yêu thích
  Future<bool> checkFavorite(String businessId) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) return false;

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.favorites}/check/$businessId');
      final response = await http
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['isFavorite'] == true;
      }
    } catch (_) {}
    return false;
  }
}

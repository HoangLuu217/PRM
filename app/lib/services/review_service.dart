import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/review_model.dart';
import 'auth_service.dart';

class ReviewService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// 1. Lấy danh sách đánh giá thực tế của một quán (Public GET /api/reviews/business/:businessId)
  Future<List<ReviewModel>> getBusinessReviews(String businessId) async {
    if (businessId.isEmpty) return [];
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.reviews}/business/$businessId');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data['success'] == true && data['data'] is List) {
          final list = (data['data'] as List)
              .map((json) => ReviewModel.fromJson(json as Map<String, dynamic>))
              .toList();
          return list;
        }
      }
      return [];
    } catch (e) {
      debugPrint('[ReviewService] getBusinessReviews error: $e');
      return [];
    }
  }

  /// 2. Tạo đánh giá thực tế từ khách hàng (POST /api/reviews)
  Future<Map<String, dynamic>> createReview({
    required String businessId,
    String? branchId,
    String? bookingId,
    String? orderId,
    required double rating,
    required String content,
    List<String>? images,
  }) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.reviews}');

      final body = {
        'businessId': businessId,
        if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
        if (bookingId != null && bookingId.isNotEmpty) 'bookingId': bookingId,
        if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
        'rating': rating,
        'content': content.trim(),
        'images': images ?? [],
      };

      final res = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return {
          'success': true,
          'data': data['data'] != null ? ReviewModel.fromJson(data['data']) : null,
          'message': 'Gửi đánh giá thành công!',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Không thể gửi đánh giá',
        };
      }
    } catch (e) {
      debugPrint('[ReviewService] createReview error: $e');
      return {
        'success': false,
        'message': 'Lỗi kết nối máy chủ: $e',
      };
    }
  }

  /// 3. Chủ quán đồng bộ đánh giá từ Google Maps (POST /api/businesses/:id/sync-google-reviews)
  Future<Map<String, dynamic>> syncGoogleReviews(String businessId, {String? googleMapsUrl}) async {
    try {
      final headers = await _getHeaders();
      final targetId = businessId.trim();
      final uri = targetId.isNotEmpty
          ? Uri.parse('//sync-google-reviews')
          : Uri.parse('/sync-google-reviews');

      final body = <String, dynamic>{};
      if (googleMapsUrl != null && googleMapsUrl.trim().isNotEmpty) {
        body['googleMapsUrl'] = googleMapsUrl.trim();
      }

      final res = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 25));

      final rawBody = utf8.decode(res.bodyBytes).trim();
      if (!rawBody.startsWith('{')) {
        return {
          'success': false,
          'message': 'Không thể kết nối tới dịch vụ đồng bộ (Mã lỗi: ). Vui lòng hoàn tất hồ sơ quán trước.',
        };
      }

      final data = jsonDecode(rawBody);
      if (res.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'] ?? 'Đồng bộ đánh giá Google Maps thành công!',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Đồng bộ thất bại. Vui lòng kiểm tra liên kết Google Maps.',
        };
      }
    } catch (e) {
      debugPrint('[ReviewService] syncGoogleReviews error: $e');
      return {
        'success': false,
        'message': 'Lỗi kết nối đồng bộ: $e',
      };
    }
  }
}


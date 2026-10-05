import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/restaurant_model.dart';
import 'auth_service.dart';

class RestaurantService {
  final AuthService _authService = AuthService();

  // Bảng ánh xạ danh mục tiếng Việt sang mã category chuẩn của Backend
  static const Map<String, String> _categoryMap = {
    'Hải Sản': 'RESTAURANT',
    'Nhà Hàng': 'RESTAURANT',
    'Cà Phê': 'CAFE',
    'Lẩu Nướng BBQ': 'BBQ',
    'BBQ': 'BBQ',
    'Buffet': 'BUFFET',
    'Tiệm Bánh': 'BAKERY',
    'Trà Sữa': 'MILK_TEA',
    'Chè & Tráng Miệng': 'DESSERT',
    'Thức Ăn Nhanh': 'FAST_FOOD',
    'Bar & Pub': 'BAR',
  };

  // 1. Lấy danh sách quán ăn từ Backend REST API (Kết nối trực tiếp MongoDB Atlas qua Express Server)
  Future<List<RestaurantModel>> getRestaurants({
    String city = 'Đà Nẵng',
    String? keyword,
    String? category,
    String? vibe,
    String? purpose,
    double? lat,
    double? lng,
  }) async {
    try {
      final queryParams = <String, String>{};

      // Tọa độ GPS người dùng để tính khoảng cách và định vị gần nhất
      if (lat != null && lng != null) {
        queryParams['lat'] = lat.toString();
        queryParams['lng'] = lng.toString();
      }

      // Địa điểm thành phố
      if (city.isNotEmpty && city != 'Tất cả') {
        queryParams['city'] = city;
      }

      // Từ khóa tìm kiếm
      if (keyword != null && keyword.trim().isNotEmpty) {
        queryParams['keyword'] = keyword.trim();
      }

      // Danh mục
      if (category != null && category != 'ALL' && category != 'Tất cả' && category != 'Danh mục') {
        final mapped = _categoryMap[category];
        if (mapped != null) {
          queryParams['category'] = mapped;
        } else {
          queryParams['keyword'] = category;
        }
      }

      // Không gian
      if (vibe != null && vibe.isNotEmpty && vibe != 'Tất cả' && vibe != 'Không gian') {
        queryParams['vibe'] = vibe;
      }

      // Mục đích bữa ăn
      if (purpose != null && purpose.isNotEmpty && purpose != 'Tất cả' && purpose != 'Mục đích') {
        queryParams['purpose'] = purpose;
      }

      final url = '${ApiConstants.baseUrl}${ApiConstants.businesses}';
      final uri = Uri.parse(url).replace(queryParameters: queryParams);

      debugPrint('[RestaurantService] -> Gọi API: $uri');

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      debugPrint('[RestaurantService] <- Nhận mã HTTP: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['data'] as List<dynamic>?) ?? (data is List ? data : null);

        if (list != null) {
          final items = list
              .map((item) => RestaurantModel.fromJson(item as Map<String, dynamic>))
              .toList();
          debugPrint('[RestaurantService] -> Tải thành công ${items.length} quán ăn từ API!');
          return items;
        }
      } else {
        debugPrint('[RestaurantService Error]: HTTP ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[RestaurantService API Error]: $e');
    }

    return [];
  }

  // 2. Tạo đơn đặt bàn gửi lên Backend API (Lưu vào bảng Booking trên MongoDB)
  Future<Map<String, dynamic>> createBooking({
    required String businessId,
    required String bookingDate,
    required String startTime,
    required int guestCount,
    String? note,
  }) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.bookings}');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'businessId': businessId,
          'bookingDate': bookingDate,
          'startTime': startTime,
          'guestCount': guestCount,
          'note': note ?? 'Đặt bàn qua ứng dụng FConnect Mobile',
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'bookingCode': data['data']?['bookingCode'] ??
              data['booking']?['bookingCode'] ??
              'FCB${DateTime.now().millisecondsSinceEpoch}',
          'message': data['message'] ?? 'Đặt bàn thành công!',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Không thể đặt bàn, vui lòng thử lại',
        };
      }
    } catch (e) {
      debugPrint('[Booking Error]: $e');
      return {
        'success': false,
        'message': 'Không thể kết nối máy chủ đặt bàn: $e',
      };
    }
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/restaurant_model.dart';

class RestaurantService {
  // Danh sách các quán ăn nổi bật tại Đà Nẵng (Fallback khi API rỗng hoặc chưa seed)
  static final List<RestaurantModel> _fallbackRestaurants = [
    RestaurantModel(
      id: 'mock_1',
      name: 'Hải Sản Bé Mặn (Mỹ Khê)',
      description: 'Hải sản tươi sống bắt tại bể uy tín bậc nhất bờ biển Mỹ Khê Đà Nẵng. Không gian rộng rãi, thoáng đãng đón gió biển.',
      categories: ['Hải Sản', 'Nhà Hàng', 'Buffet'],
      vibes: ['Ngoài trời', 'Gần biển', 'Nhóm đông'],
      purposes: ['Gia đình', 'Bạn bè', 'Tiếp khách'],
      minPrice: 150000,
      maxPrice: 600000,
      rating: 4.8,
      totalReviews: 312,
      googleRating: 4.6,
      googleTotalReviews: 3450,
      address: 'Lô 11 Võ Nguyên Giáp, Sơn Trà, Đà Nẵng',
      district: 'Sơn Trà',
      city: 'Đà Nẵng',
      phone: '0905 207 848',
      coverImageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=800&q=80',
      logoUrl: 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80',
      aiMatchScore: 98.5,
    ),
    RestaurantModel(
      id: 'mock_2',
      name: "Pizza 4P's - Hoàng Văn Thụ",
      description: 'Pizza phô mai Burrata tươi thủ công, mì Ý cua kem nức tiếng và dịch vụ chuẩn Omotenashi Nhật Bản.',
      categories: ['Pizza & Mì Ý', 'Âu - Mỹ', 'Nhà Hàng'],
      vibes: ['Lãng mạn', 'Ấm cúng', 'Máy lạnh'],
      purposes: ['Hẹn hò', 'Gia đình', 'Kỷ niệm'],
      minPrice: 120000,
      maxPrice: 450000,
      rating: 4.9,
      totalReviews: 480,
      googleRating: 4.7,
      googleTotalReviews: 4200,
      address: '08 Hoàng Văn Thụ, Phước Ninh, Hải Châu, Đà Nẵng',
      district: 'Hải Châu',
      city: 'Đà Nẵng',
      phone: '028 3622 0500',
      coverImageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=800&q=80',
      logoUrl: 'https://images.unsplash.com/photo-1579758629938-03607ccdbaba?auto=format&fit=crop&w=400&q=80',
      aiMatchScore: 97.0,
    ),
    RestaurantModel(
      id: 'mock_3',
      name: 'Bếp Trang - Mì Quảng Ếch',
      description: 'Mì Quảng ếch số 1 Đà Nẵng, phục vụ trên mẹt tre truyền thống cùng nước nhưn ếch om sả nghệ thơm lừng.',
      categories: ['Đặc Sản', 'Mì Quảng', 'Quán Ăn'],
      vibes: ['Truyền thống', 'Ấm cúng', 'Sân vườn'],
      purposes: ['Gia đình', 'Du lịch', 'Ăn sáng'],
      minPrice: 45000,
      maxPrice: 120000,
      rating: 4.7,
      totalReviews: 260,
      googleRating: 4.5,
      googleTotalReviews: 1890,
      address: '441 Ông Ích Khiêm, Nam Dương, Hải Châu, Đà Nẵng',
      district: 'Hải Châu',
      city: 'Đà Nẵng',
      phone: '0901 151 543',
      coverImageUrl: 'https://images.unsplash.com/photo-1569058242253-92a9c755a0ec?auto=format&fit=crop&w=800&q=80',
      logoUrl: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=400&q=80',
      aiMatchScore: 95.8,
    ),
    RestaurantModel(
      id: 'mock_4',
      name: 'Cơm Gà A Hải (Cơm Gà Quay Giòn)',
      description: 'Cơm gà xối mỡ trứ danh với lớp da giòn rụm, thịt mềm mọng nước, hạt cơm vàng óng dẻo bùi.',
      categories: ['Cơm Gà', 'Quán Ăn', 'Bình Dân'],
      vibes: ['Nhanh gọn', 'Nhộn nhịp', 'Máy lạnh'],
      purposes: ['Bữa trưa', 'Gia đình', 'Bạn bè'],
      minPrice: 50000,
      maxPrice: 110000,
      rating: 4.6,
      totalReviews: 390,
      googleRating: 4.4,
      googleTotalReviews: 2100,
      address: '96 Phan Châu Trinh, Phước Ninh, Hải Châu, Đà Nẵng',
      district: 'Hải Châu',
      city: 'Đà Nẵng',
      phone: '0905 312 642',
      coverImageUrl: 'https://images.unsplash.com/photo-1600891964599-f61ba0e24092?auto=format&fit=crop&w=800&q=80',
      logoUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=80',
      aiMatchScore: 94.2,
    ),
    RestaurantModel(
      id: 'mock_5',
      name: 'Highlands Coffee - VTV8 Bạch Đằng',
      description: 'Không gian ngắm trọn dòng sông Hàn thơ mộng và cầu Rồng lung linh, thưởng thức Phin Sữa Đá đậm đà.',
      categories: ['Cà Phê', 'Trà & Bánh', 'View Đẹp'],
      vibes: ['View sông', 'Thoáng đãng', 'Máy lạnh'],
      purposes: ['Làm việc', 'Tụ tập bạn bè', 'Check-in'],
      minPrice: 29000,
      maxPrice: 75000,
      rating: 4.8,
      totalReviews: 540,
      googleRating: 4.6,
      googleTotalReviews: 3100,
      address: '258 Bạch Đằng, Phước Ninh, Hải Châu, Đà Nẵng',
      district: 'Hải Châu',
      city: 'Đà Nẵng',
      phone: '0236 3840 000',
      coverImageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=800&q=80',
      logoUrl: 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=400&q=80',
      aiMatchScore: 93.5,
    ),
    RestaurantModel(
      id: 'mock_6',
      name: 'Bánh Xèo Tôm Nhảy Cô Ba',
      description: 'Bánh xèo vỏ giòn rụm, tôm đất nhảy tanh tách ngọt lịm cuốn rau sống bánh tráng và nước chấm gan heo béo ngậy.',
      categories: ['Đặc Sản', 'Ăn Vặt', 'Bình Dân'],
      vibes: ['Vỉa hè sạch sẽ', 'Bình dân', 'Ấm cúng'],
      purposes: ['Ăn xế', 'Bạn bè', 'Du lịch'],
      minPrice: 35000,
      maxPrice: 90000,
      rating: 4.8,
      totalReviews: 210,
      googleRating: 4.6,
      googleTotalReviews: 1250,
      address: '248 Trưng Nữ Vương, Bình Thuận, Hải Châu, Đà Nẵng',
      district: 'Hải Châu',
      city: 'Đà Nẵng',
      phone: '0905 123 456',
      coverImageUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=800&q=80',
      logoUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=400&q=80',
      aiMatchScore: 96.2,
    ),
  ];

  // Lấy danh sách quán ăn từ Backend API hoặc dùng fallback
  Future<List<RestaurantModel>> getRestaurants({
    String city = 'Đà Nẵng',
    String? keyword,
    String? category,
    String? vibe,
    String? purpose,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (city.isNotEmpty && city != 'Tất cả') {
        queryParams['city'] = city;
      }
      if (keyword != null && keyword.trim().isNotEmpty) {
        queryParams['keyword'] = keyword.trim();
      }
      if (category != null && category != 'ALL' && category != 'Tất cả') {
        queryParams['category'] = category;
      }
      if (vibe != null && vibe.isNotEmpty) {
        queryParams['vibe'] = vibe;
      }
      if (purpose != null && purpose.isNotEmpty) {
        queryParams['purpose'] = purpose;
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/businesses').replace(queryParameters: queryParams);
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['data'] as List<dynamic>?) ?? (data is List ? data : null);

        if (list != null && list.isNotEmpty) {
          return list.map((item) => RestaurantModel.fromJson(item as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      debugPrint('[RestaurantService Error]: $e -> Dùng danh sách mẫu chuẩn Đà Nẵng');
    }

    // Lọc fallback data dựa trên filter người dùng chọn
    var results = List<RestaurantModel>.from(_fallbackRestaurants);

    if (keyword != null && keyword.trim().isNotEmpty) {
      final q = keyword.trim().toLowerCase();
      results = results.where((r) =>
        r.name.toLowerCase().contains(q) ||
        r.description.toLowerCase().contains(q) ||
        r.address.toLowerCase().contains(q) ||
        r.categories.any((c) => c.toLowerCase().contains(q))
      ).toList();
    }

    if (category != null && category != 'ALL' && category != 'Tất cả' && category != 'Danh mục') {
      results = results.where((r) =>
        r.categories.any((c) => c.toLowerCase().contains(category.toLowerCase()))
      ).toList();
    }

    if (vibe != null && vibe.isNotEmpty && vibe != 'Không gian') {
      results = results.where((r) =>
        r.vibes.any((v) => v.toLowerCase().contains(vibe.toLowerCase()))
      ).toList();
    }

    if (purpose != null && purpose.isNotEmpty && purpose != 'Mục đích') {
      results = results.where((r) =>
        r.purposes.any((p) => p.toLowerCase().contains(purpose.toLowerCase()))
      ).toList();
    }

    return results;
  }
}

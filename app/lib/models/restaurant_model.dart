class RestaurantModel {
  final String id;
  final String name;
  final String description;
  final String? logoUrl;
  final String? coverImageUrl;
  final List<String> categories;
  final String? primaryCategoryName;
  final List<String> vibes;
  final List<String> purposes;
  final int minPrice;
  final int maxPrice;
  final double? _rating;
  final int totalReviews;
  final double? googleRating;
  final int? googleTotalReviews;
  final String address;
  final String district;
  final String city;
  final String? phone;
  final double? aiMatchScore;
  final String? recommendationReason;
  final String? distanceText;
  final String? openTime;
  final String? closeTime;
  final bool isBookingEnabled;
  final double? _latitude;
  final double? _longitude;

  double get rating => _rating ?? 4.8;
  double get latitude => _latitude ?? 16.0544;
  double get longitude => _longitude ?? 108.2022;

  RestaurantModel({
    required this.id,
    required this.name,
    required this.description,
    this.logoUrl,
    this.coverImageUrl,
    this.categories = const [],
    this.primaryCategoryName,
    this.vibes = const [],
    this.purposes = const [],
    this.minPrice = 50000,
    this.maxPrice = 300000,
    double? rating,
    this.totalReviews = 100,
    this.googleRating,
    this.googleTotalReviews,
    this.address = 'Đà Nẵng',
    this.district = 'Hải Châu',
    this.city = 'Đà Nẵng',
    this.phone,
    this.aiMatchScore,
    this.recommendationReason,
    this.distanceText,
    this.openTime,
    this.closeTime,
    this.isBookingEnabled = true,
    double? latitude,
    double? longitude,
  })  : _rating = rating ?? 4.8,
        _latitude = latitude ?? 16.0544,
        _longitude = longitude ?? 108.2022;

  factory RestaurantModel.fromJson(Map<String, dynamic> json) {
    final priceRange = json['priceRange'] is Map ? json['priceRange'] : {};
    final ratingSummary = json['ratingSummary'] is Map ? json['ratingSummary'] : {};
    final google = json['googleRating'] is Map ? json['googleRating'] : {};

    // 1. Phân giải địa chỉ, toạ độ GPS và số điện thoại từ addressText hoặc branches
    String addr = json['addressText']?.toString() ?? '';
    String dist = 'Hải Châu';
    String cty = 'Đà Nẵng';
    String? phn;
    double lat = 16.0544; // Mặc định trung tâm Đà Nẵng
    double lng = 108.2022;

    final primaryBranch = json['primaryBranch'] is Map ? json['primaryBranch'] : null;
    final branches = json['branches'] is List ? json['branches'] as List : null;
    final targetBranch = primaryBranch ?? (branches != null && branches.isNotEmpty ? branches[0] : null);

    if (targetBranch is Map) {
      if (addr.isEmpty && targetBranch['address'] is Map) {
        final a = targetBranch['address'];
        final street = a['street']?.toString() ?? '';
        final ward = a['ward']?.toString() ?? '';
        final district = a['district']?.toString() ?? '';
        final parts = [street, ward, district].where((s) => s.isNotEmpty).toList();
        addr = parts.isNotEmpty ? parts.join(', ') : 'Đà Nẵng';
        dist = a['district']?.toString() ?? dist;
        cty = a['city']?.toString() ?? cty;
      }
      phn = targetBranch['phone']?.toString();

      // Parse coordinates GeoJSON: [longitude, latitude]
      if (targetBranch['location'] is Map && targetBranch['location']['coordinates'] is List) {
        final coords = targetBranch['location']['coordinates'] as List;
        if (coords.length >= 2) {
          final pLng = (coords[0] as num?)?.toDouble();
          final pLat = (coords[1] as num?)?.toDouble();
          if (pLat != null && pLng != null && pLat != 0.0 && pLng != 0.0) {
            lat = pLat;
            lng = pLng;
          }
        }
      }
    }

    // Fallback coordinates từ json['location'] hoặc json['latitude']
    if (lat == 16.0544 && lng == 108.2022) {
      if (json['location'] is Map && json['location']['coordinates'] is List) {
        final coords = json['location']['coordinates'] as List;
        if (coords.length >= 2) {
          final pLng = (coords[0] as num?)?.toDouble();
          final pLat = (coords[1] as num?)?.toDouble();
          if (pLat != null && pLng != null && pLat != 0.0 && pLng != 0.0) {
            lat = pLat;
            lng = pLng;
          }
        }
      } else if (json['latitude'] != null && json['longitude'] != null) {
        final pLat = (json['latitude'] as num?)?.toDouble();
        final pLng = (json['longitude'] as num?)?.toDouble();
        if (pLat != null && pLng != null) {
          lat = pLat;
          lng = pLng;
        }
      }
    }

    if (addr.isEmpty) {
      addr = 'Đà Nẵng';
    }

    // 2. Danh mục
    final rawCats = (json['categories'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final categoryDisplayName = json['category']?.toString();

    // 3. AI Score
    final aiScore = (json['matchPercentage'] as num?)?.toDouble() ??
        (json['personalizedScore'] as num?)?.toDouble() ??
        (json['aiScore'] as num?)?.toDouble() ??
        (json['popularityScore'] as num?)?.toDouble() ??
        95.0;

    return RestaurantModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Quán ăn ngon',
      description: json['description']?.toString() ?? '',
      logoUrl: json['logoUrl']?.toString(),
      coverImageUrl: json['coverImageUrl']?.toString() ?? json['imageUrl']?.toString(),
      categories: rawCats,
      primaryCategoryName: categoryDisplayName,
      vibes: (json['vibes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      purposes: (json['purposes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      minPrice: (priceRange['min'] as num?)?.toInt() ?? 50000,
      maxPrice: (priceRange['max'] as num?)?.toInt() ?? 300000,
      rating: (ratingSummary['average'] as num?)?.toDouble() ?? 4.8,
      totalReviews: (ratingSummary['totalReviews'] as num?)?.toInt() ?? 50,
      googleRating: (google['rating'] as num?)?.toDouble() ?? 4.6,
      googleTotalReviews: (google['userRatingsTotal'] as num?)?.toInt() ?? 200,
      address: addr,
      district: dist,
      city: cty,
      phone: phn ?? json['phone']?.toString(),
      aiMatchScore: aiScore,
      recommendationReason: json['recommendationReason']?.toString(),
      distanceText: json['distanceText']?.toString(),
      openTime: json['openTime']?.toString() ?? '07:00',
      closeTime: json['closeTime']?.toString() ?? '22:30',
      isBookingEnabled: json['isBookingEnabled'] != false,
      latitude: lat,
      longitude: lng,
    );
  }

  // Tên danh mục hiển thị tiếng Việt đẹp mắt
  String get displayCategory {
    if (primaryCategoryName != null && primaryCategoryName!.isNotEmpty) {
      return primaryCategoryName!;
    }
    if (categories.isEmpty) return 'Ẩm thực';

    final first = categories.first.toUpperCase();
    switch (first) {
      case 'RESTAURANT':
        return 'Nhà hàng';
      case 'CAFE':
        return 'Cà phê';
      case 'BBQ':
        return 'Lẩu nướng BBQ';
      case 'BUFFET':
        return 'Buffet';
      case 'BAKERY':
        return 'Tiệm bánh';
      case 'MILK_TEA':
        return 'Trà sữa';
      case 'DESSERT':
        return 'Chè & Tráng miệng';
      case 'FAST_FOOD':
        return 'Thức ăn nhanh';
      case 'BAR':
        return 'Bar & Pub';
      default:
        return categories.first;
    }
  }

  String get formattedPrice {
    final minK = (minPrice / 1000).round();
    final maxK = (maxPrice / 1000).round();
    return '${minK}k - ${maxK}k';
  }
}

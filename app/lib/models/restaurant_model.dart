class RestaurantModel {
  final String id;
  final String name;
  final String description;
  final String? logoUrl;
  final String? coverImageUrl;
  final List<String> categories;
  final List<String> vibes;
  final List<String> purposes;
  final int minPrice;
  final int maxPrice;
  final double rating;
  final int totalReviews;
  final double? googleRating;
  final int? googleTotalReviews;
  final String address;
  final String district;
  final String city;
  final String? phone;
  final double? aiMatchScore;

  RestaurantModel({
    required this.id,
    required this.name,
    required this.description,
    this.logoUrl,
    this.coverImageUrl,
    this.categories = const [],
    this.vibes = const [],
    this.purposes = const [],
    this.minPrice = 50000,
    this.maxPrice = 300000,
    this.rating = 4.8,
    this.totalReviews = 100,
    this.googleRating,
    this.googleTotalReviews,
    this.address = 'Đà Nẵng',
    this.district = 'Hải Châu',
    this.city = 'Đà Nẵng',
    this.phone,
    this.aiMatchScore,
  });

  factory RestaurantModel.fromJson(Map<String, dynamic> json) {
    final priceRange = json['priceRange'] is Map ? json['priceRange'] : {};
    final ratingSummary = json['ratingSummary'] is Map ? json['ratingSummary'] : {};
    final google = json['googleRating'] is Map ? json['googleRating'] : {};

    // Xử lý địa chỉ từ branch đầu tiên nếu có
    String addr = 'Đà Nẵng';
    String dist = 'Hải Châu';
    String cty = json['city']?.toString() ?? 'Đà Nẵng';
    String? phn;

    if (json['branches'] is List && (json['branches'] as List).isNotEmpty) {
      final b = json['branches'][0];
      if (b is Map && b['address'] is Map) {
        final a = b['address'];
        addr = '${a['street'] ?? ''}, ${a['ward'] ?? ''}, ${a['district'] ?? ''}'.replaceAll(RegExp(r'^,\s*|,\s*$'), '');
        dist = a['district']?.toString() ?? dist;
        cty = a['city']?.toString() ?? cty;
      }
      phn = b['phone']?.toString();
    } else if (json['address'] != null) {
      if (json['address'] is Map) {
        final a = json['address'];
        addr = '${a['street'] ?? ''}, ${a['district'] ?? ''}'.replaceAll(RegExp(r'^,\s*|,\s*$'), '');
        dist = a['district']?.toString() ?? dist;
      } else {
        addr = json['address'].toString();
      }
    }

    return RestaurantModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Quán ăn ngon',
      description: json['description']?.toString() ?? '',
      logoUrl: json['logoUrl']?.toString(),
      coverImageUrl: json['coverImageUrl']?.toString() ?? json['imageUrl']?.toString(),
      categories: (json['categories'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      vibes: (json['vibes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      purposes: (json['purposes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      minPrice: (priceRange['min'] as num?)?.toInt() ?? 50000,
      maxPrice: (priceRange['max'] as num?)?.toInt() ?? 300000,
      rating: (ratingSummary['average'] as num?)?.toDouble() ?? 4.8,
      totalReviews: (ratingSummary['totalReviews'] as num?)?.toInt() ?? 50,
      googleRating: (google['rating'] as num?)?.toDouble() ?? 4.6,
      googleTotalReviews: (google['userRatingsTotal'] as num?)?.toInt() ?? 200,
      address: addr.isNotEmpty ? addr : 'Đà Nẵng',
      district: dist,
      city: cty,
      phone: phn ?? json['phone']?.toString(),
      aiMatchScore: (json['aiScore'] as num?)?.toDouble() ?? (json['aiMatchPercentage'] as num?)?.toDouble() ?? 96.0,
    );
  }

  String get formattedPrice {
    final minK = (minPrice / 1000).round();
    final maxK = (maxPrice / 1000).round();
    return '${minK}k - ${maxK}k';
  }
}

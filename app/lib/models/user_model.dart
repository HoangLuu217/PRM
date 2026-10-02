class UserPreferences {
  final List<String> favoriteCategories;
  final List<String> preferredAreas;
  final int minPrice;
  final int maxPrice;

  UserPreferences({
    this.favoriteCategories = const [],
    this.preferredAreas = const [],
    this.minPrice = 0,
    this.maxPrice = 1000000,
  });

  factory UserPreferences.fromJson(dynamic json) {
    if (json == null || json is! Map) return UserPreferences();
    final map = Map<String, dynamic>.from(json);
    return UserPreferences(
      favoriteCategories: (map['favoriteCategories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      preferredAreas: (map['preferredAreas'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      minPrice: (map['priceRange']?['min'] ?? map['minPrice'] ?? 0) is num
          ? (map['priceRange']?['min'] ?? map['minPrice'] ?? 0).toInt()
          : 0,
      maxPrice: (map['priceRange']?['max'] ?? map['maxPrice'] ?? 1000000) is num
          ? (map['priceRange']?['max'] ?? map['maxPrice'] ?? 1000000).toInt()
          : 1000000,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'favoriteCategories': favoriteCategories,
      'preferredAreas': preferredAreas,
      'priceRange': {
        'min': minPrice,
        'max': maxPrice,
      },
    };
  }
}

class User {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String role; // "USER", "MERCHANT", "ADMIN", "STAFF"
  final String? avatarUrl;
  final String authProvider;
  final String status;
  final UserPreferences preferences;
  final Map<String, dynamic>? business;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    this.avatarUrl,
    required this.authProvider,
    required this.status,
    UserPreferences? preferences,
    this.business,
  }) : preferences = preferences ?? UserPreferences();

  factory User.fromJson(dynamic json) {
    if (json == null || json is! Map) {
      return User(
        id: '',
        fullName: 'User',
        email: '',
        role: 'USER',
        authProvider: 'LOCAL',
        status: 'ACTIVE',
      );
    }

    final map = Map<String, dynamic>.from(json);

    // Xử lý xác định Role chính xác
    String roleVal = (map['role'] ?? '').toString().toUpperCase().trim();
    if (roleVal.isEmpty) {
      if (map['hasBusiness'] == true || map['business'] != null) {
        roleVal = 'MERCHANT';
      } else {
        roleVal = 'USER';
      }
    }
    if (roleVal == 'OWNER') {
      roleVal = 'MERCHANT';
    }

    final fullNameVal = (map['fullName'] ?? map['full_name'] ?? map['name'] ?? '').toString();
    if (fullNameVal.toLowerCase().contains('chủ quán') || fullNameVal.toLowerCase().contains('owner')) {
      roleVal = 'MERCHANT';
    }

    return User(
      id: (map['_id'] ?? map['id'] ?? '').toString(),
      fullName: fullNameVal,
      email: (map['email'] ?? '').toString(),
      phone: map['phone']?.toString(),
      role: roleVal,
      avatarUrl: map['avatarUrl']?.toString() ??
          map['avatar_url']?.toString() ??
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
      authProvider: (map['authProvider'] ?? map['auth_provider'] ?? 'LOCAL').toString(),
      status: (map['status'] ?? 'ACTIVE').toString(),
      preferences: UserPreferences.fromJson(map['preferences']),
      business: map['business'] is Map ? Map<String, dynamic>.from(map['business']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'avatarUrl': avatarUrl,
      'authProvider': authProvider,
      'status': status,
      'preferences': preferences.toJson(),
      'business': business,
    };
  }
}

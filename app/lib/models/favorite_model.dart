import 'restaurant_model.dart';

class FavoriteModel {
  final String id;
  final String userId;
  final String businessId;
  final RestaurantModel? business;
  final DateTime? createdAt;

  FavoriteModel({
    required this.id,
    required this.userId,
    required this.businessId,
    this.business,
    this.createdAt,
  });

  factory FavoriteModel.fromJson(Map<String, dynamic> json) {
    RestaurantModel? biz;
    String bId = '';

    if (json['business'] is Map<String, dynamic>) {
      biz = RestaurantModel.fromJson(json['business'] as Map<String, dynamic>);
      bId = biz.id;
    } else if (json['businessId'] is Map<String, dynamic>) {
      biz = RestaurantModel.fromJson(json['businessId'] as Map<String, dynamic>);
      bId = biz.id;
    } else if (json['businessId'] is String) {
      bId = json['businessId'] as String;
    }

    return FavoriteModel(
      id: json['_id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      businessId: bId,
      business: biz,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'userId': userId,
    'businessId': businessId,
    'createdAt': createdAt?.toIso8601String(),
  };
}

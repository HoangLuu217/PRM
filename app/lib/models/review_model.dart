class ReviewModel {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String businessId;
  final String? branchId;
  final String? branchName;
  final double rating;
  final String content;
  String get comment => content;
  final List<String> images;
  final bool isVerified;
  final String status;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.businessId,
    this.branchId,
    this.branchName,
    required this.rating,
    required this.content,
    required this.images,
    required this.isVerified,
    required this.status,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    String uName = 'Thực khách FConnect';
    String uAvatar = '';
    String uId = '';

    if (json['userId'] is Map) {
      final u = json['userId'] as Map<String, dynamic>;
      uId = (u['_id'] ?? u['id'])?.toString() ?? '';
      uName = u['fullName']?.toString() ?? 'Thực khách FConnect';
      uAvatar = u['avatarUrl']?.toString() ?? '';
    } else if (json['userId'] != null) {
      uId = json['userId'].toString();
    }

    String? bName;
    String? bId;
    if (json['branchId'] is Map) {
      final b = json['branchId'] as Map<String, dynamic>;
      bId = (b['_id'] ?? b['id'])?.toString();
      bName = b['name']?.toString();
    } else if (json['branchId'] != null) {
      bId = json['branchId'].toString();
    }

    DateTime createdDate = DateTime.now();
    if (json['createdAt'] != null) {
      createdDate = DateTime.tryParse(json['createdAt'].toString())?.toLocal() ?? DateTime.now();
    }

    final rawImages = json['images'];
    final List<String> imgList = [];
    if (rawImages is List) {
      for (final item in rawImages) {
        if (item != null) imgList.add(item.toString());
      }
    }

    return ReviewModel(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      userId: uId,
      userName: uName,
      userAvatar: uAvatar,
      businessId: (json['businessId'] is Map ? json['businessId']['_id'] : json['businessId'])?.toString() ?? '',
      branchId: bId,
      branchName: bName,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      content: json['content']?.toString() ?? '',
      images: imgList,
      isVerified: json['isVerified'] == true,
      status: json['status']?.toString() ?? 'PUBLISHED',
      createdAt: createdDate,
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()} tháng trước';
    } else if (diff.inDays > 7) {
      return '${(diff.inDays / 7).floor()} tuần trước';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} ngày trước';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} giờ trước';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
  }
}


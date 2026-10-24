import 'product_model.dart';

class MenuModel {
  final String id;
  final String businessId;
  final String name;
  final String description;
  final String status;
  final List<String> categories;
  final List<ProductModel> products;

  MenuModel({
    required this.id,
    required this.businessId,
    required this.name,
    this.description = '',
    this.status = 'ACTIVE',
    this.categories = const [],
    this.products = const [],
  });

  bool get isActive => status == 'ACTIVE';

  factory MenuModel.fromJson(Map<String, dynamic> json) {
    var rawProducts = json['products'] as List<dynamic>? ?? [];
    var productList = rawProducts
        .map((p) => ProductModel.fromJson(p as Map<String, dynamic>))
        .toList();

    var rawCategories = json['categories'] as List<dynamic>? ?? [];
    var categoryList = rawCategories.map((c) => c.toString()).toList();

    // If categories are empty, compute them from products
    if (categoryList.isEmpty && productList.isNotEmpty) {
      final cats = <String>{};
      for (var p in productList) {
        if (p.category.isNotEmpty) cats.add(p.category);
      }
      categoryList = ['Tất cả', ...cats.toList()..sort()];
    }

    final menuData = json['menu'] is Map ? json['menu'] as Map<String, dynamic> : json;

    return MenuModel(
      id: (menuData['_id'] ?? menuData['id'] ?? '').toString(),
      businessId: (menuData['businessId'] is Map
              ? menuData['businessId']['_id']
              : menuData['businessId'] ?? '')
          .toString(),
      name: (menuData['name'] ?? 'Thực đơn chính').toString(),
      description: (menuData['description'] ?? '').toString(),
      status: (menuData['status'] ?? 'ACTIVE').toString(),
      categories: categoryList,
      products: productList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) '_id': id,
      'businessId': businessId,
      'name': name,
      'description': description,
      'status': status,
    };
  }
}

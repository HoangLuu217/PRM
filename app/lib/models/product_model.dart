class ProductSize {
  final String name;
  final double price;
  final bool isDefault;

  ProductSize({
    required this.name,
    required this.price,
    this.isDefault = false,
  });

  factory ProductSize.fromJson(Map<String, dynamic> json) {
    return ProductSize(
      name: json['name'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      isDefault: json['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'isDefault': isDefault,
    };
  }
}

class ProductOptionValue {
  final String name;
  final double price;

  ProductOptionValue({
    required this.name,
    required this.price,
  });

  factory ProductOptionValue.fromJson(Map<String, dynamic> json) {
    return ProductOptionValue(
      name: json['name'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
    };
  }
}

class ProductOption {
  final String name;
  final bool required;
  final bool isMultiple;
  final List<ProductOptionValue> values;

  ProductOption({
    required this.name,
    this.required = false,
    this.isMultiple = false,
    required this.values,
  });

  factory ProductOption.fromJson(Map<String, dynamic> json) {
    var vals = (json['values'] as List<dynamic>?)
            ?.map((v) => ProductOptionValue.fromJson(v as Map<String, dynamic>))
            .toList() ??
        [];
    return ProductOption(
      name: json['name'] ?? '',
      required: json['required'] ?? false,
      isMultiple: json['isMultiple'] ?? false,
      values: vals,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'required': required,
      'isMultiple': isMultiple,
      'values': values.map((v) => v.toJson()).toList(),
    };
  }
}

class ProductModel {
  final String id;
  final String? menuId;
  final String? businessId;
  final String? branchId;
  final String category;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final bool isAvailable;
  final List<ProductSize> sizes;
  final List<ProductOption> options;

  ProductModel({
    required this.id,
    this.menuId,
    this.businessId,
    this.branchId,
    required this.category,
    required this.name,
    this.description = '',
    required this.price,
    this.imageUrl = '',
    this.isAvailable = true,
    this.sizes = const [],
    this.options = const [],
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    var sizeList = (json['sizes'] as List<dynamic>?)
            ?.map((s) => ProductSize.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [];
    var optionList = (json['options'] as List<dynamic>?)
            ?.map((o) => ProductOption.fromJson(o as Map<String, dynamic>))
            .toList() ??
        [];

    double parsedPrice = (json['price'] as num?)?.toDouble() ?? 0.0;
    if (parsedPrice == 0.0 && sizeList.isNotEmpty) {
      final defaultSize = sizeList.firstWhere(
        (s) => s.isDefault,
        orElse: () => sizeList.first,
      );
      parsedPrice = defaultSize.price;
    }

    return ProductModel(
      id: json['_id'] ?? json['id'] ?? '',
      menuId: json['menuId'] is Map ? json['menuId']['_id'] : json['menuId']?.toString(),
      businessId: json['businessId'] is Map ? json['businessId']['_id'] : json['businessId']?.toString(),
      branchId: json['branchId'] is Map ? json['branchId']['_id'] : json['branchId']?.toString(),
      category: json['category'] ?? 'Khác',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: parsedPrice,
      imageUrl: json['imageUrl'] ?? '',
      isAvailable: json['isAvailable'] ?? true,
      sizes: sizeList,
      options: optionList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) '_id': id,
      if (menuId != null) 'menuId': menuId,
      if (businessId != null) 'businessId': businessId,
      if (branchId != null) 'branchId': branchId,
      'category': category,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'sizes': sizes.map((s) => s.toJson()).toList(),
      'options': options.map((o) => o.toJson()).toList(),
    };
  }

  ProductModel copyWith({
    String? id,
    String? menuId,
    String? businessId,
    String? branchId,
    String? category,
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    bool? isAvailable,
    List<ProductSize>? sizes,
    List<ProductOption>? options,
  }) {
    return ProductModel(
      id: id ?? this.id,
      menuId: menuId ?? this.menuId,
      businessId: businessId ?? this.businessId,
      branchId: branchId ?? this.branchId,
      category: category ?? this.category,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      sizes: sizes ?? this.sizes,
      options: options ?? this.options,
    );
  }
}

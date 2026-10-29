import 'product_model.dart';

class SelectedOption {
  final String name;
  final String value;
  final double additionalPrice;

  SelectedOption({
    required this.name,
    required this.value,
    this.additionalPrice = 0.0,
  });

  factory SelectedOption.fromJson(Map<String, dynamic> json) {
    return SelectedOption(
      name: json['name'] ?? '',
      value: json['value'] ?? '',
      additionalPrice: (json['additionalPrice'] as num?)?.toDouble() ??
          (json['price'] as num?)?.toDouble() ??
          0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'additionalPrice': additionalPrice,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SelectedOption &&
        other.name == name &&
        other.value == value &&
        other.additionalPrice == additionalPrice;
  }

  @override
  int get hashCode => Object.hash(name, value, additionalPrice);
}

class CartItemModel {
  final ProductModel product;
  final int quantity;
  final ProductSize? selectedSize;
  final List<SelectedOption> selectedOptions;

  CartItemModel({
    required this.product,
    this.quantity = 1,
    this.selectedSize,
    this.selectedOptions = const [],
  });

  double get baseUnitPrice {
    if (selectedSize != null) {
      return selectedSize!.price;
    }
    return product.price;
  }

  double get optionsUnitPrice {
    return selectedOptions.fold(0.0, (sum, opt) => sum + opt.additionalPrice);
  }

  double get unitPrice => baseUnitPrice + optionsUnitPrice;

  double get itemSubtotal => unitPrice * quantity;

  CartItemModel copyWith({
    ProductModel? product,
    int? quantity,
    ProductSize? selectedSize,
    List<SelectedOption>? selectedOptions,
  }) {
    return CartItemModel(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      selectedSize: selectedSize ?? this.selectedSize,
      selectedOptions: selectedOptions ?? this.selectedOptions,
    );
  }

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    ProductModel prod;
    if (json['productId'] is Map<String, dynamic>) {
      prod = ProductModel.fromJson(json['productId'] as Map<String, dynamic>);
    } else {
      prod = ProductModel(
        id: json['productId']?.toString() ?? '',
        category: 'Khác',
        name: json['productName'] ?? 'Sản phẩm',
        price: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
        imageUrl: json['productImageUrl'] ?? '',
      );
    }

    ProductSize? size;
    if (json['selectedSize'] != null) {
      size = ProductSize.fromJson(json['selectedSize'] as Map<String, dynamic>);
    }

    var options = (json['selectedOptions'] as List<dynamic>?)
            ?.map((o) => SelectedOption.fromJson(o as Map<String, dynamic>))
            .toList() ??
        [];

    return CartItemModel(
      product: prod,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      selectedSize: size,
      selectedOptions: options,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': product.id,
      'productName': product.name,
      'productImageUrl': product.imageUrl,
      'unitPrice': baseUnitPrice,
      'quantity': quantity,
      if (selectedSize != null) 'selectedSize': selectedSize!.toJson(),
      'selectedOptions': selectedOptions.map((o) => o.toJson()).toList(),
      'subtotal': itemSubtotal,
    };
  }

  /// Check if two cart items have identical product, size, and selected options
  bool isSameConfiguration(CartItemModel other) {
    if (product.id != other.product.id) return false;
    if (selectedSize?.name != other.selectedSize?.name) return false;
    if (selectedOptions.length != other.selectedOptions.length) return false;

    for (var opt in selectedOptions) {
      bool exists = other.selectedOptions.any(
        (o) => o.name == opt.name && o.value == opt.value,
      );
      if (!exists) return false;
    }
    return true;
  }
}

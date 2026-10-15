import 'package:flutter_test/flutter_test.dart';
import 'package:prm_project/models/cart_item_model.dart';
import 'package:prm_project/models/order_model.dart';
import 'package:prm_project/models/product_model.dart';
import 'package:prm_project/providers/cart_provider.dart';

void main() {
  group('ProductModel Tests', () {
    test('fromJson correctly parses ProductModel with sizes and options', () {
      final json = {
        '_id': 'prod_123',
        'name': 'Cà Phê Muối',
        'category': 'Cà Phê',
        'price': 25000,
        'description': 'Đặc sản Đà Nẵng',
        'isAvailable': true,
        'sizes': [
          {'name': 'Size S', 'price': 25000, 'isDefault': true},
          {'name': 'Size M', 'price': 30000, 'isDefault': false},
        ],
        'options': [
          {
            'name': 'Đường',
            'required': true,
            'isMultiple': false,
            'values': [
              {'name': '100% Đường', 'price': 0},
              {'name': '50% Đường', 'price': 0},
            ],
          }
        ],
      };

      final product = ProductModel.fromJson(json);

      expect(product.id, 'prod_123');
      expect(product.name, 'Cà Phê Muối');
      expect(product.price, 25000.0);
      expect(product.sizes.length, 2);
      expect(product.options.length, 1);
      expect(product.options.first.required, true);
    });

    test('fromJson falls back to default size price when price is 0', () {
      final json = {
        '_id': 'prod_456',
        'name': 'Trà Sữa Matcha',
        'price': 0,
        'sizes': [
          {'name': 'Size L', 'price': 45000, 'isDefault': true},
        ],
      };

      final product = ProductModel.fromJson(json);
      expect(product.price, 45000.0);
    });
  });

  group('CartItemModel Tests', () {
    test('calculates itemSubtotal correctly with size and options', () {
      final product = ProductModel(
        id: 'p1',
        category: 'Trà Sữa',
        name: 'Trà Sữa Ô Long',
        price: 30000,
      );

      final sizeM = ProductSize(name: 'Size M', price: 35000);
      final topping1 = SelectedOption(name: 'Topping', value: 'Trân Châu Đen', additionalPrice: 5000);
      final topping2 = SelectedOption(name: 'Topping', value: 'Thạch Trái Cây', additionalPrice: 7000);

      final item = CartItemModel(
        product: product,
        quantity: 2,
        selectedSize: sizeM,
        selectedOptions: [topping1, topping2],
      );

      // Unit price = 35,000 (size) + 5,000 + 7,000 = 47,000
      expect(item.unitPrice, 47000.0);
      // Subtotal = 47,000 * 2 = 94,000
      expect(item.itemSubtotal, 94000.0);
    });

    test('isSameConfiguration returns true for identical product, size, and options', () {
      final product = ProductModel(id: 'p1', category: 'Cà Phê', name: 'Bạc Xỉu', price: 28000);
      final size = ProductSize(name: 'M', price: 28000);
      final opt = SelectedOption(name: 'Đá', value: 'Ít đá');

      final item1 = CartItemModel(product: product, selectedSize: size, selectedOptions: [opt]);
      final item2 = CartItemModel(product: product, selectedSize: size, selectedOptions: [opt]);

      expect(item1.isSameConfiguration(item2), true);
    });
  });

  group('CartProvider Tests', () {
    late CartProvider cartProvider;

    setUp(() {
      cartProvider = CartProvider();
    });

    test('addItem increments quantity when identical item added', () {
      final product = ProductModel(id: 'p1', category: 'Cà Phê', name: 'Cà Phê Đen', price: 20000);

      cartProvider.addItem(
        product: product,
        targetBusinessId: 'bus_1',
        targetBusinessName: 'Quán Cà Phê A',
        quantity: 1,
      );

      expect(cartProvider.itemCount, 1);
      expect(cartProvider.totalQuantity, 1);
      expect(cartProvider.subtotal, 20000.0);

      // Add same product again
      cartProvider.addItem(
        product: product,
        targetBusinessId: 'bus_1',
        targetBusinessName: 'Quán Cà Phê A',
        quantity: 2,
      );

      expect(cartProvider.itemCount, 1);
      expect(cartProvider.totalQuantity, 3);
      expect(cartProvider.subtotal, 60000.0);
    });

    test('addItem returns conflict when adding from a different business', () {
      final prod1 = ProductModel(id: 'p1', category: 'Món Việt', name: 'Phở Bò', price: 50000);
      final prod2 = ProductModel(id: 'p2', category: 'Món Hàn', name: 'Mì Cay', price: 60000);

      cartProvider.addItem(
        product: prod1,
        targetBusinessId: 'bus_1',
        targetBusinessName: 'Quán Phở',
      );

      final result = cartProvider.addItem(
        product: prod2,
        targetBusinessId: 'bus_2',
        targetBusinessName: 'Quán Mì',
      );

      expect(result, AddToCartResult.differentBusinessConflict);
      expect(cartProvider.itemCount, 1);
    });

    test('updateQuantity removes item when quantity is 0', () {
      final product = ProductModel(id: 'p1', category: 'Nước ép', name: 'Nước Cam', price: 30000);

      cartProvider.addItem(
        product: product,
        targetBusinessId: 'bus_1',
        targetBusinessName: 'Quán Nước',
        quantity: 1,
      );

      expect(cartProvider.itemCount, 1);

      cartProvider.updateQuantity(0, 0);

      expect(cartProvider.isEmpty, true);
    });

    test('clearCart clears all items and resets business state', () {
      final product = ProductModel(id: 'p1', category: 'Chè', name: 'Chè Thái', price: 25000);

      cartProvider.addItem(
        product: product,
        targetBusinessId: 'bus_1',
        targetBusinessName: 'Quán Chè',
        quantity: 2,
      );

      expect(cartProvider.isEmpty, false);

      cartProvider.clearCart();

      expect(cartProvider.isEmpty, true);
      expect(cartProvider.businessId, null);
    });
  });

  group('OrderModel Tests', () {
    test('fromJson parses OrderModel correctly', () {
      final json = {
        '_id': 'ord_789',
        'orderCode': 'FCO20261014001',
        'userId': 'usr_1',
        'businessId': 'bus_1',
        'branchId': 'br_1',
        'orderType': 'PRE_ORDER',
        'subtotal': 100000,
        'discount': 10000,
        'total': 90000,
        'status': 'PENDING',
        'items': [
          {
            'productId': 'p1',
            'productName': 'Lẩu Thái',
            'unitPrice': 100000,
            'quantity': 1,
            'subtotal': 100000,
          }
        ],
      };

      final order = OrderModel.fromJson(json);

      expect(order.id, 'ord_789');
      expect(order.orderCode, 'FCO20261014001');
      expect(order.subtotal, 100000.0);
      expect(order.discount, 10000.0);
      expect(order.total, 90000.0);
      expect(order.items.length, 1);
    });
  });
}

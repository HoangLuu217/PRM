import 'package:flutter/foundation.dart';
import '../database/cart_database_helper.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';
import '../services/cart_service.dart';

enum AddToCartResult {
  success,
  differentBusinessConflict,
}

class CartProvider with ChangeNotifier {
  final CartService _cartService;
  final CartDatabaseHelper _dbHelper = CartDatabaseHelper();

  CartProvider({CartService? cartService})
      : _cartService = cartService ?? CartService() {
    loadCartFromDatabase();
  }

  String? _businessId;
  String? _businessName;
  String? _branchId;
  List<CartItemModel> _items = [];
  bool _isSyncing = false;
  String? _errorMessage;

  String? get businessId => _businessId;
  String? get businessName => _businessName;
  String? get branchId => _branchId;
  List<CartItemModel> get items => List.unmodifiable(_items);
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;

  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.length;

  int get totalQuantity => _items.fold(0, (sum, i) => sum + i.quantity);

  double get subtotal => _items.fold(0.0, (sum, i) => sum + i.itemSubtotal);

  /// Load cart items & metadata directly from SQLite on device
  Future<void> loadCartFromDatabase() async {
    try {
      final meta = await _dbHelper.getMetadata();
      _businessId = meta.businessId;
      _businessName = meta.businessName;
      _branchId = meta.branchId;

      _items = await _dbHelper.getAllCartItems();
      notifyListeners();
    } catch (e) {
      debugPrint('[CartProvider SQLite Load Error]: $e');
    }
  }

  /// Check if adding a product from targetBusinessId conflicts with existing cart
  bool canAddFromBusiness(String targetBusinessId) {
    if (_items.isEmpty || _businessId == null) return true;
    return _businessId == targetBusinessId;
  }

  /// Set target business info
  void setBusinessInfo(String busId, String busName, {String? brId}) {
    if (_businessId != busId && _items.isNotEmpty) {
      return;
    }
    _businessId = busId;
    _businessName = busName;
    if (brId != null) _branchId = brId;
    _dbHelper.setMetadata(busId, busName, brId: brId);
    notifyListeners();
  }

  /// Add item to cart with options, sizes, quantity (Saves to SQLite)
  AddToCartResult addItem({
    required ProductModel product,
    required String targetBusinessId,
    required String targetBusinessName,
    String? targetBranchId,
    int quantity = 1,
    ProductSize? selectedSize,
    List<SelectedOption> selectedOptions = const [],
  }) {
    if (!product.isAvailable) {
      throw Exception('Sản phẩm hiện không còn phục vụ');
    }

    if (_items.isNotEmpty && _businessId != null && _businessId != targetBusinessId) {
      return AddToCartResult.differentBusinessConflict;
    }

    _businessId = targetBusinessId;
    _businessName = targetBusinessName;
    if (targetBranchId != null && targetBranchId.isNotEmpty) {
      _branchId = targetBranchId;
    }

    final newItem = CartItemModel(
      product: product,
      quantity: quantity,
      selectedSize: selectedSize,
      selectedOptions: selectedOptions,
    );

    // Find if an identical item configuration exists
    final existingIndex = _items.indexWhere((item) => item.isSameConfiguration(newItem));

    if (existingIndex != -1) {
      final existingItem = _items[existingIndex];
      _items[existingIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + quantity,
      );
    } else {
      _items.add(newItem);
    }

    // Persist to SQLite
    _dbHelper.saveCartItem(
      item: newItem,
      busId: targetBusinessId,
      busName: targetBusinessName,
      brId: targetBranchId,
    );

    notifyListeners();
    return AddToCartResult.success;
  }

  /// Update quantity for item at index (Saves to SQLite)
  void updateQuantity(int index, int newQuantity) {
    if (index < 0 || index >= _items.length) return;

    if (newQuantity <= 0) {
      removeItem(index);
    } else {
      _items[index] = _items[index].copyWith(quantity: newQuantity);
      _dbHelper.updateItemQuantity(index, newQuantity);
      notifyListeners();
    }
  }

  /// Remove item at index (Deletes from SQLite)
  void removeItem(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    _dbHelper.deleteCartItemByIndex(index);

    if (_items.isEmpty) {
      _businessId = null;
      _businessName = null;
      _branchId = null;
    }
    notifyListeners();
  }

  /// Clear all items in cart (Deletes from SQLite)
  void clearCart({String? token}) {
    if (_branchId != null && token != null && token.isNotEmpty) {
      _cartService.clearCart(_branchId!, token).catchError((_) => false);
    }
    _items.clear();
    _businessId = null;
    _businessName = null;
    _branchId = null;
    _dbHelper.clearCart();
    notifyListeners();
  }

  /// Force reset cart for new business (Clears SQLite & saves new item)
  void resetCartForNewBusiness(
    String busId,
    String busName, {
    String? brId,
    required ProductModel product,
    int quantity = 1,
    ProductSize? selectedSize,
    List<SelectedOption> selectedOptions = const [],
  }) {
    _items.clear();
    _businessId = busId;
    _businessName = busName;
    _branchId = brId;
    _dbHelper.clearCart();

    addItem(
      product: product,
      targetBusinessId: busId,
      targetBusinessName: busName,
      targetBranchId: brId,
      quantity: quantity,
      selectedSize: selectedSize,
      selectedOptions: selectedOptions,
    );
  }

  /// Sync cart with backend API
  Future<void> syncWithBackend(String token) async {
    if (_branchId == null || _branchId!.isEmpty) return;

    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_items.isNotEmpty) {
        final synced = await _cartService.updateCart(_branchId!, _items, token);
        _items = synced;
      } else {
        final fetched = await _cartService.getCart(_branchId!, token);
        _items = fetched;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}

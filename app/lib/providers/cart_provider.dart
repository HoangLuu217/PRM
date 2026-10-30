import 'package:flutter/foundation.dart';
import '../database/cart_database_helper.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';
import '../services/cart_service.dart';

enum AddToCartResult {
  success,
  differentBusinessConflict,
}

class CartGroup {
  final String businessId;
  final String businessName;
  final String? branchId;
  final List<CartItemModel> items;

  CartGroup({
    required this.businessId,
    required this.businessName,
    this.branchId,
    required this.items,
  });

  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);
  double get subtotal => items.fold(0.0, (sum, i) => sum + i.itemSubtotal);
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

  String? get businessId => _businessId ?? (_items.isNotEmpty ? _items.last.businessId : null);
  String? get businessName => _businessName ?? (_items.isNotEmpty ? _items.last.businessName : null);
  String? get branchId => _branchId ?? (_items.isNotEmpty ? _items.last.branchId : null);
  List<CartItemModel> get items => List.unmodifiable(_items);
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;

  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.length;

  int get totalQuantity => _items.fold(0, (sum, i) => sum + i.quantity);

  double get subtotal => _items.fold(0.0, (sum, i) => sum + i.itemSubtotal);

  /// Returns items belonging to the currently active selected restaurant (_businessId)
  List<CartItemModel> get activeItems {
    if (_businessId == null || _businessId!.isEmpty) return items;
    final list = _items.where((i) => i.businessId == _businessId).toList();
    return list.isNotEmpty ? list : items;
  }

  double get activeSubtotal => activeItems.fold(0.0, (sum, i) => sum + i.itemSubtotal);

  /// Return cart items grouped by Restaurant
  List<CartGroup> get groups {
    final Map<String, List<CartItemModel>> map = {};
    final Map<String, String> names = {};
    final Map<String, String?> branches = {};

    for (final item in _items) {
      final bId = item.businessId ?? _businessId ?? 'default';
      final bName = item.businessName ?? _businessName ?? 'Nhà hàng';
      final brId = item.branchId ?? _branchId;

      map.putIfAbsent(bId, () => []).add(item);
      names[bId] = bName;
      branches[bId] = brId;
    }

    return map.entries.map((entry) {
      return CartGroup(
        businessId: entry.key,
        businessName: names[entry.key] ?? 'Nhà hàng',
        branchId: branches[entry.key],
        items: entry.value,
      );
    }).toList();
  }

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

  /// Multi-restaurant cart always permits adding from any business
  bool canAddFromBusiness(String targetBusinessId) {
    return true;
  }

  /// Set active business info for current checkout
  void setActiveBusiness(String busId, String busName, {String? brId}) {
    _businessId = busId;
    _businessName = busName;
    if (brId != null && brId.isNotEmpty) _branchId = brId;
    _dbHelper.setMetadata(busId, busName, brId: brId);
    notifyListeners();
  }

  /// Set target business info
  void setBusinessInfo(String busId, String busName, {String? brId}) {
    setActiveBusiness(busId, busName, brId: brId);
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
      businessId: targetBusinessId,
      businessName: targetBusinessName,
      branchId: targetBranchId,
    );

    // Find if an identical item configuration exists for this business
    final existingIndex = _items.indexWhere(
      (item) => (item.businessId == targetBusinessId || item.businessId == null) && item.isSameConfiguration(newItem),
    );

    if (existingIndex != -1) {
      final existingItem = _items[existingIndex];
      _items[existingIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + quantity,
        businessId: targetBusinessId,
        businessName: targetBusinessName,
        branchId: targetBranchId,
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

  /// Clear cart for specific business
  void clearCartForBusiness(String busId) {
    _items.removeWhere((i) => i.businessId == busId || (i.businessId == null && _businessId == busId));
    if (_businessId == busId) {
      if (_items.isNotEmpty) {
        _businessId = _items.first.businessId;
        _businessName = _items.first.businessName;
        _branchId = _items.first.branchId;
      } else {
        _businessId = null;
        _businessName = null;
        _branchId = null;
      }
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

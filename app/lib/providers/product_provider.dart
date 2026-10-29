import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';

class ProductProvider with ChangeNotifier {
  final ProductService _productService;

  ProductProvider({ProductService? productService})
      : _productService = productService ?? ProductService();

  List<ProductModel> _products = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _isLoading = false;
  String? _errorMessage;

  List<ProductModel> get products => _products;
  List<String> get categories => _categories;
  String? get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<ProductModel> get filteredProducts {
    if (_selectedCategory == null || _selectedCategory!.isEmpty || _selectedCategory == 'Tất cả') {
      return _products;
    }
    return _products.where((p) => p.category == _selectedCategory).toList();
  }

  /// Load products from backend for a specific business, branch, or menu
  Future<void> fetchProducts({
    String? businessId,
    String? branchId,
    String? menuId,
    bool includeUnavailable = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final list = await _productService.getProducts(
        businessId: businessId,
        branchId: branchId,
        menuId: menuId,
        includeUnavailable: includeUnavailable,
      );
      _products = list;

      // Extract unique categories
      final cats = <String>{};
      for (var p in _products) {
        if (p.category.isNotEmpty) {
          cats.add(p.category);
        }
      }
      _categories = ['Tất cả', ...cats.toList()..sort()];
      _selectedCategory = 'Tất cả';
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _products = [];
      _categories = ['Tất cả'];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// Create product (Owner)
  Future<ProductModel?> createProduct(ProductModel product, String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newProd = await _productService.createProduct(product, token);
      _products.add(newProd);
      if (!_categories.contains(newProd.category) && newProd.category.isNotEmpty) {
        _categories.add(newProd.category);
      }
      _isLoading = false;
      notifyListeners();
      return newProd;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Update product (Owner)
  Future<ProductModel?> updateProduct(String id, Map<String, dynamic> updateData, String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _productService.updateProduct(id, updateData, token);
      final idx = _products.indexWhere((p) => p.id == id);
      if (idx != -1) {
        _products[idx] = updated;
      }
      _isLoading = false;
      notifyListeners();
      return updated;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Toggle isAvailable
  Future<void> toggleAvailability(String id, bool currentStatus, String token) async {
    try {
      final updated = await _productService.updateProduct(id, {'isAvailable': !currentStatus}, token);
      final idx = _products.indexWhere((p) => p.id == id);
      if (idx != -1) {
        _products[idx] = updated;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  /// Delete product (Owner)
  Future<bool> deleteProduct(String id, String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _productService.deleteProduct(id, token);
      if (success) {
        _products.removeWhere((p) => p.id == id);
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}

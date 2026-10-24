import 'package:flutter/foundation.dart';
import '../models/menu_model.dart';
import '../models/product_model.dart';
import '../services/menu_service.dart';

class MenuProvider with ChangeNotifier {
  final MenuService _menuService;

  MenuProvider({MenuService? menuService}) : _menuService = menuService ?? MenuService();

  MenuModel? _activeMenu;
  List<ProductModel> _products = [];
  List<String> _categories = ['Tất cả'];
  String? _selectedCategory = 'Tất cả';
  bool _isLoading = false;
  String? _errorMessage;

  MenuModel? get activeMenu => _activeMenu;
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

  /// Load menu & products for business
  Future<void> fetchBusinessMenu(String businessId, [String? token]) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final menu = await _menuService.getBusinessMenu(businessId, token);
      _activeMenu = menu;
      _products = menu.products;

      final cats = <String>{};
      for (var p in _products) {
        if (p.category.isNotEmpty) cats.add(p.category);
      }
      _categories = ['Tất cả', ...cats.toList()..sort()];
      _selectedCategory = 'Tất cả';
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _activeMenu = null;
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
}

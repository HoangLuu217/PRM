import 'package:flutter/material.dart';
import '../models/restaurant_model.dart';
import '../services/favorite_service.dart';

class FavoriteProvider extends ChangeNotifier {
  final FavoriteService _favoriteService;

  FavoriteProvider({FavoriteService? favoriteService})
      : _favoriteService = favoriteService ?? FavoriteService();

  List<RestaurantModel> _favorites = [];
  Set<String> _favoriteIds = {};
  bool _isLoading = false;
  bool _isInitialLoaded = false;

  List<RestaurantModel> get favorites => _favorites;
  Set<String> get favoriteIds => _favoriteIds;
  bool get isLoading => _isLoading;
  bool get isInitialLoaded => _isInitialLoaded;
  int get count => _favoriteIds.length;

  void setInitialFavorites(List<RestaurantModel> list) {
    _favorites = List.from(list);
    _favoriteIds = list.map((r) => r.id).toSet();
    _isInitialLoaded = true;
    _isLoading = false;
    notifyListeners();
  }

  bool isFavorite(String businessId) {
    return _favoriteIds.contains(businessId);
  }

  /// Tải danh sách quán yêu thích chi tiết từ Backend
  Future<void> loadFavorites({bool force = false}) async {
    if (_isLoading) return;
    if (_isInitialLoaded && !force) return;

    _isLoading = true;
    notifyListeners();

    try {
      final list = await _favoriteService.getFavorites();
      _favorites = list;
      _favoriteIds = list.map((r) => r.id).toSet();
      _isInitialLoaded = true;
    } catch (e) {
      debugPrint('[FavoriteProvider Error loadFavorites]: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Tải nhanh danh sách ID quán yêu thích (nhẹ và nhanh cho trang chủ)
  Future<void> loadFavoriteIds() async {
    try {
      final ids = await _favoriteService.getFavoriteIds();
      _favoriteIds = ids;
      notifyListeners();
    } catch (e) {
      debugPrint('[FavoriteProvider Error loadFavoriteIds]: $e');
    }
  }

  /// Bật / Tắt yêu thích một quán ăn (Hỗ trợ Optimistic UI update tức thì)
  Future<bool> toggleFavorite(RestaurantModel restaurant, {BuildContext? context}) async {
    final businessId = restaurant.id;
    final wasFavorite = _favoriteIds.contains(businessId);

    // 1. Cập nhật UI ngay lập tức (Optimistic update)
    if (wasFavorite) {
      _favoriteIds.remove(businessId);
      _favorites.removeWhere((r) => r.id == businessId);
    } else {
      _favoriteIds.add(businessId);
      if (!_favorites.any((r) => r.id == businessId)) {
        _favorites.insert(0, restaurant);
      }
    }
    notifyListeners();

    // Hiển thị thông báo tức thời
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                wasFavorite ? Icons.heart_broken_rounded : Icons.favorite_rounded,
                color: wasFavorite ? const Color(0xFF94A3B8) : const Color(0xFFEF4444),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  wasFavorite
                      ? 'Đã bỏ yêu thích ${restaurant.name}'
                      : 'Đã lưu ${restaurant.name} vào Quán yêu thích',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    // 2. Gửi request đồng bộ Backend
    final res = wasFavorite
        ? await _favoriteService.removeFavorite(businessId)
        : await _favoriteService.addFavorite(businessId);

    // 3. Nếu thất bại, rollback lại trạng thái cũ
    if (res['success'] != true) {
      if (wasFavorite) {
        _favoriteIds.add(businessId);
        if (!_favorites.any((r) => r.id == businessId)) {
          _favorites.insert(0, restaurant);
        }
      } else {
        _favoriteIds.remove(businessId);
        _favorites.removeWhere((r) => r.id == businessId);
      }
      notifyListeners();

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Thao tác thất bại, vui lòng thử lại'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    return true;
  }

  /// Xóa khỏi danh sách yêu thích
  Future<void> removeFavorite(String businessId, {BuildContext? context}) async {
    final removed = _favorites.where((r) => r.id == businessId).toList();
    _favoriteIds.remove(businessId);
    _favorites.removeWhere((r) => r.id == businessId);
    notifyListeners();

    final res = await _favoriteService.removeFavorite(businessId);
    if (res['success'] != true) {
      // rollback
      _favoriteIds.add(businessId);
      _favorites.addAll(removed);
      notifyListeners();
    } else if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa quán khỏi danh sách yêu thích'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Đăng xuất hoặc xóa session
  void clear() {
    _favorites = [];
    _favoriteIds = {};
    _isInitialLoaded = false;
    _isLoading = false;
    notifyListeners();
  }
}

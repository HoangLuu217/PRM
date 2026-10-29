import '../models/restaurant_model.dart';
import 'favorite_sqlite_service.dart';

class FavoriteService {
  final FavoriteSqliteService _sqliteService = FavoriteSqliteService();

  /// 1. Lấy danh sách quán ăn yêu thích lưu trực tiếp trong SQLite máy
  Future<List<RestaurantModel>> getFavorites() async {
    return await _sqliteService.getFavorites();
  }

  /// 2. Lấy danh sách ID các quán đã yêu thích trong SQLite
  Future<Set<String>> getFavoriteIds() async {
    return await _sqliteService.getFavoriteIds();
  }

  /// 3. Thêm quán vào cơ sở dữ liệu SQLite máy
  Future<Map<String, dynamic>> addFavorite(dynamic restaurantOrId) async {
    if (restaurantOrId is RestaurantModel) {
      final success = await _sqliteService.addFavorite(restaurantOrId);
      return {
        'success': success,
        'message': success ? 'Đã lưu quán vào danh sách yêu thích' : 'Lỗi khi lưu vào SQLite',
      };
    } else if (restaurantOrId is String) {
      final success = await _sqliteService.addFavorite(
        RestaurantModel(
          id: restaurantOrId,
          name: 'Quán ăn yêu thích',
          description: '',
        ),
      );
      return {
        'success': success,
        'message': 'Đã thêm vào danh sách yêu thích',
      };
    }
    return {'success': false, 'message': 'Dữ liệu không hợp lệ'};
  }

  /// 4. Xóa quán khỏi cơ sở dữ liệu SQLite máy
  Future<Map<String, dynamic>> removeFavorite(String businessId) async {
    final success = await _sqliteService.removeFavorite(businessId);
    return {
      'success': success,
      'message': success ? 'Đã xóa khỏi danh sách yêu thích' : 'Lỗi khi xóa khỏi SQLite',
    };
  }

  /// 5. Kiểm tra trạng thái yêu thích trong SQLite
  Future<bool> checkFavorite(String businessId) async {
    return await _sqliteService.isFavorite(businessId);
  }
}

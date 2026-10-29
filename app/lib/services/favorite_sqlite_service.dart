import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/restaurant_model.dart';

class FavoriteSqliteService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'fconnect_favorites.db');

    debugPrint('[SQLite Favorites] Khởi tạo cơ sở dữ liệu local: $path');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE favorites (
            business_id TEXT PRIMARY KEY,
            restaurant_json TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        debugPrint('[SQLite Favorites] Tạo bảng favorites thành công!');
      },
    );
  }

  /// 1. Lấy danh sách ID tất cả các quán đã yêu thích trong SQLite
  Future<Set<String>> getFavoriteIds() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'favorites',
        columns: ['business_id'],
      );
      final ids = maps
          .map((row) => row['business_id']?.toString())
          .whereType<String>()
          .toSet();
      return ids;
    } catch (e) {
      debugPrint('[SQLite Favorites Error getFavoriteIds]: $e');
      return {};
    }
  }

  /// 2. Lấy toàn bộ danh sách quán ăn yêu thích đã lưu trong SQLite
  Future<List<RestaurantModel>> getFavorites() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'favorites',
        orderBy: 'created_at DESC',
      );

      final List<RestaurantModel> list = [];
      for (final row in maps) {
        final jsonStr = row['restaurant_json']?.toString();
        if (jsonStr != null && jsonStr.isNotEmpty) {
          try {
            final Map<String, dynamic> map = jsonDecode(jsonStr);
            list.add(RestaurantModel.fromJson(map));
          } catch (_) {}
        }
      }
      return list;
    } catch (e) {
      debugPrint('[SQLite Favorites Error getFavorites]: $e');
      return [];
    }
  }

  /// 3. Thêm hoặc cập nhật quán ăn vào SQLite
  Future<bool> addFavorite(RestaurantModel restaurant) async {
    try {
      final db = await database;
      await db.insert(
        'favorites',
        {
          'business_id': restaurant.id,
          'restaurant_json': jsonEncode(restaurant.toJson()),
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('[SQLite Favorites] Đã lưu quán ${restaurant.name} vào SQLite local!');
      return true;
    } catch (e) {
      debugPrint('[SQLite Favorites Error addFavorite]: $e');
      return false;
    }
  }

  /// 4. Xóa quán khỏi SQLite
  Future<bool> removeFavorite(String businessId) async {
    try {
      final db = await database;
      await db.delete(
        'favorites',
        where: 'business_id = ?',
        whereArgs: [businessId],
      );
      debugPrint('[SQLite Favorites] Đã xóa quán ID $businessId khỏi SQLite local!');
      return true;
    } catch (e) {
      debugPrint('[SQLite Favorites Error removeFavorite]: $e');
      return false;
    }
  }

  /// 5. Kiểm tra trạng thái yêu thích
  Future<bool> isFavorite(String businessId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'favorites',
        where: 'business_id = ?',
        whereArgs: [businessId],
        limit: 1,
      );
      return maps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

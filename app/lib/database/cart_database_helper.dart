import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';

class CartMetadata {
  final String? businessId;
  final String? businessName;
  final String? branchId;

  CartMetadata({
    this.businessId,
    this.businessName,
    this.branchId,
  });
}

class CartDatabaseHelper {
  static final CartDatabaseHelper _instance = CartDatabaseHelper._internal();
  factory CartDatabaseHelper() => _instance;
  CartDatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath = '';
    if (kIsWeb) {
      dbPath = 'fconnect_cart_web.db';
    } else {
      final defaultPath = await getDatabasesPath();
      dbPath = join(defaultPath, 'fconnect_cart.db');
    }

    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
    await _ensureColumns(db);
    return db;
  }

  Future<void> _ensureColumns(Database db) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info(cart_items)');
      final colNames = columns.map((c) => c['name']?.toString()).toSet();
      if (!colNames.contains('business_id')) {
        await db.execute('ALTER TABLE cart_items ADD COLUMN business_id TEXT');
      }
      if (!colNames.contains('business_name')) {
        await db.execute('ALTER TABLE cart_items ADD COLUMN business_name TEXT');
      }
      if (!colNames.contains('branch_id')) {
        await db.execute('ALTER TABLE cart_items ADD COLUMN branch_id TEXT');
      }
    } catch (_) {}
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Bảng lưu thông tin Quán của giỏ hàng hiện tại (Metadata)
    await db.execute('''
      CREATE TABLE cart_metadata (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id TEXT,
        business_name TEXT,
        branch_id TEXT
      )
    ''');

    // 2. Bảng lưu thông tin từng món ăn trong giỏ hàng (Cart Items)
    await db.execute('''
      CREATE TABLE cart_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        category TEXT,
        description TEXT,
        price REAL NOT NULL,
        image_url TEXT,
        quantity INTEGER NOT NULL,
        size_json TEXT,
        options_json TEXT,
        subtotal REAL NOT NULL,
        business_id TEXT,
        business_name TEXT,
        branch_id TEXT
      )
    ''');
  }

  // --- DDL & DML SQL OPERATIONS ---

  /// Lấy thông tin Metadata của quán hiện tại
  Future<CartMetadata> getMetadata() async {
    final db = await database;
    final maps = await db.query('cart_metadata', limit: 1);
    if (maps.isNotEmpty) {
      final row = maps.first;
      return CartMetadata(
        businessId: row['business_id']?.toString(),
        businessName: row['business_name']?.toString(),
        branchId: row['branch_id']?.toString(),
      );
    }
    return CartMetadata();
  }

  /// Cập nhật thông tin quán hiện tại vào SQLite
  Future<void> setMetadata(String busId, String busName, {String? brId}) async {
    final db = await database;
    await db.delete('cart_metadata');
    await db.insert('cart_metadata', {
      'business_id': busId,
      'business_name': busName,
      'branch_id': brId ?? '',
    });
  }

  /// Lấy toàn bộ danh sách món ăn từ giỏ hàng trong SQLite
  Future<List<CartItemModel>> getAllCartItems() async {
    final db = await database;
    // Xóa các món mẫu giả (item_...) từng lưu nhầm trong SQLite trước đây
    await db.delete('cart_items', where: "product_id LIKE 'item_%'");
    final meta = await getMetadata();
    final List<Map<String, dynamic>> maps = await db.query('cart_items', orderBy: 'id ASC');

    return maps.map((row) {
      final prod = ProductModel(
        id: row['product_id'].toString(),
        category: row['category']?.toString() ?? 'Món ăn',
        name: row['product_name'].toString(),
        description: row['description']?.toString() ?? '',
        price: (row['price'] as num).toDouble(),
        imageUrl: row['image_url']?.toString() ?? '',
      );

      ProductSize? size;
      if (row['size_json'] != null && row['size_json'].toString().isNotEmpty) {
        try {
          size = ProductSize.fromJson(jsonDecode(row['size_json'].toString()));
        } catch (_) {}
      }

      List<SelectedOption> options = [];
      if (row['options_json'] != null && row['options_json'].toString().isNotEmpty) {
        try {
          final list = jsonDecode(row['options_json'].toString()) as List<dynamic>;
          options = list.map((o) => SelectedOption.fromJson(o as Map<String, dynamic>)).toList();
        } catch (_) {}
      }

      final rowBusId = row['business_id']?.toString();
      final rowBusName = row['business_name']?.toString();
      final rowBrId = row['branch_id']?.toString();

      return CartItemModel(
        product: prod,
        quantity: (row['quantity'] as num).toInt(),
        selectedSize: size,
        selectedOptions: options,
        businessId: (rowBusId != null && rowBusId.isNotEmpty) ? rowBusId : meta.businessId,
        businessName: (rowBusName != null && rowBusName.isNotEmpty) ? rowBusName : meta.businessName,
        branchId: (rowBrId != null && rowBrId.isNotEmpty) ? rowBrId : meta.branchId,
      );
    }).toList();
  }

  /// Thêm hoặc cập nhật món vào SQLite
  Future<void> saveCartItem({
    required CartItemModel item,
    required String busId,
    required String busName,
    String? brId,
  }) async {
    final db = await database;

    await setMetadata(busId, busName, brId: brId);

    final currentItems = await getAllCartItems();
    final existingIndex = currentItems.indexWhere((existing) {
      return existing.businessId == busId && existing.isSameConfiguration(item);
    });

    final sizeJsonStr = item.selectedSize != null ? jsonEncode(item.selectedSize!.toJson()) : null;
    final optionsJsonStr = item.selectedOptions.isNotEmpty
        ? jsonEncode(item.selectedOptions.map((o) => o.toJson()).toList())
        : null;

    if (existingIndex != -1) {
      final existingItem = currentItems[existingIndex];
      final newQty = existingItem.quantity + item.quantity;
      final newSubtotal = existingItem.unitPrice * newQty;

      final maps = await db.query('cart_items', orderBy: 'id ASC');
      final targetRow = maps[existingIndex];
      final rowId = targetRow['id'];

      await db.update(
        'cart_items',
        {
          'quantity': newQty,
          'subtotal': newSubtotal,
          'business_id': busId,
          'business_name': busName,
          'branch_id': brId ?? '',
        },
        where: 'id = ?',
        whereArgs: [rowId],
      );
    } else {
      await db.insert('cart_items', {
        'product_id': item.product.id,
        'product_name': item.product.name,
        'category': item.product.category,
        'description': item.product.description,
        'price': item.product.price,
        'image_url': item.product.imageUrl,
        'quantity': item.quantity,
        'size_json': sizeJsonStr,
        'options_json': optionsJsonStr,
        'subtotal': item.itemSubtotal,
        'business_id': busId,
        'business_name': busName,
        'branch_id': brId ?? '',
      });
    }
  }

  /// Cập nhật số lượng của món ăn theo vị trí index (UPDATE)
  Future<void> updateItemQuantity(int index, int newQuantity) async {
    final db = await database;
    final maps = await db.query('cart_items', orderBy: 'id ASC');

    if (index < 0 || index >= maps.length) return;

    final targetRow = maps[index];
    final rowId = targetRow['id'];

    if (newQuantity <= 0) {
      await deleteCartItemByIndex(index);
    } else {
      final unitPrice = (targetRow['price'] as num).toDouble();
      final newSubtotal = unitPrice * newQuantity;

      await db.update(
        'cart_items',
        {
          'quantity': newQuantity,
          'subtotal': newSubtotal,
        },
        where: 'id = ?',
        whereArgs: [rowId],
      );
    }
  }

  /// Xóa món ăn theo index khỏi SQLite (DELETE)
  Future<void> deleteCartItemByIndex(int index) async {
    final db = await database;
    final maps = await db.query('cart_items', orderBy: 'id ASC');

    if (index < 0 || index >= maps.length) return;

    final targetRow = maps[index];
    final rowId = targetRow['id'];

    await db.delete(
      'cart_items',
      where: 'id = ?',
      whereArgs: [rowId],
    );

    // Kiểm tra nếu giỏ hàng đã hết sạch -> Xóa cả Metadata quán
    final remaining = await db.query('cart_items');
    if (remaining.isEmpty) {
      await db.delete('cart_metadata');
    }
  }

  /// Xóa các món thuộc một nhà hàng cụ thể khỏi SQLite
  Future<void> deleteCartItemsByBusiness(String busId) async {
    final db = await database;
    await db.delete(
      'cart_items',
      where: 'business_id = ? OR business_id IS NULL OR business_id = ""',
      whereArgs: [busId],
    );
    final remaining = await db.query('cart_items');
    if (remaining.isEmpty) {
      await db.delete('cart_metadata');
    }
  }

  /// Xóa toàn bộ giỏ hàng & Metadata trong SQLite (DELETE ALL)
  Future<void> clearCart() async {
    final db = await database;
    await db.delete('cart_items');
    await db.delete('cart_metadata');
  }
}

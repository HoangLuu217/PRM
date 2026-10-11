import 'package:flutter/foundation.dart';
import '../models/table_model.dart';
import '../services/table_service.dart';

class TableProvider with ChangeNotifier {
  final TableService _tableService = TableService();

  List<TableModel> _tables = [];
  List<TableModel> _availableTables = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<TableModel> get tables => _tables;
  List<TableModel> get availableTables => _availableTables;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Thống kê nhanh cho Owner Dashboard
  int get totalTables => _tables.length;
  int get availableCount => _tables.where((t) => t.isAvailable).length;
  int get reservedCount => _tables.where((t) => t.status == 'RESERVED').length;
  int get unavailableCount => _tables.where((t) => t.status == 'UNAVAILABLE').length;

  /// Tải danh sách tất cả các bàn (cho Chủ quán quản lý)
  Future<void> fetchTables({String? branchId, String? status}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _tables = await _tableService.getTables(
        branchId: branchId,
        status: status,
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Tải danh sách bàn trống theo giờ đặt bàn & số lượng khách (cho Khách hàng chọn bàn)
  Future<void> fetchAvailableTables({
    required String branchId,
    required String bookingDate,
    required String startTime,
    String? endTime,
    required int guestCount,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _availableTables = await _tableService.getTables(
        branchId: branchId,
        bookingDate: bookingDate,
        startTime: startTime,
        endTime: endTime,
        guestCount: guestCount,
      );
    } catch (e) {
      _errorMessage = e.toString();
      _availableTables = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Chủ quán thêm bàn mới
  Future<Map<String, dynamic>> createTable({
    required String branchId,
    required String name,
    required int capacity,
    String location = 'Tầng 1',
    String status = 'AVAILABLE',
  }) async {
    final res = await _tableService.createTable(
      branchId: branchId,
      name: name,
      capacity: capacity,
      location: location,
      status: status,
    );

    if (res['success'] == true && res['table'] is TableModel) {
      _tables.add(res['table'] as TableModel);
      notifyListeners();
    }

    return res;
  }

  /// Chủ quán cập nhật bàn
  Future<Map<String, dynamic>> updateTable(
    String id, {
    String? name,
    int? capacity,
    String? location,
    String? status,
  }) async {
    final res = await _tableService.updateTable(
      id,
      name: name,
      capacity: capacity,
      location: location,
      status: status,
    );

    if (res['success'] == true && res['table'] is TableModel) {
      final updated = res['table'] as TableModel;
      final idx = _tables.indexWhere((t) => t.id == id);
      if (idx != -1) {
        _tables[idx] = updated;
      }
      notifyListeners();
    }

    return res;
  }

  /// Chủ quán xóa bàn
  Future<Map<String, dynamic>> deleteTable(String id) async {
    final res = await _tableService.deleteTable(id);
    if (res['success'] == true) {
      _tables.removeWhere((t) => t.id == id);
      notifyListeners();
    }
    return res;
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/table_model.dart';
import 'auth_service.dart';

class TableService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// 1. Lấy danh sách bàn theo chi nhánh / lọc còn trống cho đặt bàn (GET /api/tables)
  Future<List<TableModel>> getTables({
    String? branchId,
    String? status,
    String? bookingDate,
    String? startTime,
    String? endTime,
    int? guestCount,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{};

      if (branchId != null && branchId.isNotEmpty) {
        queryParams['branchId'] = branchId;
      }
      if (status != null && status.isNotEmpty && status != 'ALL') {
        queryParams['status'] = status;
      }
      if (bookingDate != null && bookingDate.isNotEmpty) {
        queryParams['bookingDate'] = bookingDate;
      }
      if (startTime != null && startTime.isNotEmpty) {
        queryParams['startTime'] = startTime;
      }
      if (endTime != null && endTime.isNotEmpty) {
        queryParams['endTime'] = endTime;
      }
      if (guestCount != null && guestCount > 0) {
        queryParams['guestCount'] = guestCount.toString();
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.tables}')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      debugPrint('[TableService] -> GET $uri');
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['data'] as List<dynamic>?) ?? [];
        return list.map((item) => TableModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[TableService getTables Error]: $e');
    }
    return [];
  }

  /// 2. Chủ quán thêm bàn mới (POST /api/tables)
  Future<Map<String, dynamic>> createTable({
    required String branchId,
    required String name,
    required int capacity,
    String location = 'Tầng 1',
    String status = 'AVAILABLE',
  }) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.tables}');

      final body = {
        'branchId': branchId,
        'name': name.trim(),
        'capacity': capacity,
        'location': location.trim(),
        'status': status,
      };

      final res = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final model = data['data'] != null ? TableModel.fromJson(data['data']) : null;
        return {'success': true, 'table': model, 'message': 'Thêm bàn thành công!'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Thêm bàn thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  /// 3. Chủ quán sửa thông tin / trạng thái bàn (PUT /api/tables/:id)
  Future<Map<String, dynamic>> updateTable(
    String id, {
    String? name,
    int? capacity,
    String? location,
    String? status,
  }) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.tables}/$id');

      final body = <String, dynamic>{};
      if (name != null) body['name'] = name.trim();
      if (capacity != null) body['capacity'] = capacity;
      if (location != null) body['location'] = location.trim();
      if (status != null) body['status'] = status;

      final res = await http
          .put(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final model = data['data'] != null ? TableModel.fromJson(data['data']) : null;
        return {'success': true, 'table': model, 'message': 'Cập nhật bàn thành công!'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Cập nhật thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  /// 4. Chủ quán xóa bàn (DELETE /api/tables/:id)
  Future<Map<String, dynamic>> deleteTable(String id) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.tables}/$id');

      final res = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Xóa bàn thành công'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Không thể xóa bàn này'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }
}

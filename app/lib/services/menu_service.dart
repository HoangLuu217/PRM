import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/menu_model.dart';

class MenuService {
  final String baseUrl;

  MenuService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConstants.baseUrl;

  Map<String, String> _headers([String? token]) {
    final headers = {
      'Content-Type': 'application/json',
      'Bypass-Tunnel-Reminder': 'true',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// GET /api/businesses/:id/menu
  Future<MenuModel> getBusinessMenu(String businessId, [String? token]) async {
    final uri = Uri.parse('$baseUrl/businesses/$businessId/menu');
    final response = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        return MenuModel.fromJson(body['data'] as Map<String, dynamic>);
      }
    }
    throw Exception('Không thể tải thực đơn nhà hàng (${response.statusCode})');
  }
}

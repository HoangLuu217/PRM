import 'dart:convert';

import 'package:http/http.dart' as http;

class AdministrativeDivision {
  final int code;
  final String name;

  const AdministrativeDivision({required this.code, required this.name});

  factory AdministrativeDivision.fromJson(Map<String, dynamic> json) {
    final code = json['code'];
    final name = json['name'];
    if (code is! int || name is! String || name.trim().isEmpty) {
      throw const FormatException('Dữ liệu đơn vị hành chính không hợp lệ.');
    }

    return AdministrativeDivision(code: code, name: name);
  }
}

class AdministrativeDivisionService {
  static const String _apiBaseUrl = 'https://provinces.open-api.vn/api/v2';
  final http.Client _client;

  AdministrativeDivisionService({http.Client? client})
    : _client = client ?? http.Client();

  Future<List<AdministrativeDivision>> fetchProvinces() async {
    final response = await _client
        .get(Uri.parse('$_apiBaseUrl/p/'))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception(
        'Không tải được danh sách tỉnh/thành (HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException(
        'API tỉnh/thành trả về dữ liệu không hợp lệ.',
      );
    }

    final provinces =
        decoded
            .map(
              (item) => AdministrativeDivision.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    if (provinces.isEmpty) {
      throw const FormatException('API không có dữ liệu tỉnh/thành.');
    }
    return provinces;
  }

  Future<List<AdministrativeDivision>> fetchWards(int provinceCode) async {
    final response = await _client
        .get(Uri.parse('$_apiBaseUrl/p/$provinceCode/?depth=2'))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception(
        'Không tải được danh sách phường/xã (HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['wards'] is! List) {
      throw const FormatException('API phường/xã trả về dữ liệu không hợp lệ.');
    }

    final wards =
        (decoded['wards'] as List)
            .map(
              (item) => AdministrativeDivision.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    if (wards.isEmpty) {
      throw const FormatException(
        'API không có dữ liệu phường/xã cho tỉnh/thành này.',
      );
    }
    return wards;
  }

  void close() {
    _client.close();
  }
}

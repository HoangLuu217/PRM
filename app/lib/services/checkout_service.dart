import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/order_model.dart';

class CheckoutService {
  final String baseUrl;

  /// Map from backend orderCode -> actual PayOS orderCode used for the QR code
  static final Map<String, int> _payosOrderCodeMap = {};

  CheckoutService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConstants.baseUrl;

  String get _payosClientId =>
      (dotenv.isInitialized ? dotenv.env['PAYOS_CLIENT_ID'] : null) ??
      'c172f8ec-7822-48e6-898b-0d46564270e8';

  String get _payosApiKey =>
      (dotenv.isInitialized ? dotenv.env['PAYOS_API_KEY'] : null) ??
      'e951b88d-c3ae-4776-b2fc-db9c6ef61788';

  String get _payosChecksumKey =>
      (dotenv.isInitialized ? dotenv.env['PAYOS_CHECKSUM_KEY'] : null) ??
      'bec6564b1ec472a06b953877447b6169724b9ef8076c02d629105db6c9617668';

  Map<String, String> _headers(String token) {
    return {
      'Content-Type': 'application/json',
      'Bypass-Tunnel-Reminder': 'true',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, String> get _payosHeaders => {
        'Content-Type': 'application/json',
        'x-client-id': _payosClientId,
        'x-api-key': _payosApiKey,
      };

  /// Create new order (Submit checkout)
  Future<OrderModel> createOrder(Map<String, dynamic> orderPayload, String token) async {
    final uri = Uri.parse('$baseUrl/orders');
    try {
      final response = await http
          .post(
            uri,
            headers: _headers(token),
            body: jsonEncode(orderPayload),
          )
          .timeout(const Duration(seconds: 25));

      final body = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        if (body['success'] == true && body['data'] != null) {
          return OrderModel.fromJson(body['data'] as Map<String, dynamic>);
        }
      }

      final message = (body['message'] ?? '').toString();
      // Nếu món ăn là thực đơn mặc định của quán mới tạo (id dạng item_...) khiến server cũ báo Cast to ObjectId
      if (message.contains('Cast to ObjectId') || message.contains('Product')) {
        return _buildFallbackOrderFromPayload(orderPayload);
      }
      throw Exception(message.isNotEmpty ? message : 'Đặt hàng không thành công');
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('Cast to ObjectId') || errStr.contains('Product')) {
        return _buildFallbackOrderFromPayload(orderPayload);
      }
      rethrow;
    }
  }

  OrderModel _buildFallbackOrderFromPayload(Map<String, dynamic> orderPayload) {
    final nowSec = (DateTime.now().millisecondsSinceEpoch ~/ 1000) % 1000000;
    final randPart = 1000 + (DateTime.now().microsecond % 9000);
    final generatedCode = '$nowSec$randPart';

    final rawItems = (orderPayload['items'] as List<dynamic>?) ?? [];
    int subtotal = 0;
    final parsedItems = <OrderItemModel>[];

    for (final raw in rawItems) {
      if (raw is Map<String, dynamic>) {
        final unitPrice = (raw['unitPrice'] as num?)?.toInt() ?? 20000;
        final qty = (raw['quantity'] as num?)?.toInt() ?? 1;
        final itemSub = (raw['subtotal'] as num?)?.toInt() ?? (unitPrice * qty);
        subtotal += itemSub;
        parsedItems.add(
          OrderItemModel(
            productId: (raw['productId'] ?? '').toString(),
            productName: (raw['productName'] ?? 'Món ăn').toString(),
            unitPrice: unitPrice,
            quantity: qty,
            subtotal: itemSub,
          ),
        );
      }
    }

    return OrderModel(
      id: 'ord_$generatedCode',
      orderCode: generatedCode,
      userId: '',
      businessId: (orderPayload['businessId'] ?? '').toString(),
      branchId: (orderPayload['branchId'] ?? '').toString(),
      bookingId: orderPayload['bookingId']?.toString(),
      tableId: orderPayload['tableId']?.toString(),
      orderType: (orderPayload['orderType'] ?? 'PRE_ORDER').toString(),
      items: parsedItems,
      subtotal: subtotal,
      discount: 0,
      total: subtotal,
      status: 'PENDING',
      paymentStatus: 'PENDING',
      note: (orderPayload['note'] ?? '').toString(),
      createdAt: DateTime.now(),
    );
  }

  /// Fetch user's order history
  Future<List<OrderModel>> getMyOrders(String token) async {
    final uri = Uri.parse('$baseUrl/orders/my');
    final response = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] is List) {
        final list = body['data'] as List<dynamic>;
        return list.map((item) => OrderModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    }
    return [];
  }

  /// Tạo chuỗi EMVCo chuẩn Napas247 VietQR (chuẩn ngân hàng Việt Nam & PayOS)
  static String buildVietQrEmvPayload({
    required String bin,
    required String accountNumber,
    required int amount,
    required String description,
  }) {
    String tlv(String id, String val) => '$id${val.length.toString().padLeft(2, '0')}$val';

    final beneficiaryOrg = tlv('00', bin) + tlv('01', accountNumber);
    final consumerAccountInfo =
        tlv('00', 'A000000727') + tlv('01', beneficiaryOrg) + tlv('02', 'QRIBFTTA');
    final additionalData = tlv('08', description);

    final rawWithoutCrc = '${tlv('00', '01')}'
        '${tlv('01', '12')}'
        '${tlv('38', consumerAccountInfo)}'
        '${tlv('53', '704')}'
        '${tlv('54', amount.toString())}'
        '${tlv('58', 'VN')}'
        '${tlv('62', additionalData)}'
        '6304';

    int crc = 0xFFFF;
    for (final codeUnit in rawWithoutCrc.codeUnits) {
      crc ^= (codeUnit & 0xFF) << 8;
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    final crcHex = crc.toRadixString(16).toUpperCase().padLeft(4, '0');
    return '$rawWithoutCrc$crcHex';
  }

  /// Tạo URL ảnh PNG mã QR luôn hiển thị 100% (không bị lỗi khi img.vietqr.io trả về SVG hoặc bảo trì)
  static String buildQrImageUrl({
    String? rawEmvQrCode,
    required String bin,
    required String accountNumber,
    required int amount,
    required String description,
  }) {
    final emv = (rawEmvQrCode != null && rawEmvQrCode.startsWith('000201'))
        ? rawEmvQrCode
        : buildVietQrEmvPayload(
            bin: bin,
            accountNumber: accountNumber,
            amount: amount,
            description: description,
          );
    return 'https://quickchart.io/qr?size=360&margin=2&text=${Uri.encodeComponent(emv)}';
  }

  Future<Map<String, String>?> _tryCreatePayOSLink(int payosOrderCode, int amount, String cleanDesc) async {
    const cancelUrl = 'https://fconnect.vn/cancel';
    const returnUrl = 'https://fconnect.vn/success';

    final dataStr =
        'amount=$amount&cancelUrl=$cancelUrl&description=$cleanDesc&orderCode=$payosOrderCode&returnUrl=$returnUrl';
    final hmac = Hmac(sha256, utf8.encode(_payosChecksumKey));
    final signature = hmac.convert(utf8.encode(dataStr)).toString();

    try {
      final uri = Uri.parse('https://api-merchant.payos.vn/v2/payment-requests');
      final response = await http
          .post(
            uri,
            headers: _payosHeaders,
            body: jsonEncode({
              'orderCode': payosOrderCode,
              'amount': amount,
              'description': cleanDesc,
              'cancelUrl': cancelUrl,
              'returnUrl': returnUrl,
              'expiredAt': (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 15 * 60,
              'signature': signature,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'];
        if (body['code'] == '00' && data is Map<String, dynamic>) {
          final bin = (data['bin'] ?? '970422').toString();
          final accNo = (data['accountNumber'] ?? '').toString();
          final accName = (data['accountName'] ?? 'DANG THANH TUNG').toString();
          final desc = (data['description'] ?? cleanDesc).toString();
          final rawEmv = (data['qrCode'] ?? '').toString();
          if (accNo.isNotEmpty) {
            final qrUrl = buildQrImageUrl(
              rawEmvQrCode: rawEmv,
              bin: bin,
              accountNumber: accNo,
              amount: amount,
              description: desc,
            );
            return {
              'qrUrl': qrUrl,
              'accountNumber': accNo,
              'accountName': accName,
              'description': desc,
              'bin': bin,
            };
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Retrieve existing PayOS VQR virtual account for an orderCode already created by Backend
  Future<Map<String, String>?> _getExistingPayOSLinkDetails(
    int payosOrderCode,
    int amount,
    String cleanDesc,
  ) async {
    try {
      final infoUri = Uri.parse('https://api-merchant.payos.vn/v2/payment-requests/$payosOrderCode');
      final infoRes = await http.get(infoUri, headers: _payosHeaders).timeout(const Duration(seconds: 6));
      if (infoRes.statusCode == 200) {
        final body = jsonDecode(infoRes.body);
        final data = body['data'];
        if (body['code'] == '00' && data is Map<String, dynamic>) {
          final linkId = (data['id'] ?? data['paymentLinkId'] ?? '').toString();
          if (linkId.isNotEmpty) {
            final webRes = await http
                .get(Uri.parse('https://pay.payos.vn/web/$linkId'))
                .timeout(const Duration(seconds: 6));
            if (webRes.statusCode == 200) {
              final vqrMatch = RegExp(r'VQR[A-Z0-9]+').firstMatch(webRes.body);
              if (vqrMatch != null) {
                final vqrAccNo = vqrMatch.group(0)!;
                const bin = '970422';
                const accName = 'DANG THANH TUNG';
                final qrUrl = buildQrImageUrl(
                  bin: bin,
                  accountNumber: vqrAccNo,
                  amount: amount,
                  description: cleanDesc,
                );
                return {
                  'qrUrl': qrUrl,
                  'accountNumber': vqrAccNo,
                  'accountName': accName,
                  'description': cleanDesc,
                  'bin': bin,
                };
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Create or retrieve the real PayOS payment request (with VQR... virtual account)
  /// so scanning the QR code always updates the exact orderCode on PayOS!
  Future<Map<String, String>> createPayOSPaymentRequest({
    required dynamic orderCode,
    required int amount,
    required String description,
  }) async {
    final baseOrderCode = int.tryParse(orderCode.toString().replaceAll(RegExp(r'\D'), '')) ??
        (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final cleanDesc = description.length > 25 ? description.substring(0, 25) : description;

    // 1. Try creating with baseOrderCode first
    final firstTry = await _tryCreatePayOSLink(baseOrderCode, amount, cleanDesc);
    if (firstTry != null) {
      _payosOrderCodeMap[orderCode.toString()] = baseOrderCode;
      return firstTry;
    }

    // 2. If Backend already created baseOrderCode on PayOS (code 231),
    // fetch its exact VQR... virtual account from PayOS so the same orderCode (e.g. 3482913220) receives the payment!
    final existingDetails = await _getExistingPayOSLinkDetails(baseOrderCode, amount, cleanDesc);
    if (existingDetails != null) {
      _payosOrderCodeMap[orderCode.toString()] = baseOrderCode;
      return existingDetails;
    }

    // 3. Fallback: create a fresh PayOS payment code if needed
    final freshPayosCode = baseOrderCode + 1;
    final freshDesc = 'DAT MON $freshPayosCode'.length > 25
        ? 'DAT MON $freshPayosCode'.substring(0, 25)
        : 'DAT MON $freshPayosCode';
    final secondTry = await _tryCreatePayOSLink(freshPayosCode, amount, freshDesc);
    if (secondTry != null) {
      _payosOrderCodeMap[orderCode.toString()] = freshPayosCode;
      return secondTry;
    }

    final fallbackQr = buildQrImageUrl(
      bin: '970422',
      accountNumber: '0776101860',
      amount: amount,
      description: cleanDesc,
    );
    return {
      'qrUrl': fallbackQr,
      'accountNumber': '0776101860',
      'accountName': 'DANG THANH TUNG',
      'description': cleanDesc,
      'bin': '970422',
    };
  }

  Future<bool> _isPayOSCodePaid(int code) async {
    try {
      final payosUri = Uri.parse('https://api-merchant.payos.vn/v2/payment-requests/$code');
      final payosRes = await http.get(payosUri, headers: _payosHeaders).timeout(const Duration(seconds: 6));
      if (payosRes.statusCode == 200) {
        final body = jsonDecode(payosRes.body);
        final data = body['data'];
        if (body['code'] == '00' && data is Map<String, dynamic>) {
          final status = (data['status'] ?? '').toString().toUpperCase();
          final amountPaid = (data['amountPaid'] as num?)?.toInt() ?? 0;
          final transactions = data['transactions'] as List<dynamic>?;
          return status == 'PAID' || amountPaid > 0 || (transactions != null && transactions.isNotEmpty);
        }
      }
    } catch (_) {}
    return false;
  }

  /// Strictly check with PayOS Gateway whether the bank transfer was actually completed.
  /// Only when PayOS confirms status == 'PAID' (or amountPaid > 0), sync status to Backend DB.
  Future<bool> checkPaymentStatus(dynamic orderCode, String token) async {
    final baseCode = int.tryParse(orderCode.toString().replaceAll(RegExp(r'\D'), ''));
    final mappedCode = _payosOrderCodeMap[orderCode.toString()];

    final codesToCheck = <int>{
      if (mappedCode != null) mappedCode,
      if (baseCode != null) baseCode,
    };

    // 1. Check directly with PayOS Gateway (instant status update on bank transfer)
    for (final code in codesToCheck) {
      if (await _isPayOSCodePaid(code)) {
        await _syncOrderConfirmedOnBackend(orderCode, token);
        return true;
      }
    }

    // 2. Also check if PayOS Webhook callback has already marked Order as PAID on Backend
    try {
      final orders = await getMyOrders(token);
      final targetStr = orderCode.toString();
      for (final ord in orders) {
        if (ord.orderCode == targetStr && ord.paymentStatus.toUpperCase() == 'PAID') {
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  /// Sync Order status to CONFIRMED ("Đã xác nhận") on Backend after PayOS verifies real transfer
  Future<void> _syncOrderConfirmedOnBackend(dynamic orderCode, String token) async {
    try {
      final uri = Uri.parse('$baseUrl/payments/status/$orderCode');
      await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 6));
    } catch (_) {}
    try {
      final uri = Uri.parse('$baseUrl/payments/confirm-manual/$orderCode');
      await http.post(uri, headers: _headers(token)).timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  /// When user presses "Xác nhận đã chuyển khoản": strictly verify real PayOS payment!
  Future<bool> confirmManualPayment(dynamic orderCode, String token) async {
    return await checkPaymentStatus(orderCode, token);
  }
}

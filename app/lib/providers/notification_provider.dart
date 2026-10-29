import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../models/notification_item_model.dart';
import '../../services/auth_service.dart';

class NotificationProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  List<NotificationItem> _notifications = [];
  bool _isLoading = false;
  int _unreadCount = 0;
  String? _errorMessage;

  List<NotificationItem> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;
  String? get errorMessage => _errorMessage;

  /// Lọc theo danh mục
  List<NotificationItem> getFilteredNotifications(String category) {
    if (category == 'ALL' || category == 'Tất cả') {
      return _notifications;
    }
    return _notifications.where((n) {
      if (category == 'BOOKING' || category == 'Đặt bàn') {
        return n.category == NotificationCategory.booking;
      }
      if (category == 'ORDER' || category == 'Đơn hàng') {
        return n.category == NotificationCategory.order;
      }
      if (category == 'CHAT' || category == 'Tin nhắn') {
        return n.category == NotificationCategory.chat;
      }
      return n.category == NotificationCategory.system;
    }).toList();
  }

  /// Lấy danh sách thông báo từ API
  Future<void> fetchNotifications({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final token = await _authService.getToken();
      if (token == null) {
        _setMockNotifications();
        _isLoading = false;
        notifyListeners();
        return;
      }

      final url = Uri.parse('${ApiConstants.baseUrl}/notifications');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['data'] as List<dynamic>?) ?? [];
        final loaded = list.map((item) => NotificationItem.fromJson(item)).toList();
        final newUnread = data['unreadCount'] ?? loaded.where((n) => !n.isRead).length;

        final hasChanges = loaded.length != _notifications.length || newUnread != _unreadCount;
        _notifications = loaded;
        _unreadCount = newUnread;

        if (hasChanges || !silent) {
          notifyListeners();
        }
      }
    } catch (_) {
      // Giữ nguyên danh sách hiện tại nếu gặp lỗi mạng
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Đánh dấu 1 thông báo là đã đọc
  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();

      try {
        final token = await _authService.getToken();
        if (token != null) {
          final url = Uri.parse('${ApiConstants.baseUrl}/notifications/$id/read');
          await http.put(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );
        }
      } catch (_) {}
    }
  }

  /// Đánh dấu tất cả thông báo là đã đọc
  Future<void> markAllAsRead() async {
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    _unreadCount = 0;
    notifyListeners();

    try {
      final token = await _authService.getToken();
      if (token != null) {
        final url = Uri.parse('${ApiConstants.baseUrl}/notifications/read-all');
        await http.put(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
    } catch (_) {}
  }

  /// Bắn test Push Notification vào máy hiện tại
  Future<bool> sendTestPush() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return false;

      final url = Uri.parse('${ApiConstants.baseUrl}/notifications/test-push');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        // Tự thêm thông báo mới vào danh sách in-app
        final newNotification = NotificationItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: 'SYSTEM',
          title: 'FConnect Test Push 🔔',
          message: 'Điện thoại của bạn vừa nhận được thông báo đẩy Firebase thành công!',
          createdAt: DateTime.now(),
          isRead: false,
        );
        _notifications.insert(0, newNotification);
        _unreadCount++;
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void _setMockNotifications() {
    _notifications = [
      NotificationItem(
        id: 'mock_n1',
        type: 'BOOKING_CONFIRMED',
        title: 'Đặt bàn thành công! 🎉',
        message: 'Highlands Coffee - Nguyễn Văn Linh đã xác nhận bàn A03 cho 4 người lúc 19:00 hôm nay.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
        isRead: false,
      ),
      NotificationItem(
        id: 'mock_n2',
        type: 'ORDER_PREPARING',
        title: 'Món ăn đang được chế biến 🍳',
        message: 'Bếp trưởng đang thực hiện 2x Phin Sữa Đá và 1x Bánh Mousse Cacao.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 35)),
        isRead: false,
      ),
      NotificationItem(
        id: 'mock_n3',
        type: 'NEW_MESSAGE',
        title: 'Tin nhắn từ Madame Lân 💬',
        message: 'Quán: "Dạ vâng, quán đã chuẩn bị xong chỗ ngồi gần cửa sổ cho gia đình mình rồi ạ."',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: true,
      ),
      NotificationItem(
        id: 'mock_n4',
        type: 'ORDER_READY',
        title: 'Đơn hàng hoàn tất! 🛎️',
        message: 'Đơn hàng #FCO082 của bạn đã sẵn sàng tại quầy nhận món.',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        isRead: true,
      ),
      NotificationItem(
        id: 'mock_n5',
        type: 'SYSTEM',
        title: 'Ưu đãi cuối tuần 20% 🎁',
        message: 'Khám phá ngay danh sách nhà hàng FConnect tại Đà Nẵng với hàng loạt quà tặng hấp dẫn.',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        isRead: true,
      ),
    ];
    _unreadCount = _notifications.where((n) => !n.isRead).length;
  }
}

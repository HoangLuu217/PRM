import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../models/message_model.dart';
import '../../services/auth_service.dart';

class ChatProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  List<ChatConversation> _conversations = [];
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _botTimer;
  String? _activeConversationId;

  List<ChatConversation> get conversations => _conversations;
  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Tải danh sách hội thoại của khách
  Future<void> fetchConversations({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final token = await _authService.getToken();
      if (token == null) {
        if (_conversations.isEmpty) _setMockConversations();
        _isLoading = false;
        notifyListeners();
        return;
      }

      final url = Uri.parse('${ApiConstants.baseUrl}/chat/conversations');
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
        final loaded = list
            .map((c) => ChatConversation.fromJson(c))
            .where((c) => c.businessName != 'Quán ăn đối tác' && c.businessName != 'Nhà hàng FConnect')
            .toList();

        // Lọc chống trùng lặp theo businessId
        final Map<String, ChatConversation> uniqueByBiz = {};
        for (final item in loaded) {
          final key = item.businessId.isNotEmpty ? item.businessId : item.id;
          if (!uniqueByBiz.containsKey(key)) {
            uniqueByBiz[key] = item;
          }
        }

        _conversations = uniqueByBiz.values.toList();
        notifyListeners();
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

  /// Tải tin nhắn trong một cuộc hội thoại
  Future<void> fetchMessages(String conversationId, {String? storeName, String? storeLogo, bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      _messages = []; // Xóa sạch tin nhắn cũ để tránh trùng lặp quán này sang quán khác!
      _activeConversationId = null;
      notifyListeners();
    }

    try {
      final token = await _authService.getToken();
      final user = await _authService.getCachedUser();
      final currentUserId = user?.id;

      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final url = Uri.parse('${ApiConstants.baseUrl}/chat/conversations/$conversationId/messages');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _activeConversationId = data['conversationId']?.toString();

        final list = (data['data'] as List<dynamic>?) ?? [];
        final loaded = list.map((m) => ChatMessage.fromJson(m, currentUserId: currentUserId)).toList();

        // Giữ lại các tin nhắn vừa gửi (optimistic) nếu backend chưa kịp hoàn tất ghi vào DB
        final pendingOptimistic = _messages.where((m) {
          final isPending = m.id.startsWith('temp_') || (int.tryParse(m.id) != null && m.id.length >= 12);
          if (!isPending) return false;
          // Kiểm tra xem backend đã có tin nhắn này chưa
          final alreadySaved = loaded.any((lm) =>
              lm.isFromCustomer == m.isFromCustomer &&
              lm.text == m.text &&
              lm.createdAt.difference(m.createdAt).abs().inSeconds < 25);
          return !alreadySaved;
        }).toList();

        final merged = [...loaded, ...pendingOptimistic];

        if (merged.isNotEmpty) {
          // Nếu có tin nhắn mới thực tế từ phía chủ quán (không phải bot), hủy timer bot ngay lập tức
          final isRealOwnerReply = !merged.last.isFromCustomer &&
              !merged.last.id.startsWith('bot_') &&
              !(merged.last.text.startsWith('Dạ ') && (merged.last.text.contains('quý khách') || merged.last.text.contains('quán')));
          if (isRealOwnerReply) {
            cancelBotTimer();
          }
          final hasChanges = merged.length != _messages.length ||
              (merged.isNotEmpty && _messages.isNotEmpty && merged.last.id != _messages.last.id);
          _messages = merged;
          if (hasChanges || !silent) {
            notifyListeners();
          }
        } else {
          // Quán mới chưa từng nhắn tin: danh sách tin nhắn phải rỗng
          final hadOld = _messages.isNotEmpty;
          _messages = [];
          if (hadOld || !silent) {
            notifyListeners();
          }
        }
      }
    } catch (_) {
      // Giữ nguyên trạng thái nếu gặp lỗi mạng tạm thời
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Khách hàng gửi tin nhắn cho nhà hàng
  Future<bool> sendMessage({
    required String receiverId,
    required String text,
    String? conversationId,
    String? storeName,
    bool isBusinessReceiver = true,
  }) async {
    if (text.trim().isEmpty) return false;

    final targetConvId = _activeConversationId ?? conversationId;

    // Optimistic UI update: Hiện tin nhắn của khách ngay lập tức
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final newMsg = ChatMessage(
      id: tempId,
      conversationId: targetConvId ?? 'temp_conv',
      senderId: 'current_user',
      senderName: 'Bạn',
      text: text.trim(),
      isFromCustomer: true,
      createdAt: DateTime.now(),
    );

    _messages.add(newMsg);
    notifyListeners();

    // Lên lịch bot tự động trả lời sau 14 giây nếu Chủ quán chưa kịp trả lời
    _scheduleBotReply(
      userMessage: text.trim(),
      conversationId: targetConvId,
      receiverId: receiverId,
      storeName: storeName,
    );

    try {
      final token = await _authService.getToken();
      if (token != null) {
        final url = Uri.parse('${ApiConstants.baseUrl}/chat/messages');
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'receiverId': receiverId,
            'businessId': receiverId,
            if (targetConvId != null && targetConvId.isNotEmpty) 'conversationId': targetConvId,
            'text': text.trim(),
            'isBusinessReceiver': isBusinessReceiver,
          }),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200 || response.statusCode == 201) {
          final resData = jsonDecode(response.body);
          if (resData['conversationId'] != null) {
            _activeConversationId = resData['conversationId'].toString();
          }
        }
      }

      return true;
    } catch (e) {
      debugPrint('[Chat Error]: $e');
      return true;
    }
  }

  /// Lên lịch bot thông minh phản hồi sau đúng 14 giây
  void _scheduleBotReply({
    required String userMessage,
    String? conversationId,
    required String receiverId,
    String? storeName,
  }) {
    _botTimer?.cancel();
    _botTimer = Timer(const Duration(seconds: 14), () async {
      // Sau 14s, nếu tin nhắn cuối cùng vẫn là của khách hàng (chủ quán chưa rep)
      if (_messages.isNotEmpty && _messages.last.isFromCustomer) {
        final replyText = _generateBotReply(userMessage);
        final targetConvId = _activeConversationId ?? conversationId;
        final botMsg = ChatMessage(
          id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
          conversationId: targetConvId ?? '',
          senderId: 'bot_auto',
          senderName: '${storeName ?? 'Quán ăn'} (Tự động)',
          text: replyText,
          isFromCustomer: false,
          createdAt: DateTime.now(),
        );

        _messages.add(botMsg);
        notifyListeners();

        // Lưu vào backend để lần sau mở lại vẫn còn
        try {
          final token = await _authService.getToken();
          if (token != null) {
            await http.post(
              Uri.parse('${ApiConstants.baseUrl}/chat/messages'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'receiverId': receiverId,
                'businessId': receiverId,
                if (targetConvId != null && targetConvId.isNotEmpty) 'conversationId': targetConvId,
                'text': replyText,
                'isBusinessReceiver': false,
                'isBotReply': true,
              }),
            );
          }
        } catch (_) {}
      }
    });
  }

  void cancelBotTimer() {
    _botTimer?.cancel();
  }

  String _generateBotReply(String userMessage) {
    final lower = userMessage.toLowerCase();
    if (lower.contains('bàn') || lower.contains('chỗ') || lower.contains('đặt') || lower.contains('book')) {
      return 'Dạ quán hiện vẫn còn bàn phục vụ quý khách ạ! Quý khách có thể bấm nút "Đặt bàn ngay" ở bên dưới để quán giữ chỗ đẹp nhất cho mình nhé! 🪑✨';
    } else if (lower.contains('món') || lower.contains('menu') || lower.contains('giá') || lower.contains('thực đơn')) {
      return 'Dạ quán có thực đơn phong phú với nhiều món ngon tươi mới mỗi ngày. Quý khách vào mục "Xem Menu" để tham khảo giá và chọn món ưng ý nhé ạ! 🍽️';
    } else if (lower.contains('mở cửa') || lower.contains('giờ') || lower.contains('đóng cửa') || lower.contains('hoạt động')) {
      return 'Dạ quán mở cửa phục vụ từ 07:00 đến 22:30 tất cả các ngày trong tuần ạ! Rất hân hạnh được đón tiếp quý khách! 🕒';
    } else if (lower.contains('đậu xe') || lower.contains('ô tô') || lower.contains('xe máy') || lower.contains('bãi xe')) {
      return 'Dạ quán có bãi đỗ xe máy và ô tô rộng rãi, hoàn toàn miễn phí và có nhân viên trông giữ an toàn ạ! 🚗🛵';
    } else {
      return 'Dạ cảm ơn quý khách đã nhắn tin cho quán! Quán đã ghi nhận tin nhắn và quản lý sẽ phản hồi quý khách sớm nhất nhé ạ! Quý khách cần hỗ trợ thêm thông tin gì cứ để lại lời nhắn ạ! 😊';
    }
  }

  void _setMockConversations() {
    _conversations = [
      ChatConversation(
        id: 'mock_c1',
        businessId: 'biz_01',
        businessName: 'Highlands Coffee - Nguyễn Văn Linh',
        businessLogo: 'https://images.unsplash.com/photo-1559925393-8be0ec4767c8?auto=format&fit=crop&w=400&q=80',
        lastMessage: 'Dạ quán hiện vẫn còn bàn phục vụ quý khách ạ!',
        lastMessageAt: DateTime.now().subtract(const Duration(minutes: 5)),
        unreadCount: 1,
      ),
      ChatConversation(
        id: 'mock_c2',
        businessId: 'biz_02',
        businessName: 'Madame Lân Restaurant',
        businessLogo: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=400&q=80',
        lastMessage: 'Chúc quý khách có bữa ăn ngon miệng!',
        lastMessageAt: DateTime.now().subtract(const Duration(hours: 3)),
        unreadCount: 0,
      ),
    ];
  }

  void _setMockMessages({String? storeName}) {
    final name = storeName ?? 'Chủ Quán FConnect';
    _messages = [
      ChatMessage(
        id: 'm1',
        conversationId: 'mock_conv',
        senderId: 'store_owner',
        senderName: name,
        text: 'Xin chào quý khách! $name rất vui được hỗ trợ bạn. Quý khách cần đặt bàn hay tư vấn món ăn nào hôm nay ạ?',
        isFromCustomer: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
    ];
  }
}

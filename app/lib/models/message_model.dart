class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String text;
  final String? imageUrl;
  final bool isFromCustomer;
  final DateTime createdAt;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.text,
    this.imageUrl,
    required this.isFromCustomer,
    required this.createdAt,
    this.isRead = true,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final sender = json['senderId'];
    String sId = '';
    String sName = 'Quán ăn';
    String? sAvatar;

    if (sender is Map<String, dynamic>) {
      sId = sender['_id']?.toString() ?? sender['id']?.toString() ?? '';
      sName = sender['fullName']?.toString() ?? sender['name']?.toString() ?? 'Người dùng';
      sAvatar = sender['avatarUrl']?.toString();
    } else if (sender != null) {
      sId = sender.toString();
    }

    final rawText = json['text']?.toString() ?? json['message']?.toString() ?? '';
    final isBotReply = rawText.startsWith('Dạ ') && (rawText.contains('quý khách') || rawText.contains('quán'));
    final isCustomer = isBotReply ? false : (currentUserId != null ? (sId == currentUserId) : true);

    return ChatMessage(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: json['conversationId']?.toString() ?? '',
      senderId: sId,
      senderName: isBotReply ? 'Trợ lý nhà hàng (Tự động)' : sName,
      senderAvatar: sAvatar,
      text: rawText,
      imageUrl: json['imageUrl']?.toString(),
      isFromCustomer: isCustomer,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['isRead'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'text': text,
      'imageUrl': imageUrl,
      'isFromCustomer': isFromCustomer,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }
}

class ChatConversation {
  final String id;
  final String businessId;
  final String businessName;
  final String? businessLogo;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;

  ChatConversation({
    required this.id,
    required this.businessId,
    required this.businessName,
    this.businessLogo,
    required this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final biz = json['businessId'];
    String bId = '';
    String bName = '';
    String? bLogo;

    if (biz is Map<String, dynamic>) {
      bId = biz['_id']?.toString() ?? biz['id']?.toString() ?? '';
      bName = biz['name']?.toString() ?? '';
      bLogo = biz['logoUrl']?.toString();
    } else if (biz != null) {
      bId = biz.toString();
    }

    if (bName.isEmpty) {
      bName = 'Quán ăn đối tác';
    }

    return ChatConversation(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      businessId: bId,
      businessName: bName,
      businessLogo: bLogo,
      lastMessage: json['lastMessage']?.toString() ?? 'Bắt đầu cuộc trò chuyện',
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      unreadCount: json['unreadCount'] ?? 0,
    );
  }
}

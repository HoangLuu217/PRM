import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/message_model.dart';
import '../../../models/restaurant_model.dart';
import '../../../providers/chat_provider.dart';
import '../booking/booking_screen.dart';

class CustomerChatScreen extends StatefulWidget {
  final RestaurantModel? restaurant;
  final String? storeName;
  final String? storeLogo;
  final String? storeId;

  const CustomerChatScreen({
    super.key,
    this.restaurant,
    this.storeName,
    this.storeLogo,
    this.storeId,
  });

  @override
  State<CustomerChatScreen> createState() => _CustomerChatScreenState();
}

class _CustomerChatScreenState extends State<CustomerChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isComposing = false;
  bool _showEmojiPicker = false;
  bool _showBotReplies = true; // Mặc định bật hiển thị bot (khi chưa có chủ quán trả lời)
  final Set<String> _dismissedBotMessageIds = {};
  Timer? _pollingTimer;

  String get _effectiveName =>
      widget.restaurant?.name ?? widget.storeName ?? 'Nhà Hàng FConnect';

  String get _effectiveLogo =>
      widget.restaurant?.logoUrl ??
      widget.restaurant?.coverImageUrl ??
      widget.storeLogo ??
      'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=300&q=80';

  String get _effectiveId =>
      widget.restaurant?.id ?? widget.storeId ?? 'biz_default';

  int _prevMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.fetchMessages(
        _effectiveId,
        storeName: _effectiveName,
        storeLogo: _effectiveLogo,
      );
      _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (mounted) {
          chatProvider.fetchMessages(
            _effectiveId,
            storeName: _effectiveName,
            storeLogo: _effectiveLogo,
            silent: true,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    Provider.of<ChatProvider>(context, listen: false).cancelBotTimer();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage([String? presetText]) {
    final textToSend = presetText ?? _textController.text;
    if (textToSend.trim().isEmpty) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.sendMessage(
      receiverId: _effectiveId,
      text: textToSend,
      conversationId: _effectiveId,
      storeName: _effectiveName,
      isBusinessReceiver: true,
    );

    _textController.clear();
    setState(() => _isComposing = false);

    Future.delayed(const Duration(milliseconds: 150), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final rawMessages = chatProvider.messages;

    final messages = <ChatMessage>[];

    for (int i = 0; i < rawMessages.length; i++) {
      final msg = rawMessages[i];
      if (_dismissedBotMessageIds.contains(msg.id)) continue;

      final isBot = msg.id.startsWith('bot_') ||
          (msg.text.startsWith('Dạ ') && (msg.text.contains('quý khách') || msg.text.contains('quán')));

      if (isBot) {
        // Nếu khách hàng tắt chế độ bot bằng icon con bot ở dưới:
        if (!_showBotReplies) continue;

        // Tự động ẩn tin nhắn bot nếu chủ quán đã thực tế trả lời PHÍA SAU tin nhắn bot này:
        final hasOwnerReplyAfter = rawMessages.sublist(i + 1).any((laterMsg) =>
            !laterMsg.isFromCustomer &&
            !laterMsg.id.startsWith('bot_') &&
            !(laterMsg.text.startsWith('Dạ ') && (laterMsg.text.contains('quý khách') || laterMsg.text.contains('quán'))));

        if (hasOwnerReplyAfter) {
          continue; // Chủ shop đã nhắn lại sau đoạn bot này -> ẩn tin nhắn bot này đi!
        }
      }

      messages.add(msg);
    }

    if (messages.length != _prevMessageCount) {
      _prevMessageCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Danh sách tin nhắn
            Expanded(
              child: chatProvider.isLoading && messages.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF0072FF)),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final showDateHeader = index == 0 ||
                            _shouldShowDateHeader(msg, messages[index - 1]);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDateHeader) _buildDateHeader(msg.createdAt),
                            _buildMessageBubble(msg),
                          ],
                        );
                      },
                    ),
            ),

            // Khung nhập tin nhắn
            _buildInputBar(),

            // Bảng chọn Emoji & Biểu tượng cảm xúc
            if (_showEmojiPicker) _buildEmojiPickerPanel(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // APPBAR
  // ==========================================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0072FF).withValues(alpha: 0.2), width: 1.5),
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFEFF6FF),
                  backgroundImage: NetworkImage(_effectiveLogo),
                  onBackgroundImageError: (_, __) {},
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981), // Online green
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _effectiveName,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Row(
                  children: [
                    Icon(Icons.bolt_rounded, size: 13, color: Color(0xFF10B981)),
                    SizedBox(width: 2),
                    Text(
                      'Đang hoạt động • Trả lời sau 2 phút',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (widget.restaurant != null)
          IconButton(
            icon: const Icon(Icons.table_restaurant_rounded, color: Color(0xFF0072FF)),
            tooltip: 'Đặt bàn ngay',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookingScreen(restaurant: widget.restaurant!),
                ),
              );
            },
          ),
        const SizedBox(width: 4),
      ],
    );
  }


  // ==========================================
  // MESSAGE BUBBLE
  // ==========================================
  Widget _buildMessageBubble(ChatMessage msg) {
    final isMe = msg.isFromCustomer;
    final isBot = !isMe &&
        (msg.id.startsWith('bot_') || (msg.text.startsWith('Dạ ') && (msg.text.contains('quý khách') || msg.text.contains('quán'))));
    final timeStr = '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFFE2E8F0),
              backgroundImage: NetworkImage(_effectiveLogo),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                        colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isMe ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isMe ? 0.08 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (isBot) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.smart_toy_rounded, size: 11, color: Color(0xFF2563EB)),
                              SizedBox(width: 3),
                              Text('Trợ lý tự động', style: TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => setState(() => _dismissedBotMessageIds.add(msg.id)),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.close_rounded, size: 12, color: Color(0xFF94A3B8)),
                                SizedBox(width: 2),
                                Text('Ẩn', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (msg.imageUrl != null && msg.imageUrl!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        msg.imageUrl!,
                        width: 220,
                        height: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(),
                      ),
                    ),
                    if (msg.text.isNotEmpty) const SizedBox(height: 6),
                  ],
                  if (msg.text.isNotEmpty)
                    Text(
                      msg.text,
                      style: TextStyle(
                        color: isMe ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 14.5,
                        height: 1.35,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: isMe ? Colors.white.withValues(alpha: 0.75) : const Color(0xFF94A3B8),
                          fontSize: 10.5,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all_rounded,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ==========================================
  // DATE HEADER
  // ==========================================
  bool _shouldShowDateHeader(ChatMessage current, ChatMessage previous) {
    return current.createdAt.day != previous.createdAt.day ||
        current.createdAt.month != previous.createdAt.month;
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    String label = '${date.day}/${date.month}/${date.year}';
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      label = 'Hôm nay';
    } else if (date.day == now.day - 1 && date.month == now.month) {
      label = 'Hôm qua';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ==========================================
  // INPUT BAR
  // ==========================================
  // ==========================================
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // Nút đính kèm ảnh mẫu
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF64748B), size: 24),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tính năng chia sẻ ảnh chụp đang được đồng bộ'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),

          // Icon con bot ở dưới cùng để khách hàng bật/ẩn bot tự động
          IconButton(
            icon: Icon(
              _showBotReplies ? Icons.smart_toy_rounded : Icons.smart_toy_outlined,
              color: _showBotReplies ? const Color(0xFF0072FF) : const Color(0xFF94A3B8),
              size: 23,
            ),
            tooltip: _showBotReplies ? 'Đang bật bot (Bấm để ẩn)' : 'Đang ẩn bot (Bấm để bật)',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            onPressed: () {
              setState(() => _showBotReplies = !_showBotReplies);
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _showBotReplies
                        ? '🤖 Đã bật hiển thị trợ lý bot tự động'
                        : '🤖 Đã ẩn toàn bộ tin nhắn bot tự động',
                  ),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(width: 4),

          // Ô nhập văn bản + Nút Emoji
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(left: 14, right: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textCapitalization: TextCapitalization.sentences,
                      onTap: () {
                        if (_showEmojiPicker) {
                          setState(() => _showEmojiPicker = false);
                        }
                      },
                      onChanged: (val) {
                        setState(() => _isComposing = val.trim().isNotEmpty);
                      },
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Nhắn tin cho quán...',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _showEmojiPicker ? Icons.keyboard_rounded : Icons.sentiment_satisfied_alt_rounded,
                      color: const Color(0xFF0072FF),
                      size: 24,
                    ),
                    tooltip: 'Chọn icon biểu cảm',
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      setState(() => _showEmojiPicker = !_showEmojiPicker);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Nút bên phải: Nếu chưa gõ thì hiện nút Like 👍, nếu đã gõ thì hiện nút Gửi ✈️
          if (!_isComposing)
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEFF6FF),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: IconButton(
                icon: const Icon(Icons.thumb_up_rounded, color: Color(0xFF0072FF), size: 20),
                tooltip: 'Thích',
                padding: EdgeInsets.zero,
                onPressed: () => _sendMessage('👍'),
              ),
            )
          else
            GestureDetector(
              onTap: () => _sendMessage(),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0072FF).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Bảng chọn Emoji & Biểu tượng cảm xúc phong cách Messenger
  Widget _buildEmojiPickerPanel() {
    final emojiCategories = {
      'Mặt cười': ['😊', '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '😉', '😇', '🥰', '😍', '🤩', '😘', '😋', '😎', '🥳', '🤗', '👍', '👌', '🤝', '👏', '🙏', '❤️', '💖'],
      'Món ăn & Bàn tiệc': ['🍽️', '🥩', '🍕', '🍔', '🥗', '🍝', '🍜', '🍲', '🍣', '🍤', '🍷', '🥂', '🍻', '🍹', '☕', '🍰', '🎂', '🪑', '🕯️', '💐'],
      'Nhà hàng & Tiện ích': ['✨', '🔥', '🎉', '⭐', '📍', '🕒', '📞', '🚗', '🛵', '💯', '✅', '💬', '🎁', '🎈', '🏷️', '🔔'],
    };

    return Container(
      height: 220,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: DefaultTabController(
        length: emojiCategories.length,
        child: Column(
          children: [
            Container(
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: const Color(0xFF0072FF),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                indicatorColor: const Color(0xFF0072FF),
                indicatorWeight: 2.5,
                tabs: emojiCategories.keys.map((k) => Tab(text: k)).toList(),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: emojiCategories.values.map((emojis) {
                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                    ),
                    itemCount: emojis.length,
                    itemBuilder: (context, idx) {
                      final em = emojis[idx];
                      return InkWell(
                        onTap: () {
                          _textController.text += em;
                          _textController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _textController.text.length),
                          );
                          setState(() => _isComposing = true);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Center(
                          child: Text(em, style: const TextStyle(fontSize: 22)),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

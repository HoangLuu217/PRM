import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/message_model.dart';
import '../../../providers/chat_provider.dart';
import 'customer_chat_screen.dart';

class CustomerChatInboxScreen extends StatefulWidget {
  final bool isTab;
  const CustomerChatInboxScreen({super.key, this.isTab = false});

  @override
  State<CustomerChatInboxScreen> createState() => _CustomerChatInboxScreenState();
}

class _CustomerChatInboxScreenState extends State<CustomerChatInboxScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';
  Timer? _inboxPollingTimer;

  // Danh sách quán đề xuất khi khách hàng chưa có tin nhắn hoặc muốn nhắn nhanh
  final List<Map<String, String>> _featuredRestaurants = [
    {
      'id': 'biz_highlands',
      'name': 'Highlands Coffee - Nguyễn Văn Linh',
      'logo': 'https://images.unsplash.com/photo-1559925393-8be0ec4767c8?auto=format&fit=crop&w=400&q=80',
      'category': 'Cà phê & Bánh ngọt',
    },
    {
      'id': 'biz_madamelan',
      'name': 'Madame Lân Restaurant',
      'logo': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=400&q=80',
      'category': 'Ẩm thực Việt & Miền Trung',
    },
    {
      'id': 'biz_pizza4ps',
      'name': 'Pizza 4P\'s - Hoàng Văn Thụ',
      'logo': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=400&q=80',
      'category': 'Pizza & Món Ý cao cấp',
    },
    {
      'id': 'biz_goldenbeef',
      'name': 'Golden Beef Steakhouse',
      'logo': 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
      'category': 'Bò bít tết & Rượu vang',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.fetchConversations();

      _inboxPollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted) {
          chatProvider.fetchConversations(silent: true);
        }
      });
    });
  }

  @override
  void dispose() {
    _inboxPollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildRestaurantAvatar({required String name, required String? logoUrl, required double radius}) {
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join('').toUpperCase()
        : 'F&B';

    final validUrl = logoUrl != null &&
        logoUrl.trim().isNotEmpty &&
        logoUrl != 'null' &&
        (logoUrl.startsWith('http://') || logoUrl.startsWith('https://'));

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFEFF6FF),
      child: ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: validUrl
              ? Image.network(
                  logoUrl,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFFEFF6FF),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: radius * 0.72,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                )
              : Container(
                  color: const Color(0xFFEFF6FF),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: radius * 0.72,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Vừa xong';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}p';
    } else if (diff.inDays < 1 && now.day == time.day) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 2) {
      return 'Hôm qua';
    } else if (diff.inDays < 7) {
      final days = ['CN', 'Th 2', 'Th 3', 'Th 4', 'Th 5', 'Th 6', 'Th 7'];
      return days[time.weekday % 7];
    } else {
      return '${time.day}/${time.month}';
    }
  }

  void _openChat(ChatConversation conv) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerChatScreen(
          storeId: conv.businessId,
          storeName: conv.businessName,
          storeLogo: conv.businessLogo,
        ),
      ),
    ).then((_) {
      if (mounted) {
        Provider.of<ChatProvider>(context, listen: false).fetchConversations(silent: true);
      }
    });
  }

  void _openChatWithRestaurant(Map<String, String> res) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerChatScreen(
          storeId: res['id']!,
          storeName: res['name']!,
          storeLogo: res['logo']!,
        ),
      ),
    ).then((_) {
      if (mounted) {
        Provider.of<ChatProvider>(context, listen: false).fetchConversations(silent: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final rawConversations = chatProvider.conversations.where((c) {
      return c.businessName != 'Quán ăn đối tác' &&
          c.businessName != 'Nhà hàng FConnect' &&
          c.businessName.trim().isNotEmpty;
    }).toList();

    // Deduplicate theo businessId
    final Map<String, ChatConversation> uniqueByBiz = {};
    for (final c in rawConversations) {
      final key = c.businessId.isNotEmpty ? c.businessId : c.id;
      if (!uniqueByBiz.containsKey(key)) {
        uniqueByBiz[key] = c;
      }
    }
    final allConversations = uniqueByBiz.values.toList();

    final filteredConversations = allConversations.where((c) {
      if (_searchKeyword.isEmpty) return true;
      final q = _searchKeyword.toLowerCase();
      return c.businessName.toLowerCase().contains(q) ||
          c.lastMessage.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        automaticallyImplyLeading: !widget.isTab,
        leading: widget.isTab
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
                onPressed: () => Navigator.pop(context),
              ),
        title: const Text(
          'Trò chuyện',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
            tooltip: 'Làm mới hộp thư',
            onPressed: () => chatProvider.fetchConversations(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => chatProvider.fetchConversations(),
        color: const Color(0xFF2563EB),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // 1. Thanh tìm kiếm phong cách Messenger
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _searchController,
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm quán ăn, tin nhắn...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                      suffixIcon: _searchKeyword.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchKeyword = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onChanged: (val) => setState(() => _searchKeyword = val.trim()),
                  ),
                ),
              ),
            ),

            // 2. Dải quán ăn đang mở cửa / Nhắn để chat nhanh (Top Story Bar)
            SliverToBoxAdapter(
              child: Container(
                height: 106,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: _featuredRestaurants.length,
                  itemBuilder: (context, idx) {
                    final res = _featuredRestaurants[idx];
                    return InkWell(
                      onTap: () => _openChatWithRestaurant(res),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 76,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              children: [
                                _buildRestaurantAvatar(
                                  name: res['name']!,
                                  logoUrl: res['logo']!,
                                  radius: 26,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              res['name']!.split(' - ').first,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            ),

            // 3. Danh sách các cuộc trò chuyện thực tế
            if (chatProvider.isLoading && allConversations.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                ),
              )
            else if (filteredConversations.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEFF6FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.forum_rounded,
                          size: 40,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchKeyword.isEmpty
                            ? 'Chưa có cuộc trò chuyện nào'
                            : 'Không tìm thấy quán ăn phù hợp',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchKeyword.isEmpty
                            ? 'Chọn một quán ăn nổi bật ở trên để bắt đầu trò chuyện, đặt bàn và nhận tư vấn nhanh chóng!'
                            : 'Thử tìm với tên quán ăn khác hoặc xóa từ khóa tìm kiếm.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final conv = filteredConversations[index];
                    final isUnread = conv.unreadCount > 0;

                    return Material(
                      color: Colors.white,
                      child: InkWell(
                        onTap: () => _openChat(conv),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              // Avatar Quán ăn có chấm xanh trực tuyến
                              Stack(
                                children: [
                                  _buildRestaurantAvatar(
                                    name: conv.businessName,
                                    logoUrl: conv.businessLogo,
                                    radius: 28,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 13,
                                      height: 13,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),

                              // Tên quán & Tin nhắn cuối
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            conv.businessName,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                                              color: const Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatTime(conv.lastMessageAt),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                            color: isUnread ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            conv.lastMessage,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.normal,
                                              color: isUnread ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isUnread) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF2563EB),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: filteredConversations.length,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

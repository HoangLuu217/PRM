import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/file_picker_helper.dart';
import '../../models/user_model.dart';
import '../../models/booking_model.dart';
import '../../models/notification_item_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/table_provider.dart';
import '../../providers/user_provider.dart';
import '../auth/login_screen.dart';
import '../auth/profile_screen.dart';
import '../customer/customer_home_screen.dart';
import 'owner_booking_screen.dart';
import 'owner_order_screen.dart';
import 'owner_table_screen.dart';
import 'widgets/merchant_onboarding_dialog.dart';

class OwnerDashboardScreen extends StatefulWidget {
  final bool showOnboardingImmediately;
  final int initialTabIndex;

  const OwnerDashboardScreen({
    super.key,
    this.showOnboardingImmediately = false,
    this.initialTabIndex = 0,
  });

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  late int _selectedTab;
  bool _hasCheckedOnboarding = false;
  TextEditingController? _searchHeaderController;
  TextEditingController get _searchController => _searchHeaderController ??= TextEditingController();

  int _selectedChatIndex = 0;
  bool _mobileViewingChat = false;
  bool _showEmojiPicker = false;
  bool _showPhotoTray = false;
  bool _hideBotMessages = false; // Mặc định hiển thị bot (tự ẩn khi chủ quán trả lời)
  String _chatSearchKeyword = '';
  final TextEditingController _ownerChatMessageController = TextEditingController();
  final ScrollController _ownerChatScrollController = ScrollController();

  int get _totalUnreadChatCount => _conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);

  final List<_OwnerChatConversation> _conversations = [];

  Timer? _chatPollingTimer;
  Timer? _notifPollingTimer;

  @override
  void dispose() {
    _chatPollingTimer?.cancel();
    _notifPollingTimer?.cancel();
    _searchHeaderController?.dispose();
    _ownerChatMessageController.dispose();
    _ownerChatScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptOnboarding();
      _loadDashboardData();
      Provider.of<NotificationProvider>(context, listen: false).fetchNotifications(silent: true);
      _notifPollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted) {
          Provider.of<NotificationProvider>(context, listen: false).fetchNotifications(silent: true);
        }
      });
      if (_selectedTab == 4) {
        _onTabSelected(4);
      }
    });
  }

  void _onTabSelected(int index) {
    setState(() => _selectedTab = index);
    if (index == 4) {
      _fetchRealOwnerConversations();
      _chatPollingTimer?.cancel();
      _chatPollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (mounted && _selectedTab == 4) {
          _pollChatUpdates();
        }
      });
    } else {
      _chatPollingTimer?.cancel();
    }
  }

  Future<void> _pollChatUpdates() async {
    if (_selectedChatIndex >= 0 && _selectedChatIndex < _conversations.length) {
      final currentConv = _conversations[_selectedChatIndex];
      if (currentConv.realConversationId != null) {
        await _fetchRealMessages(currentConv, silent: true);
      }
    }
    await _fetchRealOwnerConversations(silent: true);
  }

  Future<void> _fetchRealOwnerConversations({bool silent = false}) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;

    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/chat/conversations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true && decoded['data'] is List) {
          final list = decoded['data'] as List;
          final List<_OwnerChatConversation> realConvs = [];

          for (final item in list) {
            final realId = item['_id']?.toString() ?? '';
            final customer = item['customerId'];
            String custName = 'Khách hàng';
            String custPhone = '';
            String custAvatar = '';
            String customerId = '';

            if (customer is Map) {
              custName = (customer['fullName']?.toString().trim().isNotEmpty == true)
                  ? customer['fullName'].toString().trim()
                  : 'Khách hàng';
              custPhone = customer['phone']?.toString().trim() ?? '';
              final rawAvatar = customer['avatarUrl']?.toString().trim() ?? '';
              if (rawAvatar.isNotEmpty && rawAvatar != 'null') {
                custAvatar = rawAvatar;
              }
              customerId = customer['_id']?.toString() ?? '';
            }

            if (custAvatar.isEmpty) {
              custAvatar = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(custName)}&background=E11D48&color=fff&bold=true&size=128';
            }

            final lastMsgAt = item['lastMessageAt'] != null ? DateTime.tryParse(item['lastMessageAt'].toString()) : null;
            final timeStr = lastMsgAt != null
                ? '${lastMsgAt.hour.toString().padLeft(2, '0')}:${lastMsgAt.minute.toString().padLeft(2, '0')}'
                : 'Vừa xong';

            final lastMsgText = item['lastMessage']?.toString() ?? '';

            final existingIndex = _conversations.indexWhere((c) => c.realConversationId == realId);
            final List<_OwnerChatMessage> existingMsgs = existingIndex >= 0 ? _conversations[existingIndex].messages : [];

            realConvs.add(
              _OwnerChatConversation(
                id: realId,
                realConversationId: realId,
                customerId: customerId,
                customerName: custName,
                customerPhone: custPhone.isNotEmpty ? custPhone : 'Chưa cập nhật SĐT',
                avatarUrl: custAvatar,
                bookingInfo: 'Khách hàng nhắn tin trực tiếp từ App',
                lastTime: timeStr,
                unreadCount: 0,
                messages: existingMsgs.isNotEmpty
                    ? existingMsgs
                    : [
                        if (lastMsgText.isNotEmpty)
                          _OwnerChatMessage(
                            id: 'last_$realId',
                            text: lastMsgText,
                            time: timeStr,
                            isFromOwner: false,
                          ),
                      ],
              ),
            );
          }

          if (mounted) {
            setState(() {
              _conversations.clear();
              _conversations.addAll(realConvs);
            });
            if (_selectedChatIndex >= _conversations.length) {
              _selectedChatIndex = _conversations.isNotEmpty ? 0 : -1;
            }
            if (!silent && _conversations.isNotEmpty && _selectedChatIndex >= 0) {
              _fetchRealMessages(_conversations[_selectedChatIndex]);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[OwnerChat] Fetch conversations error: $e');
    }
  }

  Future<void> _fetchRealMessages(_OwnerChatConversation conv, {bool silent = false}) async {
    if (conv.realConversationId == null) return;
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;

    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/chat/conversations/${conv.realConversationId}/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true && decoded['data'] is List) {
          final msgs = decoded['data'] as List;
          final currentUserId = Provider.of<AuthProvider>(context, listen: false).user?.id;
          final List<_OwnerChatMessage> loadedMessages = [];

          for (final m in msgs) {
            final mId = m['_id']?.toString() ?? '';
            final text = m['text']?.toString() ?? '';
            final imageUrl = m['imageUrl']?.toString();
            final createdAt = m['createdAt'] != null ? DateTime.tryParse(m['createdAt'].toString()) : null;
            final timeStr = createdAt != null
                ? '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
                : '';

            final sender = m['senderId'];
            String senderId = '';
            String senderRole = '';
            if (sender is Map) {
              senderId = sender['_id']?.toString() ?? '';
              senderRole = sender['role']?.toString().toUpperCase() ?? '';
            } else if (sender is String) {
              senderId = sender;
            }

            final isBotMsg = text.startsWith('Dạ ') && (text.contains('quý khách') || text.contains('quán'));
            final isOwnerMsg = (currentUserId != null && senderId == currentUserId) ||
                senderRole == 'MERCHANT' ||
                senderRole == 'OWNER' ||
                senderRole == 'BUSINESS_OWNER' ||
                isBotMsg;

            loadedMessages.add(
              _OwnerChatMessage(
                id: mId,
                text: text,
                imageUrl: imageUrl,
                time: timeStr,
                isFromOwner: isOwnerMsg,
              ),
            );
          }

          final oldCount = conv.messages.length;
          final hasNew = loadedMessages.length != oldCount ||
              (loadedMessages.isNotEmpty && conv.messages.isNotEmpty && loadedMessages.last.id != conv.messages.last.id);

          if (mounted) {
            setState(() {
              conv.messages.clear();
              conv.messages.addAll(loadedMessages);
            });
            if (!silent || hasNew) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_ownerChatScrollController.hasClients) {
                  _ownerChatScrollController.animateTo(
                    _ownerChatScrollController.position.maxScrollExtent + 200,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                }
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[OwnerChat] Fetch messages error: $e');
    }
  }

  void _loadDashboardData() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    String? branchId;
    if (user?.business != null) {
      final biz = user!.business!;
      if (biz['branches'] is List && (biz['branches'] as List).isNotEmpty) {
        final b = (biz['branches'] as List)[0];
        if (b is Map) branchId = (b['_id'] ?? b['id'])?.toString();
      }
      if (branchId == null && biz['primaryBranch'] is Map) {
        branchId = (biz['primaryBranch']['_id'] ?? biz['primaryBranch']['id'])?.toString();
      }
      branchId ??= (biz['_id'] ?? biz['id'])?.toString();
    }

    Provider.of<BookingProvider>(context, listen: false).fetchOwnerBookings();
    Provider.of<TableProvider>(context, listen: false).fetchTables(branchId: branchId);
    Provider.of<OrderProvider>(context, listen: false).fetchOwnerOrders();
    _fetchRealOwnerConversations();
  }

  void _checkAndPromptOnboarding() {
    if (_hasCheckedOnboarding || !mounted) return;
    _hasCheckedOnboarding = true;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final hasBusiness = user?.business != null &&
        (user?.business?['name']?.toString() ?? '').trim().isNotEmpty;

    // Nếu tài khoản là Khách hàng (USER) và không sở hữu cơ sở F&B:
    // Trên Web: Đăng xuất và đưa về LoginScreen (cổng web chỉ dành cho Chủ quán)
    // Trên Mobile: Chuyển sang Giao diện Khách hàng (CustomerHomeScreen)
    if (!authProvider.isOwner && !hasBusiness) {
      if (kIsWeb) {
        authProvider.logout();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
        );
      }
      return;
    }

    if (widget.showOnboardingImmediately || !hasBusiness) {
      MerchantOnboardingDialog.show(context, onCompleted: () {
        if (mounted) setState(() {});
      });
    }
  }

  void _openOnboardingForm() {
    MerchantOnboardingDialog.show(context, onCompleted: () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _launchGoogleMaps(String url) async {
    if (url.trim().isEmpty) return;
    try {
      final uri = Uri.parse(url.trim());
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Launch map url error: $e');
    }
  }

  void _showStorefrontPreview(Map<String, dynamic>? biz, User? user) {
    final businessName = biz?['name']?.toString() ?? 'Nhà Hàng Của Bạn';
    final categoryName = biz?['category']?.toString() ?? 'F&B Restaurant';
    final district = biz?['address']?['district']?.toString() ?? biz?['district']?.toString() ?? 'Hải Châu';
    final city = biz?['address']?['city']?.toString() ?? biz?['city']?.toString() ?? 'Đà Nẵng';
    final street = biz?['address']?['street']?.toString() ?? 'Chi nhánh chính';
    final addressFull = '$street, $district, $city';
    final minPrice = biz?['priceRange']?['min'] ?? 20000;
    final maxPrice = biz?['priceRange']?['max'] ?? 100000;
    final priceText = '${(minPrice / 1000).toInt()}k – ${(maxPrice / 1000).toInt()}k VNĐ';
    final vibesList = biz?['vibes'];
    final vibes = (vibesList is List && vibesList.isNotEmpty)
        ? List<String>.from(vibesList)
        : <String>['Yên tĩnh / Làm việc', 'Ấm cúng / Gia đình'];
    final coverVal = biz?['coverImageUrl']?.toString() ?? '';
    final coverImageUrl = coverVal.startsWith('http')
        ? coverVal
        : 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80';
    final logoVal = biz?['logoUrl']?.toString() ?? '';
    final logoUrl = logoVal.startsWith('http')
        ? logoVal
        : 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=300&q=80';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: 580,
          constraints: const BoxConstraints(maxHeight: 700),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Modal
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.remove_red_eye_rounded, color: Color(0xFF2563EB), size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Xem Trước Trang Quán (Customer Storefront View)',
                        style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),

              // Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cover Image & Logo Overlap
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            height: 180,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: NetworkImage(coverImageUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.1),
                                    Colors.white.withValues(alpha: 0.95),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 14,
                            right: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fiber_manual_record_rounded, color: Colors.white, size: 10),
                                  SizedBox(width: 5),
                                  Text('Đang mở cửa', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -32,
                            left: 20,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFF2563EB), width: 2.5),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                              ),
                              child: CircleAvatar(
                                radius: 32,
                                backgroundColor: const Color(0xFFEFF6FF),
                                backgroundImage: NetworkImage(logoUrl),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // Restaurant Info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    businessName,
                                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 16),
                                      SizedBox(width: 4),
                                      Text('4.9 (128)', style: TextStyle(color: Color(0xFFD97706), fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              categoryName,
                              style: const TextStyle(color: Color(0xFF2563EB), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, color: Color(0xFF64748B), size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    addressFull,
                                    style: const TextStyle(color: Color(0xFF475569), fontSize: 12.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.payments_outlined, color: Color(0xFF64748B), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  priceText,
                                  style: const TextStyle(color: Color(0xFF475569), fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Vibes Badges
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: vibes.map((v) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Text(v, style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 11.5, fontWeight: FontWeight.w500)),
                              )).toList(),
                            ),
                            const SizedBox(height: 20),

                            // Mock Customer Booking Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: null,
                                    icon: const Icon(Icons.table_restaurant_rounded, size: 18),
                                    label: const Text('Đặt Bàn Ngay (Demo)'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      disabledBackgroundColor: const Color(0xFF2563EB),
                                      disabledForegroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: null,
                                    icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
                                    label: const Text('Xem Menu Món'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF2563EB),
                                      disabledForegroundColor: const Color(0xFF2563EB),
                                      side: const BorderSide(color: Color(0xFF2563EB)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 18),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Đây là mô phỏng giao diện khách hàng nhìn thấy trên ứng dụng FConnect khi tìm kiếm hoặc ghé thăm trang của bạn.',
                                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQrCodeDialog(Map<String, dynamic>? biz) {
    final businessName = biz?['name']?.toString() ?? 'Nhà Hàng Đối Tác FConnect';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.qr_code_2_rounded, color: Color(0xFF2563EB), size: 22),
                      SizedBox(width: 8),
                      Text('Mã QR Bàn & Menu Số', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                businessName,
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Quét mã để xem thực đơn và gọi món trực tiếp',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Mock Stylized QR Graphic
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12)],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.qr_code_rounded, size: 175, color: const Color(0xFF0F172A)),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'FConnect Smart Dining QR',
                      style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.white),
                                SizedBox(width: 10),
                                Text('Đã lưu mã QR vào danh sách in ấn!'),
                              ],
                            ),
                            backgroundColor: const Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Tải ảnh QR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final passFormKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (stfCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFE2E8F0))),
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Đổi Mật Khẩu Chủ Quán', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          content: Form(
            key: passFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentPassController,
                  obscureText: true,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu hiện tại',
                    labelStyle: const TextStyle(color: Color(0xFF64748B)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập mật khẩu hiện tại' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newPassController,
                  obscureText: true,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu mới (từ 6 ký tự)',
                    labelStyle: const TextStyle(color: Color(0xFF64748B)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                  ),
                  validator: (v) => v == null || v.length < 6 ? 'Mật khẩu phải từ 6 ký tự' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmPassController,
                  obscureText: true,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Xác nhận mật khẩu mới',
                    labelStyle: const TextStyle(color: Color(0xFF64748B)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                  ),
                  validator: (v) => v != newPassController.text ? 'Mật khẩu xác nhận không khớp' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (passFormKey.currentState!.validate()) {
                        setDialogState(() => isSaving = true);
                        final authProvider = Provider.of<AuthProvider>(dialogCtx, listen: false);
                        final success = await authProvider.updateProfile({
                          'currentPassword': currentPassController.text,
                          'newPassword': newPassController.text,
                        });

                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Đổi mật khẩu thành công!' : (authProvider.errorMessage ?? 'Lỗi đổi mật khẩu')),
                            backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditOwnerAccountDialog(User? user) {
    final nameController = TextEditingController(text: user?.fullName ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (stfCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFE2E8F0))),
          title: const Row(
            children: [
              Icon(Icons.manage_accounts_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Cập Nhật Hồ Sơ Chủ Quán', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Họ và tên chủ sở hữu',
                    labelStyle: const TextStyle(color: Color(0xFF64748B)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập họ và tên' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Số điện thoại liên hệ',
                    labelStyle: const TextStyle(color: Color(0xFF64748B)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập số điện thoại' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => isSaving = true);
                        final authProvider = Provider.of<AuthProvider>(dialogCtx, listen: false);
                        final userProvider = Provider.of<UserProvider>(dialogCtx, listen: false);

                        final success = await authProvider.updateProfile({
                          'fullName': nameController.text.trim(),
                          'phone': phoneController.text.trim(),
                        });

                        if (success && authProvider.user != null) {
                          userProvider.setUser(authProvider.user);
                        }

                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        if (!mounted) return;

                        setState(() {});

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Cập nhật tài khoản thành công!' : (authProvider.errorMessage ?? 'Lỗi cập nhật')),
                            backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Cập nhật'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Đăng xuất tài khoản', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi cổng FConnect Partner?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: isDesktop ? _buildDesktopLayout(user) : _buildMobileLayout(user),
          bottomNavigationBar: isDesktop ? null : _buildMobileBottomNav(),
        );
      },
    );
  }

  // ==========================================
  // DESKTOP LAYOUT (SIDEBAR + CONTENT SHELL)
  // ==========================================
  Widget _buildDesktopLayout(User? user) {
    return Row(
      children: [
        // Sidebar Cố Định Bên Trái (White + Blue)
        Container(
          width: 260,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            children: [
              // Sidebar Header Brand
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FConnect',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'PARTNER PORTAL',
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFE2E8F0), height: 1),

              // Navigation Links List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  children: [
                    _buildSidebarItem(0, Icons.home_rounded, 'Dashboard', ''),
                    _buildSidebarItem(1, Icons.restaurant_menu_rounded, 'Thực đơn & Món', 'Member 3'),
                    _buildSidebarItem(2, Icons.event_seat_rounded, 'Bàn & Đặt chỗ', 'Member 4'),
                    _buildSidebarItem(3, Icons.receipt_long_rounded, 'Đơn hàng', 'Member 4'),
                    _buildSidebarItem(4, Icons.sms_outlined, 'Messages', '', badgeCount: _totalUnreadChatCount > 0 ? _totalUnreadChatCount : null),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text(
                        'PHÂN HỆ CỦA BẠN (MEMBER 1)',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    _buildSidebarItem(5, Icons.store_mall_directory_rounded, 'Hồ sơ Quán & Cài đặt', 'Member 1', highlight: true),
                  ],
                ),
              ),

              // Sidebar Footer Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                ),
                child: Column(
                  children: [
                    // Nút Đăng xuất
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () => _handleLogout(context),
                        icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFEF4444)),
                        label: const Text('Đăng xuất', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Content Area Bên Phải
        Expanded(
          child: Column(
            children: [
              // Top Bar Desktop (Clean White)
              Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Thanh Tìm Kiếm Header (Ẩn khi ở tab Messages vì tab này đã có ô tìm kiếm riêng)
                    if (_selectedTab != 4)
                      Container(
                        width: 460,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          textAlignVertical: TextAlignVertical.center,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'Search',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 18),
                            prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 36, minHeight: 38),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                      });
                                    },
                                  )
                                : null,
                            suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 38),
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (val) {
                            setState(() {});
                          },
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    Row(
                      children: [
                        // Chuông thông báo Realtime cho Chủ Quán (Tin nhắn, Đặt bàn, Đơn hàng)
                        _buildOwnerNotificationBell(),
                        const SizedBox(width: 12),

                        // Chip Vai Trò
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified_user_rounded, color: Color(0xFF2563EB), size: 14),
                              SizedBox(width: 6),
                              Text('Chủ Quán F&B', style: TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Avatar -> Hồ sơ cá nhân
                        Tooltip(
                          message: 'Xem hồ sơ cá nhân',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ProfileScreen()),
                              );
                            },
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFF2563EB),
                              child: Text(
                                (user?.fullName.isNotEmpty == true ? user!.fullName[0] : 'O').toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Body Content
              Expanded(
                child: _selectedTab == 4
                    ? _buildTab4ChatSkeleton()
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(28),
                        child: _buildCurrentTabContent(user),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String title, String memberTag, {bool highlight = false, int? badgeCount}) {
    final isSelected = _selectedTab == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTabSelected(index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  size: 21,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF334155),
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badgeCount != null && badgeCount > 0) ...[
                        const SizedBox(width: 6),
                        Transform.translate(
                          offset: const Offset(0, -5),
                          child: Container(
                            width: 19,
                            height: 19,
                            decoration: const BoxDecoration(
                              color: Color(0xFFD97706),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$badgeCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (memberTag.isNotEmpty && badgeCount == null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withValues(alpha: 0.22) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      memberTag,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // MOBILE LAYOUT (APPBAR + CONTENT + BOTTOM NAV)
  // ==========================================
  Widget _buildMobileLayout(User? user) {
    return Column(
      children: [
        AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          shadowColor: Colors.black12,
          foregroundColor: const Color(0xFF0F172A),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getTabTitle(_selectedTab),
                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            _buildOwnerNotificationBell(),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
              tooltip: 'Làm mới dữ liệu',
              onPressed: _loadDashboardData,
            ),
            IconButton(
              icon: const Icon(Icons.person_outline_rounded, color: Color(0xFF64748B)),
              tooltip: 'Hồ sơ',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
              tooltip: 'Đăng xuất',
              onPressed: () => _handleLogout(context),
            ),
          ],
        ),
        Expanded(
          child: _selectedTab == 4
              ? _buildTab4ChatSkeleton()
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: _buildCurrentTabContent(user),
                ),
        ),
      ],
    );
  }

  Widget _buildMobileBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedTab > 4 ? 4 : _selectedTab,
        onTap: (index) {
          if (index == 4) {
            _onTabSelected(5); // Tab Hồ sơ quán
          } else {
            _onTabSelected(index);
          }
        },
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: const Color(0xFF94A3B8),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded, size: 20),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu_rounded, size: 20),
            label: 'Thực đơn',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_seat_rounded, size: 20),
            label: 'Đặt bàn',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_rounded, size: 20),
            label: 'Đơn hàng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_rounded, size: 20),
            label: 'Hồ sơ Quán',
          ),
        ],
      ),
    );
  }

  String _getTabTitle(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Quản Lý Thực Đơn';
      case 2:
        return 'Quản Lý Bàn & Đặt Chỗ';
      case 3:
        return 'Quản Lý Đơn Hàng';
      case 4:
        return 'Messages';
      case 5:
        return 'Hồ Sơ Quán & Cài Đặt';
      default:
        return 'FConnect Partner';
    }
  }

  // ==========================================
  // DISPATCHER HIỂN THỊ NỘI DUNG TỪNG TAB
  // ==========================================
  Widget _buildCurrentTabContent(User? user) {
    switch (_selectedTab) {
      case 0:
        return _buildTab0DashboardSkeleton();
      case 1:
        return _buildTab1MenuSkeleton();
      case 2:
        return _buildTab2BookingSkeleton();
      case 3:
        return _buildTab3OrderSkeleton();
      case 4:
        return _buildTab4ChatSkeleton();
      case 5:
      default:
        return _buildTab5BusinessProfile(user);
    }
  }

  // =========================================================================
  // TAB 5: HỒ SƠ QUÁN & CÀI ĐẶT (TRÁCH NHIỆM CHÍNH CỦA THÀNH VIÊN 1 - HOÀN THIỆN)
  // =========================================================================
  Widget _buildTab5BusinessProfile(User? user) {
    final biz = user?.business;
    final hasBusiness = biz != null && (biz['name']?.toString() ?? '').trim().isNotEmpty;

    final businessName = hasBusiness
        ? (biz['name']?.toString() ?? 'Chưa đặt tên quán')
        : 'Chưa hoàn thiện hồ sơ cơ sở F&B';

    final description = biz?['description']?.toString() ??
        'Hệ thống quán ẩm thực chất lượng cao, phục vụ các món ăn và đồ uống tinh hoa tại Đà Nẵng.';

    final categoryName = biz?['category']?.toString() ?? 'Nhà hàng ẩm thực';
    final district = biz?['address']?['district']?.toString() ??
        biz?['district']?.toString() ??
        'Hải Châu';
    final city = biz?['address']?['city']?.toString() ??
        biz?['city']?.toString() ??
        'Đà Nẵng';
    final street = biz?['address']?['street']?.toString() ?? 'Chi nhánh chính';
    final addressFull = street.isNotEmpty ? '$street, $district, $city' : '$district, $city';
    final phone = biz?['phone']?.toString() ?? user?.phone ?? '0901234567';
    final googleMapsUrl = biz?['googleMapsUrl']?.toString() ?? '';

    final minPrice = biz?['priceRange']?['min'] ?? 20000;
    final maxPrice = biz?['priceRange']?['max'] ?? 100000;
    final priceText = '${(minPrice / 1000).toInt()}k – ${(maxPrice / 1000).toInt()}k VNĐ';

    final vibesList = biz?['vibes'];
    final vibes = (vibesList is List && vibesList.isNotEmpty)
        ? List<String>.from(vibesList)
        : <String>['Yên tĩnh / Làm việc', 'Ấm cúng / Gia đình', 'Không gian thoáng đãng'];

    final purposesList = biz?['purposes'];
    final purposes = (purposesList is List && purposesList.isNotEmpty)
        ? List<String>.from(purposesList)
        : <String>['Gặp gỡ bạn bè', 'Bữa ăn gia đình', 'Hẹn hò cặp đôi'];

    final logoVal = biz?['logoUrl']?.toString() ?? '';
    final logoUrl = logoVal.startsWith('http')
        ? logoVal
        : 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=300&q=80';

    final coverVal = biz?['coverImageUrl']?.toString() ?? '';
    final coverImageUrl = coverVal.startsWith('http')
        ? coverVal
        : 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Hero Restaurant Header Card (Cover, Logo, Title, Quick Actions)
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 18,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover Image Banner with Status Chips
              Stack(
                children: [
                  Container(
                    height: 190,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(coverImageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.08),
                            Colors.white.withValues(alpha: 0.95),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 18,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fiber_manual_record_rounded, color: Colors.white, size: 10),
                              SizedBox(width: 6),
                              Text('Đang mở cửa', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded, color: Color(0xFF2563EB), size: 15),
                              SizedBox(width: 4),
                              Text('Đặt bàn nhanh', style: TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Bottom Identity Info Row
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Avatar Logo Overlapping
                    Transform.translate(
                      offset: const Offset(0, -32),
                      child: Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFF2563EB), width: 2.5),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                        ),
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: const Color(0xFFEFF6FF),
                          backgroundImage: NetworkImage(logoUrl),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),

                    // Restaurant Title & Rating
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  businessName,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.verified_rounded, color: Color(0xFF2563EB), size: 20),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                categoryName,
                                style: const TextStyle(color: Color(0xFF2563EB), fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_outlined, color: Color(0xFF64748B), size: 15),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$district, $city',
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Quick Action Buttons (White & Blue)
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _openOnboardingForm,
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text('Sửa thông tin'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showStorefrontPreview(biz, user),
                          icon: const Icon(Icons.remove_red_eye_rounded, size: 17, color: Color(0xFF2563EB)),
                          label: const Text('Xem trước', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showQrCodeDialog(biz),
                          icon: const Icon(Icons.qr_code_rounded, size: 17, color: Color(0xFF2563EB)),
                          label: const Text('QR Menu bàn', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        const SizedBox(height: 18),

        // 3. Responsive 2-Column Body (Left: Unified Restaurant Info & Space, Right: Owner Account)
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktopTwoCol = constraints.maxWidth >= 900;

            final leftColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Single Unified Component: THÔNG TIN & KHÔNG GIAN QUÁN (Địa chỉ, Liên hệ, Không gian & Tiện ích)
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 12,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.storefront_rounded, color: Color(0xFF2563EB), size: 22),
                              SizedBox(width: 8),
                              Text(
                                'THÔNG TIN & KHÔNG GIAN QUÁN',
                                style: TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: _openOnboardingForm,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF2563EB)),
                                SizedBox(width: 4),
                                Text(
                                  'Chỉnh sửa',
                                  style: TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Section 1: ĐỊA CHỈ & LIÊN HỆ
                      const Row(
                        children: [
                          Icon(Icons.place_rounded, color: Color(0xFF2563EB), size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Địa chỉ & Liên hệ',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildProfileDetailRow(Icons.location_on_outlined, 'Địa chỉ quán:', addressFull),
                      _buildProfileDetailRow(Icons.phone_in_talk_rounded, 'Hotline đặt bàn:', phone),
                      _buildProfileDetailRow(Icons.payments_outlined, 'Khoảng giá:', priceText),
                      if (googleMapsUrl.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(Icons.map_outlined, size: 18, color: Color(0xFF64748B)),
                              const SizedBox(width: 10),
                              const SizedBox(
                                width: 140,
                                child: Text(
                                  'Bản đồ vị trí:',
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _launchGoogleMaps(googleMapsUrl),
                                    icon: const Icon(Icons.open_in_new_rounded, size: 13),
                                    label: const Text('Mở Google Maps'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),
                      const Divider(color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 14),

                      // Section 2: KHÔNG GIAN, VIBE & TIỆN ÍCH
                      const Row(
                        children: [
                          Icon(Icons.palette_rounded, color: Color(0xFF2563EB), size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Không gian, Vibe & Tiện ích',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Description Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: const Border(left: BorderSide(color: Color(0xFF2563EB), width: 3.5)),
                        ),
                        child: Text(
                          description,
                          style: const TextStyle(color: Color(0xFF334155), fontSize: 13.5, height: 1.45),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Vibes Pills
                      const Text('Không gian & Vibe quán:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: vibes.map((v) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.spa_rounded, color: Color(0xFF1D4ED8), size: 14),
                              const SizedBox(width: 6),
                              Text(v, style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Purposes Pills
                      const Text('Phù hợp cho mục đích:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: purposes.map((p) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.groups_rounded, color: Color(0xFF15803D), size: 15),
                              const SizedBox(width: 6),
                              Text(p, style: const TextStyle(color: Color(0xFF15803D), fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Amenities Grid
                      const Text('Tiện ích phục vụ tại quán:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        runSpacing: 10,
                        children: [
                          _buildAmenityBadge(Icons.wifi_rounded, 'Wifi tốc độ cao'),
                          _buildAmenityBadge(Icons.ac_unit_rounded, 'Máy lạnh / Điều hòa'),
                          _buildAmenityBadge(Icons.local_parking_rounded, 'Bãi đỗ xe rộng rãi'),
                          _buildAmenityBadge(Icons.credit_card_rounded, 'Thanh toán thẻ / QR'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );

            final rightColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Card C: Tài khoản Chủ sở hữu & Bảo mật
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 12,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.manage_accounts_rounded, color: Color(0xFF2563EB), size: 22),
                              SizedBox(width: 8),
                              Text(
                                'TÀI KHOẢN CHỦ SỞ HỮU',
                                style: TextStyle(color: Color(0xFF2563EB), fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: const Text('MERCHANT', style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // User Identity Tile
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: const Color(0xFF2563EB),
                            child: Text(
                              (user?.fullName.isNotEmpty == true ? user!.fullName[0] : 'O').toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.fullName ?? 'Chủ Quán Đối Tác',
                                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user?.email ?? 'chưa cập nhật email',
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 12),
                      _buildProfileDetailRow(Icons.badge_rounded, 'Họ và tên:', user?.fullName ?? 'Chưa cập nhật'),
                      _buildProfileDetailRow(Icons.email_rounded, 'Email đăng nhập:', user?.email ?? 'Chưa cập nhật'),
                      _buildProfileDetailRow(Icons.phone_rounded, 'Số điện thoại:', user?.phone?.isNotEmpty == true ? user!.phone! : 'Chưa thiết lập'),
                      const SizedBox(height: 14),

                      // Account Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showChangePasswordDialog,
                              icon: const Icon(Icons.lock_reset_rounded, size: 16, color: Color(0xFF2563EB)),
                              label: const Text('Đổi mật khẩu', style: TextStyle(color: Color(0xFF2563EB), fontSize: 12.5, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showEditOwnerAccountDialog(user),
                              icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF334155)),
                              label: const Text('Sửa tài khoản', style: TextStyle(color: Color(0xFF334155), fontSize: 12.5, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );

            if (isDesktopTwoCol) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: leftColumn),
                  const SizedBox(width: 20),
                  Expanded(flex: 5, child: rightColumn),
                ],
              );
            } else {
              return Column(
                children: [
                  leftColumn,
                  const SizedBox(height: 18),
                  rightColumn,
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildAmenityBadge(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF2563EB), size: 16),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Color(0xFF334155), fontSize: 12.5, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 0: DASHBOARD / TỔNG QUAN (THÀNH VIÊN 5 - DASHBOARD & METRICS)
  // THEO THIẾT KẾ MẪU HÌNH 4: TOP MÓN BÁN CHẠY, BIỂU ĐỒ DOANH THU & ĐƠN CẦN LÀM
  // =========================================================================
  Widget _buildTab0DashboardSkeleton() {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. TOP 4 MỤC CHỈ SỐ HOẠT ĐỘNG THỰC TẾ (REAL METRIC CARDS)
        _buildTopMetricsRow(),
        const SizedBox(height: 24),

        // 2. KHU VỰC GIỮA: BIỂU ĐỒ DOANH THU TỪNG THÁNG & BẢNG % TĂNG TRƯỞNG
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            if (isDesktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: _buildMonthlyRevenueReportChart()),
                  const SizedBox(width: 20),
                  Expanded(flex: 5, child: _buildRevenueGrowthDetailsCard()),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildMonthlyRevenueReportChart(),
                  const SizedBox(height: 20),
                  _buildRevenueGrowthDetailsCard(),
                ],
              );
            }
          },
        ),
        const SizedBox(height: 24),

        // 3. KHU VỰC DƯỚI CÙNG: DANH SÁCH ĐẶT BÀN GẦN ĐÂY (RECENT BOOKINGS)
        _buildRecentBookingsSection(bookingProvider),
      ],
    );
  }

  /// 1. Top 4 mục chỉ số hoạt động thực tế (Doanh thu hôm nay, Đặt bàn chờ, Bàn trống, Đặt bàn hôm nay)
  Widget _buildTopMetricsRow() {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final tableProvider = Provider.of<TableProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);

    // Tính tổng doanh thu hôm nay từ các đơn đã thanh toán/hoàn thành
    final todayRevenue = orderProvider.ownerOrders
        .where((o) => o.status.toUpperCase() == 'COMPLETED' || o.status.toUpperCase() == 'SERVED')
        .fold<int>(0, (sum, o) => sum + o.total);
    final revenueStr = todayRevenue > 0
        ? '${todayRevenue.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")} đ'
        : '3,560,000 đ';

    final pendingBookings = bookingProvider.pendingCount > 0
        ? bookingProvider.pendingCount
        : (bookingProvider.ownerBookings.isEmpty ? 2 : 0);

    final todayBookings = (bookingProvider.confirmedCount + bookingProvider.pendingCount) > 0
        ? (bookingProvider.confirmedCount + bookingProvider.pendingCount)
        : (bookingProvider.ownerBookings.isEmpty ? 5 : 0);

    final freeTables = tableProvider.totalTables > 0
        ? '${tableProvider.availableCount} / ${tableProvider.totalTables}'
        : '8 / 12';

    final cards = [
      {
        'title': 'Doanh thu hôm nay',
        'value': revenueStr,
        'icon': Icons.account_balance_wallet_rounded,
        'colors': [const Color(0xFF059669), const Color(0xFF10B981)],
        'shadow': const Color(0xFF10B981),
        'tag': 'Hôm nay',
        'tagColor': const Color(0xFF059669),
        'tagBg': const Color(0xFFECFDF5),
      },
      {
        'title': 'Đặt bàn chờ duyệt',
        'value': '$pendingBookings',
        'icon': Icons.calendar_month_rounded,
        'colors': [const Color(0xFF1D4ED8), const Color(0xFF3B82F6)],
        'shadow': const Color(0xFF2563EB),
        'tag': 'Cần duyệt',
        'tagColor': const Color(0xFF2563EB),
        'tagBg': const Color(0xFFEFF6FF),
      },
      {
        'title': 'Bàn đang trống',
        'value': freeTables,
        'icon': Icons.table_bar_rounded,
        'colors': [const Color(0xFF0284C7), const Color(0xFF38BDF8)],
        'shadow': const Color(0xFF0284C7),
        'tag': 'Trống',
        'tagColor': const Color(0xFF0284C7),
        'tagBg': const Color(0xFFF0F9FF),
      },
      {
        'title': 'Đặt bàn hôm nay',
        'value': '$todayBookings',
        'icon': Icons.event_seat_rounded,
        'colors': [const Color(0xFFD97706), const Color(0xFFF59E0B)],
        'shadow': const Color(0xFFD97706),
        'tag': 'Lịch hẹn',
        'tagColor': const Color(0xFFD97706),
        'tagBg': const Color(0xFFFFFBEB),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 850;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 4 : 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: isWide ? 2.5 : 2.0,
          ),
          itemBuilder: (context, index) {
            final c = cards[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Icon Gradient bóng bẩy nổi bật
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: c['colors'] as List<Color>,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: (c['shadow'] as Color).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(c['icon'] as IconData, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                c['title'] as String,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: c['tagBg'] as Color,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                c['tag'] as String,
                                style: TextStyle(
                                  color: c['tagColor'] as Color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c['value'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 2. Biểu đồ doanh thu so sánh với mục tiêu theo tháng (Grouped Bar Chart chuẩn như thiết kế)
  Widget _buildMonthlyRevenueReportChart() {
    final orderProvider = Provider.of<OrderProvider>(context);

    // Mốc chỉ tiêu doanh thu hàng tháng theo biểu đồ
    final targetValues = [
      4200000, // T1
      4200000, // T2
      4500000, // T3
      4500000, // T4
      4500000, // T5
      4500000, // T6
      4500000, // T7
      4500000, // T8
      4500000, // T9
      4500000, // T10
      4500000, // T11
      4500000, // T12
    ];

    // Dữ liệu doanh thu mẫu trực quan chuẩn theo ảnh thiết kế
    final defaultActualValues = [
      3950000, // T1
      5800000, // T2
      4150000, // T3
      3180000, // T4
      5080000, // T5
      3580000, // T6
      3920000, // T7
      6400000, // T8
      4200000, // T9
      3560000, // T10
      4380000, // T11
      4260000, // T12
    ];

    // Gom doanh thu thực tế từ OrderProvider nếu trong database có đơn hoàn thành
    final actualValues = List<int>.generate(12, (index) {
      final month = index + 1;
      final monthOrders = orderProvider.ownerOrders.where((o) {
        if (o.status.toUpperCase() != 'COMPLETED' && o.status.toUpperCase() != 'SERVED') return false;
        return o.createdAt != null && o.createdAt!.month == month;
      });
      final realSum = monthOrders.fold<int>(0, (sum, o) => sum + o.total);
      return realSum > 0 ? realSum : defaultActualValues[index];
    });

    const maxY = 8000000.0;
    const chartHeight = 210.0;
    final yLabels = ['8000000', '6000000', '4000000', '2000000', '0'];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề kèm Icon Biểu Đồ & Chip chọn năm
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bar_chart_rounded, color: Color(0xFF2563EB), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Báo Cáo Doanh Thu Theo Tháng',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 13, color: Color(0xFF64748B)),
                    SizedBox(width: 5),
                    Text(
                      '2026',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Vùng vẽ biểu đồ gồm Trục Y, Grid lines ngang & Cặp cột kép
          SizedBox(
            height: chartHeight + 35,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trục mốc giá trị Y bên trái
                SizedBox(
                  width: 58,
                  height: chartHeight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: yLabels.map((lbl) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          lbl,
                          style: const TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Vùng biểu đồ chính (Gridlines + Cột kép + Nhãn tháng)
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height: chartHeight,
                        child: Stack(
                          children: [
                            // 5 đường kẻ ngang gridlines
                            Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(5, (i) {
                                return Container(
                                  width: double.infinity,
                                  height: 1,
                                  color: i == 4 ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                );
                              }),
                            ),

                            // 12 cặp cột (Doanh thu & Mục tiêu) ngồi sát đường baseline mốc 0
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: chartHeight,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: List.generate(12, (index) {
                                  final actual = actualValues[index];
                                  final target = targetValues[index];
                                  final actualH = ((actual / maxY) * chartHeight).clamp(0.0, chartHeight);
                                  final targetH = ((target / maxY) * chartHeight).clamp(0.0, chartHeight);

                                  return Tooltip(
                                    message: 'Tháng ${index + 1}:\n• Doanh thu: ${actual.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} đ\n• Mục tiêu: ${target.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} đ',
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        // Cột Doanh Thu (Xanh lá chuẩn hình ảnh: #70AD47)
                                        Container(
                                          width: 10,
                                          height: actualH,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF70AD47),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        // Cột Doanh Thu Mục Tiêu (Xanh dương chuẩn hình ảnh: #5B9BD5)
                                        Container(
                                          width: 10,
                                          height: targetH,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF5B9BD5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Nhãn trục X: THÁNG 1 -> THÁNG 12
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(12, (index) {
                          return Text(
                            'THÁNG ${index + 1}',
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Chú thích (Legend) nằm căn giữa ở đáy biểu đồ
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(width: 12, height: 12, color: const Color(0xFF70AD47)),
                  const SizedBox(width: 6),
                  const Text(
                    'DOANH THU',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                ],
              ),
              const SizedBox(width: 28),
              Row(
                children: [
                  Container(width: 12, height: 12, color: const Color(0xFF5B9BD5)),
                  const SizedBox(width: 6),
                  const Text(
                    'DOANH THU MỤC TIÊU',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 3. Bảng phần trăm tăng và giảm doanh thu giữa các tháng (Revenue Growth & Variance)
  Widget _buildRevenueGrowthDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề & Badge MoM (Đã xóa icon theo yêu cầu)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Biến Động Tăng Trưởng Doanh Thu',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.insights_rounded, size: 13, color: Color(0xFF16A34A)),
                    SizedBox(width: 4),
                    Text(
                      'MoM',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2 Hàng thông số chính (Đã in đậm MoM)
          _buildGrowthMetricRow('Tháng này vs Tháng trước ', '+18.5%', boldSuffix: '(MoM)', isPositive: true, isHighlighted: true),
          const SizedBox(height: 10),
          _buildGrowthMetricRow('Tháng đạt đỉnh doanh thu ', '+32.6%', boldSuffix: '(Tháng 8)', isPositive: true),

          const SizedBox(height: 18),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Danh sách biến động 4 tháng gần nhất: In đậm chữ (Hiện tại), (Tháng trước)
          const Text(
            'Chi tiết biến động 4 tháng gần nhất:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 10),
          _buildMiniMonthGrowthCard('Tháng 10 ', '3,560,000 đ', '+14.2% so với T9', boldSuffix: '(Hiện tại)', isUp: true),
          _buildMiniMonthGrowthCard('Tháng 9 ', '4,200,000 đ', '+8.6% so với T8', boldSuffix: '(Tháng trước)', isUp: true),
          _buildMiniMonthGrowthCard('Tháng 8', '6,400,000 đ', '-3.1% so với T7', isUp: false),
          _buildMiniMonthGrowthCard('Tháng 7', '3,920,000 đ', '+15.0% so với T6', isUp: true),
        ],
      ),
    );
  }

  Widget _buildHighlightedLabel(String title, [String? boldSuffix]) {
    if (boldSuffix == null || boldSuffix.isEmpty) {
      return Text(
        title,
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), fontWeight: FontWeight.w500),
      );
    }
    return Text.rich(
      TextSpan(
        text: title,
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), fontWeight: FontWeight.w500),
        children: [
          TextSpan(
            text: boldSuffix,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthMetricRow(String title, String value, {String? boldSuffix, bool isPositive = true, bool isHighlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: _buildHighlightedLabel(title, boldSuffix),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: isHighlighted ? const Color(0xFFD97706) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: isHighlighted ? null : Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: isHighlighted ? Colors.white : (isPositive ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Item 4 tháng gần nhất: Thiết kế đồng bộ hoàn toàn với các ô bên trên (Không có icon, badge nền trắng viền xám)
  Widget _buildMiniMonthGrowthCard(String month, String revenue, String diffText, {String? boldSuffix, required bool isUp}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Tên tháng kèm chữ in đậm (Hiện tại), (Tháng trước)
          _buildHighlightedLabel(month, boldSuffix),
          const Spacer(),
          // Số tiền doanh thu
          Text(
            revenue,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(width: 10),
          // Badge % tăng / giảm: Đồng bộ 100% với các ô bên trên (Nền trắng, viền xám sáng #CBD5E1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Text(
              diffText,
              style: TextStyle(
                color: isUp ? const Color(0xFF059669) : const Color(0xFFDC2626),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Khu vực Recent Bookings: Đọc danh sách đặt bàn THỰC TẾ gần đây
  Widget _buildRecentBookingsSection(BookingProvider bookingProvider) {
    final recentBookings = bookingProvider.ownerBookings;

    // Danh sách đặt bàn hiển thị: ưu tiên dữ liệu thật từ Server, nếu DB chưa có thì cung cấp dữ liệu mẫu chân thực
    final displayBookings = recentBookings.isNotEmpty
        ? recentBookings
        : [
            BookingModel(
              id: 'demo-bk-1',
              userId: 'u1',
              userName: 'Nguyễn Văn An',
              userPhone: '0905 123 456',
              businessId: 'b1',
              businessName: 'Nhà Hàng FConnect',
              branchId: 'br1',
              tableId: 't1',
              tableName: 'Bàn VIP 02 (Tầng 2)',
              bookingCode: 'BK8821',
              bookingDate: 'Hôm nay',
              startTime: '19:00',
              guestCount: 4,
              status: 'CONFIRMED',
            ),
            BookingModel(
              id: 'demo-bk-2',
              userId: 'u2',
              userName: 'Trần Thị Mai',
              userPhone: '0912 888 999',
              businessId: 'b1',
              businessName: 'Nhà Hàng FConnect',
              branchId: 'br1',
              tableId: 't2',
              tableName: 'Bàn Ngoài Trời 04',
              bookingCode: 'BK8822',
              bookingDate: 'Hôm nay',
              startTime: '19:30',
              guestCount: 2,
              status: 'PENDING',
            ),
            BookingModel(
              id: 'demo-bk-3',
              userId: 'u3',
              userName: 'Lê Hoàng Long',
              userPhone: '0988 777 666',
              businessId: 'b1',
              businessName: 'Nhà Hàng FConnect',
              branchId: 'br1',
              tableId: 't3',
              tableName: 'Bàn Gia Đình 01',
              bookingCode: 'BK8823',
              bookingDate: 'Hôm nay',
              startTime: '20:00',
              guestCount: 6,
              status: 'CONFIRMED',
            ),
            BookingModel(
              id: 'demo-bk-4',
              userId: 'u4',
              userName: 'Phạm Hương Giang',
              userPhone: '0971 234 567',
              businessId: 'b1',
              businessName: 'Nhà Hàng FConnect',
              branchId: 'br1',
              tableId: null,
              tableName: null,
              bookingCode: 'BK8824',
              bookingDate: 'Hôm nay',
              startTime: '20:30',
              guestCount: 3,
              status: 'PENDING',
            ),
            BookingModel(
              id: 'demo-bk-5',
              userId: 'u5',
              userName: 'Đỗ Tuấn Kiệt',
              userPhone: '0935 678 910',
              businessId: 'b1',
              businessName: 'Nhà Hàng FConnect',
              branchId: 'br1',
              tableId: 't4',
              tableName: 'Bàn Trung Tâm 08',
              bookingCode: 'BK8825',
              bookingDate: 'Hôm nay',
              startTime: '18:00',
              guestCount: 8,
              status: 'CHECKED_IN',
            ),
          ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề & Nút chuyển trang Bookings
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.event_seat_rounded, color: Color(0xFF2563EB), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Danh Sách Đặt Bàn Gần Đây (Recent Bookings)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  setState(() => _selectedTab = 2); // Chuyển sang Tab 2: Quản lý Bàn & Đặt chỗ
                },
                child: const Row(
                  children: [
                    Text(
                      'Xem tất cả đặt bàn',
                      style: TextStyle(color: Color(0xFF2563EB), fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Header Bảng
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Expanded(flex: 5, child: Text('Mã & Khách đặt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                Expanded(flex: 2, child: Text('Số khách', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                Expanded(flex: 4, child: Text('Thời gian đến', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                Expanded(flex: 3, child: Text('Bàn chỉ định', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                Expanded(flex: 3, child: Text('Trạng thái', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                SizedBox(width: 40, child: Text('Chi tiết', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)), textAlign: TextAlign.right)),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Danh sách lượt đặt bàn
          ...displayBookings.take(5).map((booking) {
              final isPending = booking.isPending;
              final isConfirmed = booking.isConfirmed;
              final isCheckedIn = booking.isCheckedIn;

              Color statusBg;
              Color statusColor;
              Color statusBorder;

              if (isPending) {
                statusBg = const Color(0xFFFEF3C7);
                statusColor = const Color(0xFFD97706);
                statusBorder = const Color(0xFFFDE68A);
              } else if (isConfirmed) {
                statusBg = const Color(0xFFECFDF5);
                statusColor = const Color(0xFF059669);
                statusBorder = const Color(0xFFA7F3D0);
              } else if (isCheckedIn) {
                statusBg = const Color(0xFFEFF6FF);
                statusColor = const Color(0xFF2563EB);
                statusBorder = const Color(0xFFBFDBFE);
              } else {
                statusBg = const Color(0xFFF1F5F9);
                statusColor = const Color(0xFF64748B);
                statusBorder = const Color(0xFFE2E8F0);
              }

              final customerName = booking.userName?.isNotEmpty == true ? booking.userName! : 'Khách đặt bàn';
              final customerPhone = booking.userPhone?.isNotEmpty == true ? ' • ${booking.userPhone}' : '';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    // Mã & Khách đặt
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${booking.bookingCode}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$customerName$customerPhone',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Số lượng khách
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${booking.guestCount} người',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                    ),
                    // Thời gian & Ngày
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.startTime,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            booking.bookingDate,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    // Bàn chỉ định
                    Expanded(
                      flex: 3,
                      child: Text(
                        booking.tableName?.isNotEmpty == true ? booking.tableName! : 'Chưa xếp bàn',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: booking.tableName?.isNotEmpty == true ? FontWeight.bold : FontWeight.normal,
                          color: booking.tableName?.isNotEmpty == true ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                          fontStyle: booking.tableName?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                    ),
                    // Trạng thái
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusBorder),
                          ),
                          child: Text(
                            booking.statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Nút chi tiết
                    SizedBox(
                      width: 40,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF64748B)),
                        tooltip: 'Xem đặt bàn',
                        onPressed: () {
                          setState(() => _selectedTab = 2); // Tab 2: Quản lý Bàn & Đặt chỗ
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: THỰC ĐƠN & MÓN ĂN (SƯỜN CHO THÀNH VIÊN 3 - MENU & PRODUCT)
  // =========================================================================
  Widget _buildTab1MenuSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSkeletonHeader(
          moduleTitle: 'Quản Lý Thực Đơn & Món Ăn',
          memberTag: 'Thành viên 3 (Menu & Cart)',
          description: 'Khung sườn quản lý danh mục món, giá bán và trạng thái còn/hết hàng.',
        ),
        const SizedBox(height: 18),

        // Toolbar Skeleton (Tìm kiếm + Bộ lọc + Thêm món)
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 18),
                    SizedBox(width: 8),
                    Text('Tìm kiếm món ăn trong thực đơn...', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thành viên 3 sẽ tích hợp MenuProvider để thêm món mới')),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Thêm Món'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Danh Sách Món Ăn Dạng Khung Sườn Mẫu
        _buildSampleListItem('Món ăn #1 (Ví dụ: Cơm gà xối mỡ giòn da)', 'Giá: 55,000đ • Danh mục: Đồ ăn chính • Còn hàng', Icons.fastfood_rounded),
        _buildSampleListItem('Món ăn #2 (Ví dụ: Trà sữa trân châu Ô Long)', 'Giá: 35,000đ • Danh mục: Đồ uống • Còn hàng', Icons.local_cafe_rounded),
        _buildSampleListItem('Món ăn #3 (Ví dụ: Lẩu hải sản chua cay)', 'Giá: 220,000đ • Danh mục: Lẩu & Nướng • Tạm hết hàng', Icons.ramen_dining_rounded),

        const SizedBox(height: 16),
        _buildPlaceholderCard(
          icon: Icons.restaurant_menu_rounded,
          title: 'Khung Sườn MenuProvider',
          subtitle: 'Phân hệ quản lý món ăn và danh mục theo PROJECT.md sẽ do Thành viên 3 triển khai kết nối API Backend.',
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 2: QUẢN LÝ BÀN & ĐẶT CHỖ (THÀNH VIÊN 4 - BOOKINGS & TABLES)
  // =========================================================================
  Widget _buildTab2BookingSkeleton() {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final tableProvider = Provider.of<TableProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSkeletonHeader(
          moduleTitle: 'Quản Lý Bàn & Đặt Chỗ',
          memberTag: 'Thành viên 4 (Booking & Table)',
          description: 'Quản lý lịch hẹn đặt bàn của thực khách, phân bổ chỗ ngồi và trạng thái bàn ăn.',
        ),
        const SizedBox(height: 18),

        // Quick Stats
        Row(
          children: [
            _buildStatItem(
              'Đặt bàn chờ duyệt',
              '${bookingProvider.pendingCount}',
              const Color(0xFFF59E0B),
              Icons.event_available_rounded,
            ),
            const SizedBox(width: 12),
            _buildStatItem(
              'Bàn đang trống',
              '${tableProvider.availableCount}/${tableProvider.totalTables}',
              const Color(0xFF10B981),
              Icons.table_restaurant_rounded,
            ),
          ],
        ),
        const SizedBox(height: 18),

        // 1. Quản lý Đặt bàn (Booking)
        _buildFeatureTile(
          title: 'Quản lý Đặt bàn (Booking)',
          subtitle: 'Xem danh sách khách đặt, xác nhận yêu cầu, xếp bàn & check-in',
          icon: Icons.calendar_month_rounded,
          accentColor: const Color(0xFF2563EB),
          badgeText: bookingProvider.pendingCount > 0 ? '${bookingProvider.pendingCount} chờ duyệt' : null,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OwnerBookingScreen()),
            );
          },
        ),
        const SizedBox(height: 12),

        // 2. Quản lý Bàn ăn (Table)
        _buildFeatureTile(
          title: 'Quản lý Bàn ăn (Table)',
          subtitle: 'Danh sách bàn, số chỗ ngồi, trạng thái hoạt động & thêm/sửa/xóa bàn',
          icon: Icons.table_restaurant_rounded,
          accentColor: const Color(0xFF10B981),
          badgeText: '${tableProvider.totalTables} bàn',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OwnerTableScreen()),
            );
          },
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 3: QUẢN LÝ ĐƠN HÀNG (THÀNH VIÊN 4 - ORDERS)
  // =========================================================================
  Widget _buildTab3OrderSkeleton() {
    final orderProvider = Provider.of<OrderProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSkeletonHeader(
          moduleTitle: 'Quản Lý Đơn Hàng Gọi Món',
          memberTag: 'Thành viên 4 (Booking & Order)',
          description: 'Theo dõi đơn gọi món tại bàn, xác nhận chế biến, sẵn sàng phục vụ và thanh toán.',
        ),
        const SizedBox(height: 18),

        // Quick Stats
        Row(
          children: [
            _buildStatItem(
              'Đơn hàng cần làm',
              '${orderProvider.pendingOrdersCount + orderProvider.preparingOrdersCount}',
              const Color(0xFF0072FF),
              Icons.receipt_long_rounded,
            ),
            const SizedBox(width: 12),
            _buildStatItem(
              'Tổng đơn hôm nay',
              '${orderProvider.todayOrdersCount}',
              const Color(0xFF8B5CF6),
              Icons.local_fire_department_rounded,
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Quản lý Đơn món (Order)
        _buildFeatureTile(
          title: 'Quản lý Đơn món (Order)',
          subtitle: 'Xác nhận đơn, chế biến, sẵn sàng, phục vụ & hoàn tất đơn gọi món',
          icon: Icons.soup_kitchen_rounded,
          accentColor: const Color(0xFFF97316),
          badgeText: orderProvider.pendingOrdersCount > 0
              ? '${orderProvider.pendingOrdersCount} chờ làm'
              : null,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OwnerOrderScreen()),
            );
          },
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 4: HỘP THƯ TIN NHẮN (GIAO DIỆN MESSENGER 2 CỘT CHUYÊN NGHIỆP - MEMBER 5)
  // =========================================================================
  Widget _buildTab4ChatSkeleton() {
    return _buildMessengerChatInterface();
  }

  /// Khung giao diện Messenger 2 Cột: Toàn màn hình khít nền bên ngoài
  Widget _buildMessengerChatInterface() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 850;

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.white,
          child: isDesktop
              ? Row(
                  children: [
                    // Cột Trái: Hộp thư Inbox (340px)
                    SizedBox(
                      width: 340,
                      child: _buildMessengerInboxSidebar(),
                    ),
                    // Đường phân cách dọc
                    Container(width: 1, color: const Color(0xFFE2E8F0)),
                    // Cột Phải: Khung Chat Trực Tiếp
                    Expanded(
                      child: _buildMessengerActiveChatWindow(isMobile: false),
                    ),
                  ],
                )
              : (_mobileViewingChat
                  ? _buildMessengerActiveChatWindow(isMobile: true)
                  : _buildMessengerInboxSidebar()),
        );
      },
    );
  }

  /// Avatar người dùng với fallback hiển thị chữ cái đầu (Initials) khi không có ảnh hoặc ảnh tải chậm
  Widget _buildUserAvatar({
    required String name,
    required String avatarUrl,
    required double radius,
    Color? backgroundColor,
  }) {
    final displayName = name.trim().isNotEmpty ? name.trim() : 'Khách';
    // Lấy chữ cái đầu (ví dụ: "D" cho Dong Tran) chuẩn xác y hệt hồ sơ trên App
    final firstLetter = displayName[0].toUpperCase();

    final validUrl = avatarUrl.trim().isNotEmpty &&
        avatarUrl != 'null' &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) &&
        !avatarUrl.contains('ui-avatars.com');

    final Widget fallbackWidget = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFB7185), Color(0xFFE11D48)], // Đỏ hồng chuẩn như hồ sơ cá nhân trên app
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        firstLetter,
        style: TextStyle(
          fontSize: radius * 0.95,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
    );

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: validUrl
            ? Image.network(
                avatarUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallbackWidget,
              )
            : fallbackWidget,
      ),
    );
  }

  /// Cột trái: Danh sách hội thoại khách hàng (Hộp thư Inbox)
  Widget _buildMessengerInboxSidebar() {
    final filteredConversations = _conversations.where((c) {
      if (_chatSearchKeyword.isEmpty) return true;
      final q = _chatSearchKeyword.toLowerCase();
      return c.customerName.toLowerCase().contains(q) ||
          c.customerPhone.contains(q) ||
          c.messages.any((m) => m.text.toLowerCase().contains(q));
    }).toList();

    return Column(
      children: [
        // Header Cột Inbox
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFFFAFAFA),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Hộp Thư Khách Hàng',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 8),
                      if (_totalUnreadChatCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$_totalUnreadChatCount mới',
                            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB), size: 19),
                        tooltip: 'Làm mới tin nhắn',
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                        onPressed: () => _fetchRealOwnerConversations(),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.mark_chat_unread_outlined, color: Color(0xFF2563EB), size: 20),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Ô tìm kiếm hội thoại căn giữa hoàn hảo
              Container(
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  textAlignVertical: TextAlignVertical.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                    hintText: 'Tìm khách hàng hoặc tin nhắn...',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                    prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 18),
                    prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 38),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    setState(() => _chatSearchKeyword = val.trim());
                  },
                ),
              ),
            ],
          ),
        ),

        // Danh sách các cuộc trò chuyện
        Expanded(
          child: filteredConversations.isEmpty
              ? const Center(
                  child: Text(
                    'Không tìm thấy hội thoại',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                )
              : ListView.separated(
                  itemCount: filteredConversations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final conv = filteredConversations[index];
                    final realIndex = _conversations.indexOf(conv);
                    final isSelected = realIndex == _selectedChatIndex;
                    final lastMsg = conv.messages.isNotEmpty ? conv.messages.last : null;

                    return Material(
                      color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedChatIndex = realIndex;
                            conv.unreadCount = 0;
                            _mobileViewingChat = true;
                          });
                          if (conv.realConversationId != null) {
                            _fetchRealMessages(conv);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: isSelected
                                ? const Border(left: BorderSide(color: Color(0xFF2563EB), width: 3.5))
                                : null,
                          ),
                          child: Row(
                            children: [
                              // Avatar có chấm xanh Online
                              Stack(
                                children: [
                                  _buildUserAvatar(
                                    name: conv.customerName,
                                    avatarUrl: conv.avatarUrl,
                                    radius: 22,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 11,
                                      height: 11,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              // Thông tin khách & tin nhắn cuối
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            conv.customerName,
                                            style: TextStyle(
                                              fontWeight: isSelected || conv.unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                                              fontSize: 13.5,
                                              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          conv.lastTime,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: conv.unreadCount > 0 ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                                            fontWeight: conv.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            lastMsg != null ? (lastMsg.isFromOwner ? 'Bạn: ${lastMsg.text}' : lastMsg.text) : '',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: conv.unreadCount > 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                              fontWeight: conv.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (conv.unreadCount > 0)
                                          Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF2563EB),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              '${conv.unreadCount}',
                                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    // Tag đặt bàn nhỏ gọn
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        conv.bookingInfo.split('•').first.trim(),
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
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
                ),
        ),
      ],
    );
  }

  /// Cột phải: Cửa sổ Chat Trực Tiếp (Header + Tin nhắn + Gợi ý trả lời + Ô nhập)
  Widget _buildMessengerActiveChatWindow({required bool isMobile}) {
    if (_selectedChatIndex < 0 || _selectedChatIndex >= _conversations.length) {
      return const Center(
        child: Text('Vui lòng chọn một cuộc trò chuyện', style: TextStyle(color: Color(0xFF94A3B8))),
      );
    }

    final conv = _conversations[_selectedChatIndex];

    return Column(
      children: [
        // 1. Header Cửa Sổ Chat
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              if (isMobile) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                  onPressed: () => setState(() => _mobileViewingChat = false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
              ],
              _buildUserAvatar(
                name: conv.customerName,
                avatarUrl: conv.avatarUrl,
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            conv.customerName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fiber_manual_record, size: 8, color: Color(0xFF059669)),
                              SizedBox(width: 4),
                              Text('Đang trực tuyến', style: TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.event_seat_rounded, size: 12, color: Color(0xFF2563EB)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            conv.bookingInfo,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Nút xem đặt bàn của khách
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _selectedTab = 2); // Chuyển sang Tab 2: Quản lý Bàn & Đặt chỗ
                },
                icon: const Icon(Icons.table_restaurant_rounded, size: 14, color: Color(0xFF2563EB)),
                label: const Text('Xem đặt bàn', style: TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              // Nút Ẩn / Hiện Bot tự động để cuộc trò chuyện không bị vướng
              OutlinedButton.icon(
                onPressed: () => setState(() => _hideBotMessages = !_hideBotMessages),
                icon: Icon(
                  _hideBotMessages ? Icons.smart_toy_outlined : Icons.smart_toy_rounded,
                  size: 14,
                  color: _hideBotMessages ? const Color(0xFF64748B) : const Color(0xFF2563EB),
                ),
                label: Text(
                  _hideBotMessages ? 'Đã ẩn bot' : 'Hiện bot',
                  style: TextStyle(
                    color: _hideBotMessages ? const Color(0xFF64748B) : const Color(0xFF2563EB),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _hideBotMessages ? const Color(0xFFE2E8F0) : const Color(0xFFBFDBFE)),
                  backgroundColor: _hideBotMessages ? const Color(0xFFF8FAFC) : const Color(0xFFEFF6FF),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        // 2. Vùng Tin Nhắn Cuộn
        Expanded(
          child: Container(
            color: const Color(0xFFF8FAFC),
            child: Builder(
              builder: (context) {
                final displayMessages = <_OwnerChatMessage>[];

                for (int i = 0; i < conv.messages.length; i++) {
                  final msg = conv.messages[i];
                  final isBot = msg.text.startsWith('Dạ ') && (msg.text.contains('quý khách') || msg.text.contains('quán'));

                  if (isBot) {
                    if (_hideBotMessages) continue;

                    final hasOwnerReplyAfter = conv.messages.sublist(i + 1).any((laterMsg) =>
                        laterMsg.isFromOwner &&
                        !(laterMsg.text.startsWith('Dạ ') && (laterMsg.text.contains('quý khách') || laterMsg.text.contains('quán'))));

                    if (hasOwnerReplyAfter) {
                      continue; // Chủ quán đã trả lời sau đoạn bot này -> tự động ẩn
                    }
                  }

                  displayMessages.add(msg);
                }

                return ListView.builder(
                  controller: _ownerChatScrollController,
                  padding: const EdgeInsets.all(18),
                  itemCount: displayMessages.length,
                  itemBuilder: (context, idx) {
                    final msg = displayMessages[idx];
                    final isOwner = msg.isFromOwner;
                    final hasImage = msg.imageUrl != null && msg.imageUrl!.isNotEmpty;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: isOwner ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isOwner) ...[
                        _buildUserAvatar(
                          name: conv.customerName,
                          avatarUrl: conv.avatarUrl,
                          radius: 14,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 420),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isOwner ? const Color(0xFF2563EB) : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isOwner ? 16 : 4),
                              bottomRight: Radius.circular(isOwner ? 4 : 16),
                            ),
                            border: isOwner ? null : Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: isOwner ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (hasImage) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    msg.imageUrl!,
                                    width: 250,
                                    height: 160,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) => Container(
                                      width: 250,
                                      height: 100,
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.broken_image_rounded, color: Colors.grey, size: 20),
                                            SizedBox(width: 6),
                                            Text('Không tải được ảnh', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (msg.text.isNotEmpty) const SizedBox(height: 8),
                              ],
                              if (msg.text.isNotEmpty)
                                Text(
                                  msg.text,
                                  style: TextStyle(
                                    color: isOwner ? Colors.white : const Color(0xFF0F172A),
                                    fontSize: 13.5,
                                    height: 1.4,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                msg.time,
                                style: TextStyle(
                                  color: isOwner ? Colors.white.withValues(alpha: 0.75) : const Color(0xFF94A3B8),
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    ),

        // 3. Khung Thư Viện Ảnh (Photo Tray)
        if (_showPhotoTray) _buildPhotoTray(),

        // 4. Khung Chọn Icon Mặt Cười (Emoji Picker)
        if (_showEmojiPicker) _buildEmojiPickerPanel(),

        // 5. Thanh Nhập Tin Nhắn Phong Cách Messenger (Nền trắng sạch, giữ nguyên màu xanh đậm cho các icon)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              // Nút Mở Thư Viện Ảnh (Lấy ảnh từ thư viện hoặc tải từ máy)
              IconButton(
                icon: const Icon(Icons.image_rounded, color: Color(0xFF1E3226), size: 24),
                tooltip: 'Thư viện ảnh',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() {
                    _showPhotoTray = !_showPhotoTray;
                    if (_showPhotoTray) _showEmojiPicker = false;
                  });
                },
              ),
              const SizedBox(width: 4),

              // Nút Nhãn Dán / Sticker
              IconButton(
                icon: const Icon(Icons.sticky_note_2_rounded, color: Color(0xFF1E3226), size: 24),
                tooltip: 'Nhãn dán',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() {
                    _showEmojiPicker = !_showEmojiPicker;
                    if (_showEmojiPicker) _showPhotoTray = false;
                  });
                },
              ),
              const SizedBox(width: 4),

              // Nút Ảnh Động GIF
              IconButton(
                icon: const Icon(Icons.gif_box_rounded, color: Color(0xFF1E3226), size: 26),
                tooltip: 'Ảnh động GIF',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: () {
                  _sendOwnerMessage(
                    imageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=600&q=80',
                    presetText: 'Nhà hàng FConnect hân hạnh đón tiếp quý khách! 🎉',
                  );
                },
              ),
              const SizedBox(width: 8),

              // Khung nhập "Aa" dạng viên thuốc nền xám nhạt sạch sẽ
              Expanded(
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.only(left: 16, right: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ownerChatMessageController,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                          decoration: const InputDecoration(
                            hintText: 'Aa',
                            hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _sendOwnerMessage(),
                        ),
                      ),
                      // Icon mặt cười bên trong khung nhập
                      IconButton(
                        icon: Icon(
                          _showEmojiPicker ? Icons.keyboard_rounded : Icons.sentiment_satisfied_alt_rounded,
                          color: const Color(0xFF1E3226),
                          size: 24,
                        ),
                        tooltip: 'Icon mặt cười',
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _showEmojiPicker = !_showEmojiPicker;
                            if (_showEmojiPicker) _showPhotoTray = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Nút Bên Phải: Nếu chưa gõ thì hiện nút Thích 👍 màu xanh đậm, nếu đã gõ thì hiện nút Gửi ✈️
              if (_ownerChatMessageController.text.trim().isEmpty)
                IconButton(
                  icon: const Icon(Icons.thumb_up_rounded, color: Color(0xFF1E3226), size: 24),
                  tooltip: 'Thích',
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                  onPressed: () => _sendOwnerMessage(presetText: '👍'),
                )
              else
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E3226),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    tooltip: 'Gửi tin nhắn',
                    padding: EdgeInsets.zero,
                    onPressed: () => _sendOwnerMessage(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Khung Thư Viện Ảnh Nhà Hàng & Chọn ảnh từ máy tính / thiết bị (Không cần dán link)
  Widget _buildPhotoTray() {
    final List<Map<String, String>> galleryPhotos = [
      {
        'title': 'Bàn VIP 02 (Nến & Hoa)',
        'category': 'Bàn tiệc',
        'url': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=600&q=80',
      },
      {
        'title': 'Ban công view hoàng hôn',
        'category': 'Không gian',
        'url': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=600&q=80',
      },
      {
        'title': 'Phòng tiệc Gia đình',
        'category': 'Không gian',
        'url': 'https://images.unsplash.com/photo-1530103862676-de8c9debad1d?auto=format&fit=crop&w=600&q=80',
      },
      {
        'title': 'Sảnh tiệc trung tâm',
        'category': 'Không gian',
        'url': 'https://images.unsplash.com/photo-1550966871-3ed3cdb5ed0c?auto=format&fit=crop&w=600&q=80',
      },
      {
        'title': 'Bò nướng sốt tiêu đen',
        'category': 'Món ăn',
        'url': 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80',
      },
      {
        'title': 'Cá hồi áp chảo bơ chanh',
        'category': 'Món ăn',
        'url': 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=600&q=80',
      },
      {
        'title': 'Salad bơ ức gà sốt mè',
        'category': 'Món ăn',
        'url': 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=600&q=80',
      },
      {
        'title': 'Set rượu vang & Cocktail',
        'category': 'Đồ uống',
        'url': 'https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?auto=format&fit=crop&w=600&q=80',
      },
      {
        'title': 'Bánh kem sinh nhật cao cấp',
        'category': 'Tráng miệng',
        'url': 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?auto=format&fit=crop&w=600&q=80',
      },
    ];

    return Container(
      height: 220,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề thư viện ảnh và nút tải từ máy
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.photo_library_rounded, color: Color(0xFF1E3226), size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Thư viện ảnh nhà hàng (Chạm ảnh để gửi)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3226)),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () async {
                    final dataUrl = await pickLocalImageFile();
                    if (dataUrl != null && dataUrl.isNotEmpty) {
                      _sendOwnerMessage(
                        imageUrl: dataUrl,
                        presetText: 'Hình ảnh gửi từ thiết bị',
                      );
                      setState(() => _showPhotoTray = false);
                    }
                  },
                  icon: const Icon(Icons.drive_folder_upload_rounded, size: 15),
                  label: const Text('Chọn ảnh từ máy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3226),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => setState(() => _showPhotoTray = false),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Danh sách cuộn ảnh từ thư viện
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              scrollDirection: Axis.horizontal,
              itemCount: galleryPhotos.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, idx) {
                if (idx == 0) {
                  // Thẻ đầu tiên: Bấm để chọn ảnh từ máy tính / điện thoại
                  return InkWell(
                    onTap: () async {
                      final dataUrl = await pickLocalImageFile();
                      if (dataUrl != null && dataUrl.isNotEmpty) {
                        _sendOwnerMessage(
                          imageUrl: dataUrl,
                          presetText: 'Hình ảnh gửi từ thiết bị',
                        );
                        setState(() => _showPhotoTray = false);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF1E3226), size: 30),
                          SizedBox(height: 6),
                          Text(
                            'Tải ảnh từ máy',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E3226)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final item = galleryPhotos[idx - 1];
                return InkWell(
                  onTap: () {
                    _sendOwnerMessage(
                      imageUrl: item['url'],
                      presetText: 'Quán gửi quý khách hình ảnh ${item['title']} ạ!',
                    );
                    setState(() => _showPhotoTray = false);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 130,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  item['url']!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image_rounded, size: 24, color: Colors.grey),
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Gửi ngay',
                                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                          child: Text(
                            item['title']!,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Bảng chọn Icon Mặt cười & Biểu tượng cảm xúc (Emoji Picker Panel)
  Widget _buildEmojiPickerPanel() {
    final emojiCategories = {
      'Mặt cười': ['😊', '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '😉', '😇', '🥰', '😍', '🤩', '😘', '😋', '😎', '🥳', '🤗', '👍', '👌', '🤝', '👏', '🙏', '❤️', '💖'],
      'Món ăn & Bàn tiệc': ['🍽️', '🥩', '🍕', '🍔', '🥗', '🍝', '🍜', '🍲', '🍣', '🍤', '🍷', '🥂', '🍻', '🍹', '☕', '🍰', '🎂', '🪑', '🕯️', '💐'],
      'Nhà hàng & Tiện ích': ['✨', '🔥', '🎉', '⭐', '📍', '🕒', '📞', '🚗', '🛵', '💯', '✅', '💬', '🎁', '🎈', '🏷️', '🔔'],
    };

    return Container(
      height: 180,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: DefaultTabController(
        length: emojiCategories.length,
        child: Column(
          children: [
            Container(
              height: 36,
              color: const Color(0xFFF8FAFC),
              child: TabBar(
                isScrollable: true,
                labelColor: const Color(0xFF1E3226),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                indicatorColor: const Color(0xFF1E3226),
                indicatorWeight: 2,
                tabs: emojiCategories.keys.map((cat) => Tab(text: cat)).toList(),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: emojiCategories.values.map((emojis) {
                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 44,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: emojis.length,
                    itemBuilder: (context, i) {
                      final emoji = emojis[i];
                      return InkWell(
                        onTap: () {
                          final current = _ownerChatMessageController.text;
                          final selection = _ownerChatMessageController.selection;
                          final newText = (selection.start >= 0)
                              ? current.replaceRange(selection.start, selection.end, emoji)
                              : current + emoji;
                          _ownerChatMessageController.value = TextEditingValue(
                            text: newText,
                            selection: TextSelection.collapsed(
                              offset: (selection.start >= 0 ? selection.start : current.length) + emoji.length,
                            ),
                          );
                          setState(() {});
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
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

  /// Xử lý gửi tin nhắn của Chủ quán tới khách hàng (Hỗ trợ cả văn bản, hình ảnh và icon)
  void _sendOwnerMessage({String? presetText, String? imageUrl}) async {
    final textToSend = (presetText ?? _ownerChatMessageController.text).trim();
    if (textToSend.isEmpty && (imageUrl == null || imageUrl.isEmpty)) return;
    if (_selectedChatIndex < 0 || _selectedChatIndex >= _conversations.length) return;

    final conv = _conversations[_selectedChatIndex];
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      conv.messages.add(
        _OwnerChatMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          text: textToSend,
          imageUrl: imageUrl,
          time: timeStr,
          isFromOwner: true,
        ),
      );
      _ownerChatMessageController.clear();
      _showEmojiPicker = false;
      _showPhotoTray = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_ownerChatScrollController.hasClients) {
        _ownerChatScrollController.animateTo(
          _ownerChatScrollController.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });

    // Gửi tin nhắn thực tế qua Backend API nếu cuộc hội thoại liên kết với dữ liệu thật
    if (conv.realConversationId != null || conv.customerId != null) {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token != null) {
        try {
          await http.post(
            Uri.parse('${ApiConstants.baseUrl}/chat/messages'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              if (conv.realConversationId != null) 'conversationId': conv.realConversationId,
              if (conv.customerId != null) 'receiverId': conv.customerId,
              'text': textToSend,
              if (imageUrl != null) 'imageUrl': imageUrl,
              'isBusinessReceiver': false,
            }),
          );
        } catch (e) {
          debugPrint('[OwnerChat] Send message error: $e');
        }
      }
    }
  }

  // =========================================================================
  // OWNER REALTIME NOTIFICATION CENTER (MEMBER 5)
  // =========================================================================
  Widget _buildOwnerNotificationBell() {
    return Consumer<NotificationProvider>(
      builder: (context, notifProv, _) {
        final unread = notifProv.unreadCount;

        return Tooltip(
          message: 'Thông báo cửa hàng ($unread mới)',
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showOwnerNotificationModal(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: unread > 0 ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: unread > 0 ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    unread > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                    color: unread > 0 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                    size: 21,
                  ),
                  if (unread > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showOwnerNotificationModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final notifProv = Provider.of<NotificationProvider>(dialogCtx);
            final notifs = notifProv.notifications;
            final unread = notifProv.unreadCount;

            return Dialog(
              backgroundColor: Colors.transparent,
              alignment: Alignment.topRight,
              insetPadding: const EdgeInsets.only(top: 60, right: 28, bottom: 40),
              child: Container(
                width: 440,
                constraints: const BoxConstraints(maxHeight: 580),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF2563EB), size: 18),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Thông Báo Cửa Hàng',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                              ),
                              if (unread > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$unread mới',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          TextButton(
                            onPressed: unread > 0 ? () => notifProv.markAllAsRead() : null,
                            child: const Text('Đọc tất cả', style: TextStyle(fontSize: 12.5)),
                          ),
                        ],
                      ),
                    ),

                    // Notification List
                    Flexible(
                      child: notifs.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(36),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF8FAFC),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF94A3B8), size: 36),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('Chưa có thông báo nào', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Khi có khách đặt bàn, gửi tin nhắn hoặc gọi món sẽ hiện tại đây.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: notifs.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (ctx, idx) {
                                final n = notifs[idx];
                                final isChat = n.type == 'NEW_MESSAGE' || n.category == NotificationCategory.chat;
                                final isBooking = n.type.contains('BOOKING') || n.category == NotificationCategory.booking;
                                final isOrder = n.type.contains('ORDER') || n.category == NotificationCategory.order;

                                Color iconBg = const Color(0xFFEFF6FF);
                                Color iconColor = const Color(0xFF2563EB);
                                IconData iconData = Icons.notifications_rounded;
                                String actionHint = 'Bấm để xem chi tiết';

                                if (isChat) {
                                  iconBg = const Color(0xFFEFF6FF);
                                  iconColor = const Color(0xFF2563EB);
                                  iconData = Icons.forum_rounded;
                                  actionHint = 'Bấm để mở tin nhắn khách hàng 💬';
                                } else if (isBooking) {
                                  iconBg = const Color(0xFFECFDF5);
                                  iconColor = const Color(0xFF059669);
                                  iconData = Icons.event_seat_rounded;
                                  actionHint = 'Bấm để chuyển sang Quản lý Bàn 🪑';
                                } else if (isOrder) {
                                  iconBg = const Color(0xFFFFFBEB);
                                  iconColor = const Color(0xFFD97706);
                                  iconData = Icons.receipt_long_rounded;
                                  actionHint = 'Bấm để chuyển sang Quản lý Đơn hàng 🍽️';
                                }

                                return Material(
                                  color: n.isRead ? Colors.white : const Color(0xFFF8FAFC),
                                  child: InkWell(
                                    onTap: () {
                                      if (!n.isRead) notifProv.markAsRead(n.id);
                                      Navigator.pop(modalCtx);
                                      if (isChat) {
                                        _onTabSelected(4);
                                      } else if (isBooking) {
                                        _onTabSelected(2);
                                      } else if (isOrder) {
                                        _onTabSelected(3);
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: iconBg,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(iconData, color: iconColor, size: 18),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        n.title,
                                                        style: TextStyle(
                                                          fontSize: 13.5,
                                                          fontWeight: n.isRead ? FontWeight.w600 : FontWeight.bold,
                                                          color: const Color(0xFF0F172A),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      n.formattedTime,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Color(0xFF94A3B8),
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    if (!n.isRead) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        width: 7,
                                                        height: 7,
                                                        decoration: const BoxDecoration(
                                                          color: Color(0xFF2563EB),
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  n.message,
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.3),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  actionHint,
                                                  style: TextStyle(fontSize: 11, color: iconColor, fontWeight: FontWeight.w600),
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
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // REUSABLE HELPER WIDGETS
  // =========================================================================
  Widget _buildSkeletonHeader({required String moduleTitle, required String memberTag, required String description}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Text(
                moduleTitle,
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w800),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  memberTag,
                  style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildKpiCardSkeleton(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildSampleListItem(String title, String subtitle, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8), size: 18),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCard({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: const Color(0xFF2563EB).withValues(alpha: 0.7)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5, height: 1.4),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2563EB)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(actionLabel, style: const TextStyle(color: Color(0xFF2563EB))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accentColor, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badgeText != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OwnerChatMessage {
  final String id;
  final String text;
  final String? imageUrl;
  final String time;
  final bool isFromOwner;

  _OwnerChatMessage({
    required this.id,
    required this.text,
    this.imageUrl,
    required this.time,
    required this.isFromOwner,
  });
}

class _OwnerChatConversation {
  final String id;
  final String? realConversationId;
  final String? customerId;
  final String customerName;
  final String customerPhone;
  final String avatarUrl;
  final String bookingInfo;
  String lastTime;
  int unreadCount;
  final List<_OwnerChatMessage> messages;

  _OwnerChatConversation({
    required this.id,
    this.realConversationId,
    this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.avatarUrl,
    required this.bookingInfo,
    required this.lastTime,
    this.unreadCount = 0,
    required this.messages,
  });
}

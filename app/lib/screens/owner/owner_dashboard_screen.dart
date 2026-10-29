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
import '../../models/order_model.dart';
import '../../models/review_model.dart';
import '../../services/review_service.dart';
import '../../models/notification_item_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/table_provider.dart';
import '../../providers/user_provider.dart';
import '../auth/login_screen.dart';
import '../auth/profile_screen.dart';
import 'product/owner_product_list_screen.dart';
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
  int? _selectedChartMonth;
  int get _activeChartMonth => (_selectedChartMonth ?? 9).clamp(0, 11);
  String _chatSearchKeyword = '';
  final TextEditingController _ownerChatMessageController = TextEditingController();
  final ScrollController _ownerChatScrollController = ScrollController();

  int get _totalUnreadChatCount => _conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);

  final List<_OwnerChatConversation> _conversations = [];

  Timer? _chatPollingTimer;
  Timer? _notifPollingTimer;
  Timer? _dashboardPollingTimer;
  final ReviewService _reviewService = ReviewService();
  List<ReviewModel> _businessReviews = [];
  bool _isLoadingReviews = false;
  int _selectedReviewRatingFilter = 0; // 0 = Tất cả, 5, 4, 3, 2, 1
  int _tab2BookingFilter = 0;
  int _tab3OrderFilter = 0;
  bool _isSyncingGoogleReviews = false;
  bool _showGoogleReviewsOnly = false;

  @override
  void dispose() {
    _chatPollingTimer?.cancel();
    _notifPollingTimer?.cancel();
    _dashboardPollingTimer?.cancel();
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
      // Realtime polling cho Dashboard (Đơn hàng, Đặt bàn, Đánh giá không cần F5)
      _dashboardPollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (mounted) {
          _silentRefreshDashboard();
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
    if (index == 5) {
      _fetchBusinessReviews(showLoading: true);
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
    _fetchBusinessReviews();
  }

  /// Cập nhật ngầm định kỳ toàn bộ dữ liệu Dashboard để realtime không cần F5
  void _silentRefreshDashboard() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final biz = user?.business;
    final businessId = (biz?['_id'] ?? biz?['id'])?.toString();

    Provider.of<BookingProvider>(context, listen: false).fetchOwnerBookings(silent: true);
    Provider.of<OrderProvider>(context, listen: false).fetchOwnerOrders(silent: true);

    if (businessId != null && businessId.isNotEmpty) {
      _reviewService.getBusinessReviews(businessId).then((revs) {
        if (mounted) {
          setState(() {
            _businessReviews = revs;
          });
        }
      }).catchError((_) {});
    }
  }

  Future<void> _fetchBusinessReviews({bool showLoading = false}) async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final biz = user?.business;
    final businessId = (biz?['_id'] ?? biz?['id'])?.toString();
    if (businessId == null || businessId.isEmpty) return;

    if (showLoading && mounted) {
      setState(() => _isLoadingReviews = true);
    }

    try {
      final reviews = await _reviewService.getBusinessReviews(businessId);
      if (mounted) {
        setState(() {
          _businessReviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReviews = false);
      }
    }
  }

  Future<void> _handleSyncGoogleReviews(String businessId, String? googleMapsUrl, {String? businessName}) async {
    if (businessId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tài khoản chưa có cơ sở quán ăn. Vui lòng hoàn tất tạo hồ sơ quán trước khi đồng bộ Google Maps.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      _openOnboardingForm();
      return;
    }
    if (googleMapsUrl == null || googleMapsUrl.trim().isEmpty) {
      _showGoogleMapsSyncPromptDialog(businessId, currentUrl: googleMapsUrl, businessName: businessName);
      return;
    }
    await _performSyncGoogleReviews(businessId, googleMapsUrl);
  }

  void _showGoogleMapsSyncPromptDialog(String businessId, {String? currentUrl, String? businessName}) {
    final urlCtrl = TextEditingController(text: currentUrl ?? '');
    final name = (businessName != null && businessName.trim().isNotEmpty) ? businessName.trim() : 'Highlands Coffee';
    final suggestedUrl = 'https://www.google.com/maps/search/?api=1&query=' + Uri.encodeComponent(name + ' Da Nang');

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.share_location_rounded, color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Đồng Bộ Đánh Giá Google Maps',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dán liên kết Google Maps của quán để hệ thống tự động đồng bộ điểm số và các đánh giá thực tế từ Google Places:',
                  style: TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: urlCtrl,
                  decoration: InputDecoration(
                    labelText: 'Liên kết Google Maps',
                    hintText: 'https://maps.app.goo.gl/... hoặc https://google.com/maps/place/...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                    prefixIcon: const Icon(Icons.link_rounded, color: Color(0xFF2563EB), size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    urlCtrl.text = suggestedUrl;
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: Color(0xFF16A34A), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Điền link tự động theo tên quán: "' + name + '"',
                            style: const TextStyle(color: Color(0xFF15803D), fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final input = urlCtrl.text.trim();
                if (input.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng dán liên kết Google Maps trước khi đồng bộ.')),
                  );
                  return;
                }
                final lower = input.toLowerCase();
                final isValid = lower.contains('google.com/maps') ||
                    lower.contains('maps.google.') ||
                    lower.contains('maps.app.goo.gl') ||
                    lower.contains('goo.gl/maps');
                if (!isValid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đường dẫn không hợp lệ! Vui lòng nhập đúng liên kết Google Maps (ví dụ: https://maps.app.goo.gl/... hoặc https://google.com/maps/...).'),
                      backgroundColor: Color(0xFFDC2626),
                    ),
                  );
                  return;
                }
                Navigator.pop(dlgCtx);
                _performSyncGoogleReviews(businessId, input);
              },
              icon: const Icon(Icons.sync_rounded, size: 16),
              label: const Text('Bắt đầu đồng bộ', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performSyncGoogleReviews(String businessId, String targetUrl) async {
    setState(() => _isSyncingGoogleReviews = true);

    try {
      final res = await _reviewService.syncGoogleReviews(businessId, googleMapsUrl: targetUrl);
      if (mounted) {
        setState(() => _isSyncingGoogleReviews = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Đồng bộ hoàn tất'),
            backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ),
        );
        if (res['success'] == true) {
          await Provider.of<AuthProvider>(context, listen: false).checkAuthStatus();
          _fetchBusinessReviews();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncingGoogleReviews = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kết nối đồng bộ: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
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

  // =========================================================================
  // CARD D: QUẢN LÝ ĐÁNH GIÁ & UY TÍN TỪ THỰC KHÁCH (100% Real Data & Google Maps Sync)
  // =========================================================================
  Widget _buildReviewsManagementSection(Map<String, dynamic>? biz, User? user) {
    final businessId = (biz?['_id'] ?? biz?['id'])?.toString() ?? '';
    final googleMapsUrl = biz?['googleMapsUrl']?.toString() ?? '';
    final googleRating = biz?['googleRating'];
    final rawGoogleReviews = biz?['googleReviews'];
    final List<Map<String, dynamic>> googleReviews = [];
    if (rawGoogleReviews is List) {
      for (final r in rawGoogleReviews) {
        if (r is Map) googleReviews.add(Map<String, dynamic>.from(r));
      }
    }

    final totalFConnectReviews = _businessReviews.length;
    final avgScore = totalFConnectReviews > 0
        ? (_businessReviews.fold<double>(0.0, (sum, r) => sum + r.rating) / totalFConnectReviews)
        : ((biz?['ratingSummary']?['average'] as num?)?.toDouble() ?? 5.0);

    final count5 = _businessReviews.where((r) => r.rating.round() == 5).length;
    final count4 = _businessReviews.where((r) => r.rating.round() == 4).length;
    final count3 = _businessReviews.where((r) => r.rating.round() == 3).length;
    final count2 = _businessReviews.where((r) => r.rating.round() == 2).length;
    final count1 = _businessReviews.where((r) => r.rating.round() == 1).length;
    final countVerified = _businessReviews.where((r) => r.isVerified).length;

    final gRating = (googleRating?['rating'] as num?)?.toDouble() ?? 0.0;
    final gTotal = (googleRating?['userRatingsTotal'] as num?)?.toInt() ?? 0;

    final filteredFConnectReviews = _selectedReviewRatingFilter == 0
        ? _businessReviews
        : (_selectedReviewRatingFilter == 99
            ? _businessReviews.where((r) => r.isVerified).toList()
            : _businessReviews.where((r) => r.rating.round() == _selectedReviewRatingFilter).toList());

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Bar: Tiêu đề + Nút Đồng bộ Google Maps
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'ĐÁNH GIÁ & UY TÍN TỪ THỰC KHÁCH',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text(
                            '$totalFConnectReviews Đánh giá',
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Phản hồi 100% thực tế từ khách hàng trải nghiệm ẩm thực & đồng bộ dữ liệu đánh giá từ Google Maps.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Nút đồng bộ Google Maps
              ElevatedButton.icon(
                onPressed: _isSyncingGoogleReviews
                    ? null
                    : () => _handleSyncGoogleReviews(businessId, googleMapsUrl, businessName: biz?['name']?.toString()),
                icon: _isSyncingGoogleReviews
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync_rounded, size: 16),
                label: Text(
                  _isSyncingGoogleReviews ? 'Đang đồng bộ...' : 'Đồng bộ Google Maps',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _fetchBusinessReviews(showLoading: true),
                tooltip: 'Tải lại danh sách đánh giá',
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          // 2. Metrics Overview Banner
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 760;
              final col1 = _buildFConnectRatingMetricCard(avgScore, totalFConnectReviews, countVerified);
              final col2 = _buildRatingDistributionCard(totalFConnectReviews, count5, count4, count3, count2, count1);
              final col3 = _buildGoogleRatingMetricCard(gRating, gTotal, googleMapsUrl, googleReviews.length, onAddLink: () {
                if (businessId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tài khoản chưa có cơ sở quán ăn. Vui lòng hoàn tất tạo hồ sơ quán trước khi gắn link.'),
                      backgroundColor: Color(0xFFEF4444),
                    ),
                  );
                  _openOnboardingForm();
                  return;
                }
                _showGoogleMapsSyncPromptDialog(businessId, currentUrl: googleMapsUrl, businessName: biz?['name']?.toString());
              });

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: col1),
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: col2),
                    const SizedBox(width: 16),
                    Expanded(flex: 3, child: col3),
                  ],
                );
              } else {
                return Column(
                  children: [
                    col1,
                    const SizedBox(height: 14),
                    col2,
                    const SizedBox(height: 14),
                    col3,
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 24),

          // 3. Filter and Tab Switcher
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Bộ lọc sao
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildOwnerReviewFilterChip('Tất cả ($totalFConnectReviews)', 0, isGoogle: false),
                      const SizedBox(width: 8),
                      _buildOwnerReviewFilterChip('5 Sao ($count5)', 5, isGoogle: false),
                      const SizedBox(width: 8),
                      _buildOwnerReviewFilterChip('4 Sao ($count4)', 4, isGoogle: false),
                      const SizedBox(width: 8),
                      _buildOwnerReviewFilterChip('3 Sao ($count3)', 3, isGoogle: false),
                      const SizedBox(width: 8),
                      _buildOwnerReviewFilterChip('≤ 2 Sao (${count2 + count1})', 2, isGoogle: false),
                      const SizedBox(width: 8),
                      _buildOwnerReviewFilterChip('✓ Đã xác thực ($countVerified)', 99, isGoogle: false),
                      if (googleReviews.isNotEmpty) ...[
                        const SizedBox(width: 14),
                        Container(width: 1, height: 24, color: const Color(0xFFCBD5E1)),
                        const SizedBox(width: 14),
                        _buildOwnerReviewFilterChip('Google Maps (${googleReviews.length})', -1, isGoogle: true),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 4. Danh sách đánh giá
          if (_isLoadingReviews) ...[
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5),
                  SizedBox(height: 14),
                  Text('Đang tải danh sách đánh giá từ máy chủ...', style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5)),
                ],
              ),
            ),
          ] else if (_showGoogleReviewsOnly) ...[
            if (googleReviews.isEmpty)
              _buildEmptyReviewsState('Chưa có đánh giá Google Maps nào được đồng bộ. Bấm nút "Đồng bộ Google Maps" phía trên để tải đánh giá.')
            else
              ...googleReviews.map((g) => _buildGoogleReviewItemCard(g)),
          ] else ...[
            if (filteredFConnectReviews.isEmpty)
              _buildEmptyReviewsState('Không có đánh giá nào phù hợp với bộ lọc hiện tại.')
            else
              ...filteredFConnectReviews.map((rev) => _buildOwnerReviewItemCard(rev)),
          ],
        ],
      ),
    );
  }

  Widget _buildFConnectRatingMetricCard(double avg, int total, int verified) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.storefront_rounded, color: Color(0xFF2563EB), size: 18),
              SizedBox(width: 6),
              Text('FConnect Trực Tiếp', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                avg.toStringAsFixed(1),
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              const SizedBox(width: 4),
              const Text('/ 5.0', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < avg.floor()
                    ? Icons.star_rounded
                    : (i < avg ? Icons.star_half_rounded : Icons.star_outline_rounded),
                color: const Color(0xFFFBBF24),
                size: 18,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$total lượt đánh giá thực tế từ khách hàng',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFECFDF5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 13),
                const SizedBox(width: 4),
                Text('$verified đánh giá có hóa đơn/đặt bàn thực', style: const TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingDistributionCard(int total, int c5, int c4, int c3, int c2, int c1) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Phân Bổ Tỷ Lệ Đánh Giá', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          _buildRatingBarRow('5 ★', c5, total),
          const SizedBox(height: 6),
          _buildRatingBarRow('4 ★', c4, total),
          const SizedBox(height: 6),
          _buildRatingBarRow('3 ★', c3, total),
          const SizedBox(height: 6),
          _buildRatingBarRow('2 ★', c2, total),
          const SizedBox(height: 6),
          _buildRatingBarRow('1 ★', c1, total),
        ],
      ),
    );
  }

  Widget _buildRatingBarRow(String label, int count, int total) {
    final ratio = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 32,
          child: Text(
            '$count',
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleRatingMetricCard(double gRating, int gTotal, String gUrl, int gReviewsCount, {VoidCallback? onAddLink}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Text('GOOGLE PLACES', style: TextStyle(color: Color(0xFFDC2626), fontSize: 10, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 6),
              const Text('Google Maps', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                gRating > 0 ? gRating.toStringAsFixed(1) : 'Chưa có',
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              if (gRating > 0) ...[
                const SizedBox(width: 4),
                const Text('★', style: TextStyle(fontSize: 18, color: Color(0xFFFBBF24))),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            gTotal > 0 ? '$gTotal đánh giá trên Google Maps' : 'Chưa đồng bộ điểm Google Maps',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                gUrl.isNotEmpty ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                size: 14,
                color: gUrl.isNotEmpty ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  gUrl.isNotEmpty ? 'Đã liên kết link Google Maps' : 'Chưa có link bản đồ Google',
                  style: TextStyle(
                    color: gUrl.isNotEmpty ? const Color(0xFF059669) : const Color(0xFF64748B),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (gUrl.isEmpty && onAddLink != null) ...[
                InkWell(
                  onTap: onAddLink,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      '+ Gắn link',
                      style: TextStyle(color: Color(0xFF2563EB), fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerReviewFilterChip(String label, int filterVal, {required bool isGoogle}) {
    final isSelected = isGoogle
        ? _showGoogleReviewsOnly
        : (!_showGoogleReviewsOnly && _selectedReviewRatingFilter == filterVal);

    return InkWell(
      onTap: () {
        setState(() {
          if (isGoogle) {
            _showGoogleReviewsOnly = true;
          } else {
            _showGoogleReviewsOnly = false;
            _selectedReviewRatingFilter = filterVal;
          }
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF334155),
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerReviewItemCard(ReviewModel rev) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFDBEAFE),
                backgroundImage: (rev.userAvatar.isNotEmpty && rev.userAvatar.startsWith('http'))
                    ? NetworkImage(rev.userAvatar)
                    : null,
                child: (rev.userAvatar.isEmpty || !rev.userAvatar.startsWith('http'))
                    ? Text(
                        rev.userName.isNotEmpty ? rev.userName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8), fontSize: 15),
                      )
                    : null,
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
                            rev.userName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (rev.isVerified) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 11),
                                SizedBox(width: 3.5),
                                Text('Đã trải nghiệm ẩm thực', style: TextStyle(color: Color(0xFF059669), fontSize: 10.5, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                        if (rev.branchName != null && rev.branchName!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              rev.branchName!,
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < rev.rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: const Color(0xFFFBBF24),
                              size: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          rev.timeAgo,
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Text('HIỂN THỊ CÔNG KHAI', style: TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            rev.content,
            style: const TextStyle(color: Color(0xFF334155), fontSize: 13.5, height: 1.5),
          ),
          if (rev.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: rev.images.map((img) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    img,
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGoogleReviewItemCard(Map<String, dynamic> g) {
    final author = g['authorName']?.toString() ?? 'Khách hàng Google';
    final photo = g['authorPhotoUrl']?.toString() ?? '';
    final rating = (g['rating'] as num?)?.toDouble() ?? 5.0;
    final text = g['text']?.toString() ?? '';
    final timeDesc = g['relativeTimeDescription']?.toString() ?? 'Gần đây';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFFEE2E2),
                backgroundImage: photo.startsWith('http') ? NetworkImage(photo) : null,
                child: !photo.startsWith('http')
                    ? const Icon(Icons.person, color: Color(0xFFEF4444), size: 20)
                    : null,
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
                            author,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('GOOGLE REVIEW', style: TextStyle(color: Color(0xFFDC2626), fontSize: 9.5, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: const Color(0xFFFBBF24),
                              size: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(timeDesc, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(text, style: const TextStyle(color: Color(0xFF334155), fontSize: 13, height: 1.45)),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyReviewsState(String message) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.rate_review_outlined, size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 10),
          const Text(
            'Chưa có dữ liệu đánh giá',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
          ),
        ],
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
                    _buildSidebarItem(2, Icons.calendar_month_rounded, 'Quản lý Đặt bàn', 'Member 4'),
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
        final bizId = user?.business?['_id']?.toString() ?? user?.business?['id']?.toString();
        return OwnerProductListScreen(businessId: bizId);
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

            final mainGrid = isDesktopTwoCol
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: leftColumn),
                      const SizedBox(width: 20),
                      Expanded(flex: 5, child: rightColumn),
                    ],
                  )
                : Column(
                    children: [
                      leftColumn,
                      const SizedBox(height: 18),
                      rightColumn,
                    ],
                  );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                mainGrid,
                const SizedBox(height: 24),
                _buildReviewsManagementSection(biz, user),
              ],
            );
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

    final currentMonth = DateTime.now().month;

    // Mặc định doanh thu chuẩn cho các tháng trong quá khứ nếu database chưa có đơn (T11, T12 chưa tới nên bằng 0)
    final defaultActualValues = [
      3950000, 5800000, 4150000, 3180000, 5080000, 3580000,
      3920000, 6400000, 4200000, 0, 0, 0,
    ];

    // Gom doanh thu thực tế từ OrderProvider theo từng tháng trong năm
    final actualValues = List<int>.generate(12, (index) {
      final month = index + 1;
      // Tháng chưa tới trong tương lai -> Doanh thu thực tế = 0
      if (month > currentMonth) return 0;

      final monthOrders = orderProvider.ownerOrders.where((o) {
        final st = o.status.toUpperCase();
        if (st != 'COMPLETED' && st != 'SERVED' && st != 'PAID') return false;
        return o.createdAt != null && o.createdAt!.month == month && o.createdAt!.year == DateTime.now().year;
      });
      final realSum = monthOrders.fold<int>(0, (sum, o) => sum + o.total);

      // Tháng hiện tại: 100% dữ liệu thực từ database! Chưa có đơn thanh toán thì = 0 đ!
      if (month == currentMonth) {
        return realSum;
      }
      return realSum > 0 ? realSum : defaultActualValues[index];
    });

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
                  Expanded(flex: 7, child: _buildMonthlyRevenueReportChart(actualValues)),
                  const SizedBox(width: 20),
                  Expanded(flex: 5, child: _buildRevenueGrowthDetailsCard(actualValues)),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildMonthlyRevenueReportChart(actualValues),
                  const SizedBox(height: 20),
                  _buildRevenueGrowthDetailsCard(actualValues),
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

  /// 1. Top 3 mục chỉ số hoạt động thực tế (Doanh thu tháng này, Đặt bàn chờ duyệt, Đặt bàn hôm nay)
  Widget _buildTopMetricsRow() {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);

    final now = DateTime.now();
    final completedOrders = orderProvider.ownerOrders.where((o) {
      final st = o.status.toUpperCase();
      return st == 'COMPLETED' || st == 'SERVED' || st == 'PAID';
    }).toList();

    // Doanh thu hôm nay (chỉ tính các đơn hoàn thành trong ngày hôm nay)
    final todayRevenue = completedOrders.where((o) {
      if (o.createdAt == null) return false;
      return o.createdAt!.year == now.year &&
             o.createdAt!.month == now.month &&
             o.createdAt!.day == now.day;
    }).fold<int>(0, (sum, o) => sum + o.total);

    // Doanh thu tháng này (khớp 100% với cột Tháng ${now.month} trên biểu đồ)
    final thisMonthRevenue = completedOrders.where((o) {
      if (o.createdAt == null) return false;
      return o.createdAt!.year == now.year &&
             o.createdAt!.month == now.month;
    }).fold<int>(0, (sum, o) => sum + o.total);

    String fmtMoney(int amount) {
      return '${amount.toString().replaceAllMapped(RegExp(r"(\\d{1,3})(?=(\\d{3})+(?!\\d))"), (m) => "${m[1]},")} đ';
    }

    // Đặt bàn chờ duyệt thực tế
    final pendingBookings = bookingProvider.pendingCount;

    // Đặt bàn hôm nay thực tế
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final todayBookings = bookingProvider.ownerBookings.where((b) {
      if (b.isCancelled || b.isRejected) return false;
      final d = b.bookingDate;
      return d.contains(todayStr) || d.toLowerCase().contains('hôm nay');
    }).length;

    final cards = [
      {
        'title': 'Doanh thu tháng ${now.month}',
        'value': fmtMoney(thisMonthRevenue),
        'icon': Icons.account_balance_wallet_rounded,
        'colors': [const Color(0xFF059669), const Color(0xFF10B981)],
        'shadow': const Color(0xFF10B981),
        'tag': 'Hôm nay: ${fmtMoney(todayRevenue)}',
        'tagColor': const Color(0xFF059669),
        'tagBg': const Color(0xFFECFDF5),
      },
      {
        'title': 'Đặt bàn chờ duyệt',
        'value': '$pendingBookings',
        'icon': Icons.calendar_month_rounded,
        'colors': [const Color(0xFF1D4ED8), const Color(0xFF3B82F6)],
        'shadow': const Color(0xFF2563EB),
        'tag': pendingBookings > 0 ? 'Cần duyệt ($pendingBookings)' : 'Đã xử lý xong',
        'tagColor': const Color(0xFF2563EB),
        'tagBg': const Color(0xFFEFF6FF),
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
            crossAxisCount: isWide ? 3 : 1,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: isWide ? 3.0 : 2.2,
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
  Widget _buildMonthlyRevenueReportChart([List<int>? passedActualValues]) {
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

    final currentMonth = DateTime.now().month;

    // Dữ liệu doanh thu mẫu trực quan cho các tháng đã qua (T11, T12 chưa tới nên bằng 0)
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
      0,       // T10 (Thực tế từ Database)
      0,       // T11 (Chưa diễn ra)
      0,       // T12 (Chưa diễn ra)
    ];

    // Gom doanh thu thực tế từ OrderProvider nếu trong database có đơn hoàn thành
    final actualValues = passedActualValues ?? List<int>.generate(12, (index) {
      final month = index + 1;
      if (month > currentMonth) return 0;
      final monthOrders = orderProvider.ownerOrders.where((o) {
        final st = o.status.toUpperCase();
        if (st != 'COMPLETED' && st != 'SERVED' && st != 'PAID') return false;
        return o.createdAt != null && o.createdAt!.month == month && o.createdAt!.year == DateTime.now().year;
      });
      final realSum = monthOrders.fold<int>(0, (sum, o) => sum + o.total);

      // Tháng hiện tại: 100% dữ liệu thực từ database! Chưa có đơn thanh toán thì = 0 đ!
      if (month == currentMonth) {
        return realSum;
      }
      return realSum > 0 ? realSum : defaultActualValues[index];
    });

    const maxY = 8000000.0;
    const chartHeight = 220.0;
    final yLabels = ['8 tr', '6 tr', '4 tr', '2 tr', '0 đ'];

    final activeMonthIdx = _activeChartMonth;
    final activeActual = actualValues[activeMonthIdx];
    final activeTarget = targetValues[activeMonthIdx];
    final activePercent = activeTarget > 0 ? ((activeActual / activeTarget) * 100).toStringAsFixed(1) : '0';
    final isOverTarget = activeActual >= activeTarget;
    final isFutureMonth = (activeMonthIdx + 1) > currentMonth;

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
                      'Năm 2026',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Thanh thông tin chi tiết nhanh của Tháng đang rê chuột / click vào
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isFutureMonth
                  ? const Color(0xFFF8FAFC)
                  : (isOverTarget ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isFutureMonth
                    ? const Color(0xFFE2E8F0)
                    : (isOverTarget ? const Color(0xFFBBF7D0) : const Color(0xFFBFDBFE)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isFutureMonth
                      ? Icons.schedule_rounded
                      : (isOverTarget ? Icons.trending_up_rounded : Icons.info_outline_rounded),
                  color: isFutureMonth
                      ? const Color(0xFF64748B)
                      : (isOverTarget ? const Color(0xFF16A34A) : const Color(0xFF2563EB)),
                  size: 17,
                ),
                const SizedBox(width: 8),
                Text(
                  isFutureMonth ? 'Tháng ${activeMonthIdx + 1} (Kế hoạch): ' : 'Tháng ${activeMonthIdx + 1}: ',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                ),
                const Text(
                  'Doanh thu thực tế: ',
                  style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                ),
                Text(
                  '${activeActual.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")} đ  ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isFutureMonth ? const Color(0xFF64748B) : const Color(0xFF15803D),
                  ),
                ),
                Text(
                  '• Mục tiêu: ${activeTarget.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")} đ  ',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isFutureMonth
                        ? const Color(0xFFF1F5F9)
                        : (isOverTarget ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isFutureMonth
                        ? 'Chưa diễn ra'
                        : (isOverTarget ? 'Vượt chỉ tiêu ($activePercent%)' : 'Đạt $activePercent% chỉ tiêu'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isFutureMonth
                          ? const Color(0xFF64748B)
                          : (isOverTarget ? const Color(0xFF15803D) : const Color(0xFF1D4ED8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Vùng vẽ biểu đồ gồm Trục Y, Grid lines ngang & Cột hiển thị số tiền trực tiếp
          SizedBox(
            height: chartHeight + 45,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trục mốc giá trị Y bên trái
                SizedBox(
                  width: 38,
                  height: chartHeight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: yLabels.map((lbl) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          lbl,
                          style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Vùng biểu đồ chính (Gridlines + Cột kép + Số tiền trên đỉnh cột + Nhãn tháng)
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
                                  final isSelected = _activeChartMonth == index;

                                  // Chiều cao cột
                                  final actualH = ((actual / maxY) * (chartHeight - 24)).clamp(0.0, chartHeight - 24);
                                  final targetH = ((target / maxY) * (chartHeight - 24)).clamp(0.0, chartHeight - 24);

                                  final actualShortLabel = '${(actual / 1000000).toStringAsFixed(1)}tr';

                                  return MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    onEnter: (_) => setState(() => _selectedChartMonth = index),
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedChartMonth = index),
                                      child: Tooltip(
                                        message: 'Tháng ${index + 1}:\n• Doanh thu: ${actual.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} đ\n• Mục tiêu: ${target.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} đ',
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isSelected ? const Color(0xFFF1F5F9) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                            border: isSelected ? Border.all(color: const Color(0xFFCBD5E1)) : null,
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              // Cột Doanh Thu Thực Tế (Xanh lá)
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (actual > 0)
                                                    Text(
                                                      actualShortLabel,
                                                      style: TextStyle(
                                                        fontSize: 8.0,
                                                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                                        color: isSelected ? const Color(0xFF15803D) : const Color(0xFF437A24),
                                                      ),
                                                    )
                                                  else
                                                    const SizedBox(height: 10),
                                                  const SizedBox(height: 2),
                                                  Container(
                                                    width: 10,
                                                    height: actualH,
                                                    decoration: BoxDecoration(
                                                      color: isSelected ? const Color(0xFF5BA330) : const Color(0xFF70AD47),
                                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 2),
                                              // Cột Doanh Thu Mục Tiêu (Xanh dương)
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    '${(target / 1000000).toStringAsFixed(1)}tr',
                                                    style: TextStyle(
                                                      fontSize: 8.0,
                                                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                                      color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF4B7BB0),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Container(
                                                    width: 10,
                                                    height: targetH,
                                                    decoration: BoxDecoration(
                                                      color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF5B9BD5),
                                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Nhãn trục X: THÁNG 1 -> THÁNG 12 (Tự động co giãn theo 12 cột, không bao giờ bị overflow)
                      Row(
                        children: List.generate(12, (index) {
                          final isSelected = _activeChartMonth == index;
                          return Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _selectedChartMonth = index),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                decoration: isSelected
                                    ? BoxDecoration(
                                        color: const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(4),
                                      )
                                    : null,
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'THÁNG ${index + 1}',
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 8.0,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected ? Colors.white : const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
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
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFF70AD47), borderRadius: BorderRadius.circular(2))),
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
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFF5B9BD5), borderRadius: BorderRadius.circular(2))),
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
  Widget _buildRevenueGrowthDetailsCard([List<int>? passedActualValues]) {
    final defaultActualValues = [
      3950000, 5800000, 4150000, 3180000, 5080000, 3580000,
      3920000, 6400000, 4200000, 0, 0, 0,
    ];
    final actualValues = passedActualValues ?? defaultActualValues;

    // Tháng hiện tại (lấy theo thời gian thực hoặc mốc 10)
    final now = DateTime.now();
    final curMonth = now.month;
    final curVal = actualValues[curMonth - 1];
    final prevMonth = curMonth > 1 ? curMonth - 1 : 12;
    final prevVal = actualValues[prevMonth - 1];

    double momRate = 0;
    if (prevVal > 0) {
      momRate = ((curVal - prevVal) / prevVal) * 100;
    }
    final momIsPositive = momRate >= 0;
    final momSign = momIsPositive ? '+' : '';
    final momStr = '$momSign${momRate.toStringAsFixed(1)}%';

    // Tìm tháng đạt đỉnh doanh thu
    int peakIdx = 0;
    int peakVal = actualValues[0];
    for (int i = 1; i < actualValues.length; i++) {
      if (actualValues[i] > peakVal) {
        peakVal = actualValues[i];
        peakIdx = i;
      }
    }
    final peakMonthName = 'Tháng ${peakIdx + 1}';
    final avgVal = actualValues.reduce((a, b) => a + b) / 12;
    final peakRate = avgVal > 0 ? ((peakVal - avgVal) / avgVal * 100) : 0.0;
    final peakSign = peakRate >= 0 ? '+' : '';
    final peakStr = '$peakSign${peakRate.toStringAsFixed(1)}%';

    String fmtMoney(int amount) {
      return '${amount.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")} đ';
    }

    // 4 tháng gần nhất (ví dụ T10, T9, T8, T7)
    final recentMonths = <int>[];
    for (int i = 0; i < 4; i++) {
      int m = curMonth - i;
      if (m <= 0) m += 12;
      recentMonths.add(m);
    }

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
          // Tiêu đề & Badge MoM
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

          // 2 Hàng thông số chính
          _buildGrowthMetricRow('Tháng này vs Tháng trước ', momStr, boldSuffix: '(MoM)', isPositive: momIsPositive, isHighlighted: true),
          const SizedBox(height: 10),
          _buildGrowthMetricRow('Tháng đạt đỉnh doanh thu ', peakStr, boldSuffix: '($peakMonthName)', isPositive: true),

          const SizedBox(height: 18),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Danh sách biến động 4 tháng gần nhất: Tự động tính toán từ doanh thu thực tế
          const Text(
            'Chi tiết biến động 4 tháng gần nhất:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 10),
          ...recentMonths.map((m) {
            final val = actualValues[m - 1];
            final prevM = m - 1 <= 0 ? 12 : m - 1;
            final pVal = actualValues[prevM - 1];
            double rate = 0;
            if (pVal > 0) {
              rate = ((val - pVal) / pVal) * 100;
            }
            final isUp = rate >= 0;
            final sign = isUp ? '+' : '';
            final rateStr = (val == 0 && m == curMonth)
                ? 'Chưa có đơn'
                : '$sign${rate.toStringAsFixed(1)}% so với T$prevM';
            String? boldSuffix;
            if (m == curMonth) {
              boldSuffix = '(Hiện tại)';
            } else if (m == prevMonth) {
              boldSuffix = '(Tháng trước)';
            }
            return _buildMiniMonthGrowthCard('Tháng $m ', fmtMoney(val), rateStr, boldSuffix: boldSuffix, isUp: isUp);
          }),
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

    // Danh sách đặt bàn hiển thị: 100% từ Server
    final displayBookings = recentBookings;

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
          if (displayBookings.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 36, color: Color(0xFF94A3B8)),
                  SizedBox(height: 8),
                  Text('Chưa có lượt đặt bàn nào gần đây.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                ],
              ),
            )
          else
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
  // HELPER METHODS FOR TAB 2 (BOOKING & TABLE) & TAB 3 (ORDER)
  // =========================================================================

  String _formatOwnerPrice(int amount) {
    return '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ';
  }

  void _updateBookingStatusDirect(BookingModel b, String status, String actionTitle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$actionTitle?'),
        content: Text('Bạn có chắc chắn muốn thực hiện thao tác "$actionTitle" cho đơn đặt bàn #${b.bookingCode}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await Provider.of<BookingProvider>(context, listen: false)
                  .updateOwnerBookingStatus(b.id, status);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Thao tác thành công'),
                    backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'REJECTED' || status == 'CANCELLED'
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF0072FF),
              foregroundColor: Colors.white,
            ),
            child: Text(actionTitle),
          ),
        ],
      ),
    );
  }

  void _progressOwnerOrderStatus(OrderModel o, String nextStatus, String actionTitle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$actionTitle?'),
        content: Text('Xác nhận chuyển trạng thái đơn #${o.orderCode} sang "$actionTitle"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await Provider.of<OrderProvider>(context, listen: false)
                  .updateOrderStatus(o.id, nextStatus);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Cập nhật thành công!'),
                    backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: nextStatus == 'CANCELLED' ? const Color(0xFFEF4444) : const Color(0xFF0072FF),
              foregroundColor: Colors.white,
            ),
            child: Text(actionTitle),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: QUẢN LÝ BÀN & ĐẶT CHỖ (GIAO DIỆN WEB QUẢN TRỊ CHUYÊN NGHIỆP)
  // =========================================================================
  Widget _buildTab2BookingSkeleton() {
    final bookingProvider = Provider.of<BookingProvider>(context);

    final checkedInCount = bookingProvider.ownerBookings.where((b) => b.isCheckedIn).length;
    final completedCount = bookingProvider.ownerBookings.where((b) => b.isCompleted).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        const Text(
                          'Quản Lý Đặt Bàn',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Text(
                            'Thành viên 4 (Booking)',
                            style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Quản lý và tiếp nhận lịch hẹn đặt bàn của thực khách trực tiếp trên cổng Web.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loadDashboardData,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Làm mới'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0072FF),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 4 KPI Stats thuần Đặt bàn
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 750;
            if (isDesktop) {
              return Row(
                children: [
                  _buildStatItem('Đặt bàn chờ duyệt', '${bookingProvider.pendingCount}', const Color(0xFFF59E0B), Icons.event_available_rounded),
                  const SizedBox(width: 12),
                  _buildStatItem('Đã xác nhận', '${bookingProvider.confirmedCount}', const Color(0xFF0072FF), Icons.check_circle_rounded),
                  const SizedBox(width: 12),
                  _buildStatItem('Đã nhận bàn (Check-in)', '$checkedInCount', const Color(0xFF10B981), Icons.login_rounded),
                  const SizedBox(width: 12),
                  _buildStatItem('Hoàn tất', '$completedCount', const Color(0xFF8B5CF6), Icons.done_all_rounded),
                ],
              );
            } else {
              return Column(
                children: [
                  Row(
                    children: [
                      _buildStatItem('Chờ duyệt', '${bookingProvider.pendingCount}', const Color(0xFFF59E0B), Icons.event_available_rounded),
                      const SizedBox(width: 12),
                      _buildStatItem('Đã xác nhận', '${bookingProvider.confirmedCount}', const Color(0xFF0072FF), Icons.check_circle_rounded),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStatItem('Đã nhận bàn', '$checkedInCount', const Color(0xFF10B981), Icons.login_rounded),
                      const SizedBox(width: 12),
                      _buildStatItem('Hoàn tất', '$completedCount', const Color(0xFF8B5CF6), Icons.done_all_rounded),
                    ],
                  ),
                ],
              );
            }
          },
        ),
        const SizedBox(height: 20),

        // Hiển thị trực tiếp danh sách đặt bàn
        _buildWebBookingSubView(bookingProvider),
      ],
    );
  }

    /// Khung hiển thị Lịch Đặt Bàn dạng Web Responsive
  Widget _buildWebBookingSubView(BookingProvider bookingProvider) {
    final filterTabs = ['Tất cả', 'Chờ xác nhận', 'Đã xác nhận', 'Đã nhận bàn', 'Hoàn tất', 'Đã hủy / Từ chối'];

    List<BookingModel> filtered = bookingProvider.ownerBookings;
    switch (_tab2BookingFilter) {
      case 1:
        filtered = filtered.where((b) => b.isPending).toList();
        break;
      case 2:
        filtered = filtered.where((b) => b.isConfirmed).toList();
        break;
      case 3:
        filtered = filtered.where((b) => b.isCheckedIn).toList();
        break;
      case 4:
        filtered = filtered.where((b) => b.isCompleted).toList();
        break;
      case 5:
        filtered = filtered.where((b) => b.isCancelled || b.isRejected).toList();
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(filterTabs.length, (idx) {
              final active = _tab2BookingFilter == idx;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filterTabs[idx]),
                  selected: active,
                  onSelected: (_) => setState(() => _tab2BookingFilter = idx),
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xFF0072FF),
                  labelStyle: TextStyle(
                    color: active ? Colors.white : const Color(0xFF475569),
                    fontWeight: active ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                  side: BorderSide(color: active ? const Color(0xFF0072FF) : const Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  showCheckmark: false,
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),

        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.event_note_outlined, size: 48, color: Color(0xFF94A3B8)),
                  SizedBox(height: 12),
                  Text('Không có đơn đặt bàn nào trong danh mục này',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 14)),
                ],
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;
              if (isDesktop) {
                final rows = <Widget>[];
                for (int i = 0; i < filtered.length; i += 2) {
                  final b1 = filtered[i];
                  final b2 = (i + 1 < filtered.length) ? filtered[i + 1] : null;
                  rows.add(
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _buildWebBookingCard(b1)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: b2 != null
                                  ? _buildWebBookingCard(b2)
                                  : const SizedBox(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: rows,
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: filtered.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildWebBookingCard(b),
                  )).toList(),
                );
              }
            },
          ),
      ],
    );
  }

    /// Card Đặt bàn dạng Web
  Widget _buildWebBookingCard(BookingModel b) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    OrderModel? linkedOrder;
    for (final ord in orderProvider.ownerOrders) {
      if ((ord.bookingId != null && ord.bookingId == b.id) ||
          (ord.bookingCode != null && ord.bookingCode == b.bookingCode)) {
        linkedOrder = ord;
        break;
      }
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Khối nội dung trên
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Code & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('#${b.bookingCode}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155))),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: b.statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: b.statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(b.statusLabel,
                        style: TextStyle(color: b.statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 2: Customer info
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF0072FF).withValues(alpha: 0.1),
                    child: Text(
                      (b.userName != null && b.userName!.trim().isNotEmpty) ? b.userName!.trim()[0].toUpperCase() : 'K',
                      style: const TextStyle(color: Color(0xFF0072FF), fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.userName ?? 'Khách đặt bàn',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text(
                          (b.userPhone != null && b.userPhone!.isNotEmpty) ? 'SĐT: ${b.userPhone}' : 'SĐT: Chưa cập nhật',
                          style: TextStyle(
                            color: (b.userPhone != null && b.userPhone!.isNotEmpty) ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people_outline, size: 14, color: Color(0xFF2563EB)),
                        const SizedBox(width: 4),
                        Text('${b.guestCount} khách',
                            style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),

              // Row 3: Schedule
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF0072FF)),
                  const SizedBox(width: 6),
                  Text('${b.startTime} • ${b.bookingDate}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B))),
                ],
              ),

              // Row 4: Note (if any)
              if (b.note.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'Ghi chú: ${b.note}',
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                  ),
                ),
              ],

              // Row 5: Pre-ordered dishes preview
              if (linkedOrder != null && linkedOrder.items.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.restaurant_menu_rounded, size: 14, color: Color(0xFF2563EB)),
                          const SizedBox(width: 6),
                          Text('Món đặt trước (${linkedOrder.items.length} món) • ${_formatOwnerPrice(linkedOrder.total)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        linkedOrder.items.map((it) => '${it.quantity}x ${it.productName}').join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          // Khối thanh tác vụ đáy (Luôn neo ở đáy thẻ để đường chân đế của hai thẻ bằng tăm tắp)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (b.isPending) ...[
                    OutlinedButton(
                      onPressed: () => _updateBookingStatusDirect(b, 'REJECTED', 'Từ chối đặt bàn'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Từ chối', style: TextStyle(fontSize: 12.5)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _updateBookingStatusDirect(b, 'CONFIRMED', 'Xác nhận đặt bàn'),
                      icon: const Icon(Icons.check_circle_outline, size: 15),
                      label: const Text('Xác nhận đặt bàn', style: TextStyle(fontSize: 12.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0072FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ] else if (b.isConfirmed) ...[
                    OutlinedButton(
                      onPressed: () => _updateBookingStatusDirect(b, 'CANCELLED', 'Hủy đặt bàn'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Hủy hẹn', style: TextStyle(fontSize: 12.5)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _updateBookingStatusDirect(b, 'CHECKED_IN', 'Khách nhận bàn'),
                      icon: const Icon(Icons.login_rounded, size: 15),
                      label: const Text('Khách nhận bàn (Check-in)', style: TextStyle(fontSize: 12.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ] else if (b.isCheckedIn) ...[
                    ElevatedButton.icon(
                      onPressed: () => _updateBookingStatusDirect(b, 'COMPLETED', 'Hoàn tất bữa ăn'),
                      icon: const Icon(Icons.done_all_rounded, size: 15),
                      label: const Text('Hoàn tất bữa ăn', style: TextStyle(fontSize: 12.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0072FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: b.statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: b.statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(b.isCompleted ? Icons.check_circle_rounded : Icons.info_outline, size: 14, color: b.statusColor),
                          const SizedBox(width: 4),
                          Text(b.statusLabel, style: TextStyle(color: b.statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

    // =========================================================================
  // TAB 3: QUẢN LÝ ĐƠN HÀNG (GIAO DIỆN WEB QUẢN TRỊ CHUYÊN NGHIỆP)
  // =========================================================================
  Widget _buildTab3OrderSkeleton() {
    final orderProvider = Provider.of<OrderProvider>(context);

    final filterTabs = ['Tất cả', 'Chờ xác nhận', 'Đang chuẩn bị', 'Sẵn sàng lên món', 'Đã phục vụ', 'Hoàn tất'];

    List<OrderModel> filtered = orderProvider.ownerOrders;
    switch (_tab3OrderFilter) {
      case 1:
        filtered = filtered.where((o) => o.isPending).toList();
        break;
      case 2:
        filtered = filtered.where((o) => o.isConfirmed || o.isPreparing).toList();
        break;
      case 3:
        filtered = filtered.where((o) => o.isReady).toList();
        break;
      case 4:
        filtered = filtered.where((o) => o.isServed).toList();
        break;
      case 5:
        filtered = filtered.where((o) => o.isCompleted).toList();
        break;
    }

    final todayCompletedRevenue = orderProvider.ownerOrders
        .where((o) => o.isCompleted || o.isServed)
        .fold<int>(0, (sum, o) => sum + o.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        const Text(
                          'Quản Lý Đơn Hàng Gọi Món',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Text(
                            'Thành viên 4 (Booking & Order)',
                            style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Theo dõi đơn gọi món tại bàn & đặt trước, xác nhận chế biến, sẵn sàng phục vụ và quản lý thanh toán.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loadDashboardData,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Làm mới'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0072FF),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Quick Stats
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 750;
            if (isDesktop) {
              return Row(
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
                  const SizedBox(width: 12),
                  _buildStatItem(
                    'Doanh thu phục vụ',
                    _formatOwnerPrice(todayCompletedRevenue),
                    const Color(0xFF10B981),
                    Icons.payments_rounded,
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  Row(
                    children: [
                      _buildStatItem(
                        'Đơn cần làm',
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStatItem(
                        'Doanh thu phục vụ',
                        _formatOwnerPrice(todayCompletedRevenue),
                        const Color(0xFF10B981),
                        Icons.payments_rounded,
                      ),
                    ],
                  ),
                ],
              );
            }
          },
        ),
        const SizedBox(height: 20),

        // Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(filterTabs.length, (idx) {
              final active = _tab3OrderFilter == idx;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filterTabs[idx]),
                  selected: active,
                  onSelected: (_) => setState(() => _tab3OrderFilter = idx),
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xFF0072FF),
                  labelStyle: TextStyle(
                    color: active ? Colors.white : const Color(0xFF475569),
                    fontWeight: active ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                  side: BorderSide(color: active ? const Color(0xFF0072FF) : const Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  showCheckmark: false,
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),

        // Order Cards Grid (Đồng bộ chiều cao và bề rộng tuyệt đối)
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFF94A3B8)),
                  SizedBox(height: 12),
                  Text('Không có đơn hàng nào trong mục này',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 14)),
                ],
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;
              if (isDesktop) {
                final rows = <Widget>[];
                for (int i = 0; i < filtered.length; i += 2) {
                  final o1 = filtered[i];
                  final o2 = (i + 1 < filtered.length) ? filtered[i + 1] : null;
                  rows.add(
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _buildWebOrderCard(o1)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: o2 != null
                                  ? _buildWebOrderCard(o2)
                                  : const SizedBox(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: rows,
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: filtered.map((o) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildWebOrderCard(o),
                  )).toList(),
                );
              }
            },
          ),
      ],
    );
  }

  /// Card Đơn Hàng dạng Web (Chiều cao đồng bộ chuẩn Web CMS)
  Widget _buildWebOrderCard(OrderModel o) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Khối nội dung trên
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Code & Type & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('#${o.orderCode}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155))),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          o.orderTypeLabel,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: o.statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: o.statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(o.statusLabel,
                        style: TextStyle(color: o.statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 2: Customer info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.userName ?? 'Khách đặt món',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text(
                          (o.userPhone != null && o.userPhone!.isNotEmpty) ? 'SĐT: ${o.userPhone}' : 'SĐT: Chưa cập nhật',
                          style: TextStyle(
                            color: (o.userPhone != null && o.userPhone!.isNotEmpty) ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),

              // Row 3: Items Table List
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...o.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0072FF).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('${item.quantity}x',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0072FF))),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.productName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B))),
                                  if (item.sizeName != null || item.optionTexts.isNotEmpty)
                                    Text(
                                      [
                                        if (item.sizeName != null) 'Size: ${item.sizeName}',
                                        ...item.optionTexts,
                                      ].join(' • '),
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                ],
                              ),
                            ),
                            Text(_formatOwnerPrice(item.subtotal),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF475569))),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Row 4: Note
              if (o.note.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Ghi chú: ${o.note}',
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
              ],
            ],
          ),

          // Row 5: Total & Actions (Cố định ở đáy thẻ để đường chân đế của hai thẻ bằng tăm tắp)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tổng thanh toán:', style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
                      Text(_formatOwnerPrice(o.total),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0072FF))),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (o.isPending) ...[
                        OutlinedButton(
                          onPressed: () => _progressOwnerOrderStatus(o, 'CANCELLED', 'Hủy đơn hàng'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Hủy', style: TextStyle(fontSize: 12.5)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _progressOwnerOrderStatus(o, 'CONFIRMED', 'Xác nhận đơn'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0072FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Xác nhận đơn', style: TextStyle(fontSize: 12.5)),
                        ),
                      ] else if (o.isConfirmed) ...[
                        ElevatedButton(
                          onPressed: () => _progressOwnerOrderStatus(o, 'PREPARING', 'Bắt đầu chế biến'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0072FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Bắt đầu chế biến', style: TextStyle(fontSize: 12.5)),
                        ),
                      ] else if (o.isPreparing) ...[
                        ElevatedButton(
                          onPressed: () => _progressOwnerOrderStatus(o, 'READY', 'Sẵn sàng lên món'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Sẵn sàng lên món', style: TextStyle(fontSize: 12.5)),
                        ),
                      ] else if (o.isReady) ...[
                        ElevatedButton(
                          onPressed: () => _progressOwnerOrderStatus(o, 'SERVED', 'Đã phục vụ tại bàn'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Đã phục vụ tại bàn', style: TextStyle(fontSize: 12.5)),
                        ),
                      ] else if (o.isServed) ...[
                        ElevatedButton(
                          onPressed: () => _progressOwnerOrderStatus(o, 'COMPLETED', 'Hoàn tất đơn hàng'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Hoàn tất đơn', style: TextStyle(fontSize: 12.5)),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: o.statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: o.statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            o.statusLabel,
                            style: TextStyle(color: o.statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
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

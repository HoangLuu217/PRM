import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/api_constants.dart';
import '../../models/restaurant_model.dart';
import '../../models/product_model.dart';
import '../../providers/product_provider.dart';
import '../../providers/favorite_provider.dart';
import '../../models/review_model.dart';
import '../../services/review_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../auth/login_screen.dart';
import 'booking/booking_screen.dart';
import 'chat/customer_chat_screen.dart';
import 'product/product_detail_screen.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final RestaurantModel restaurant;
  final int initialTabIndex;

  const RestaurantDetailScreen({
    super.key,
    required this.restaurant,
    this.initialTabIndex = 0,
  });

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  late int _selectedTabIndex;
  bool _isFavorite = false;
  bool _isLoadingMenu = true;
  List<Map<String, dynamic>> _menuItems = [];
  final ReviewService _reviewService = ReviewService();
  List<ReviewModel> _realReviews = [];
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false).fetchProducts(businessId: widget.restaurant.id);
      Provider.of<FavoriteProvider>(context, listen: false).loadFavoriteIds();
    });
    _loadMenuProducts();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await _reviewService.getBusinessReviews(widget.restaurant.id);
      if (mounted) {
        setState(() {
          _realReviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReviews = false);
      }
    }
  }

  Future<void> _loadMenuProducts() async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/products?businessId=${widget.restaurant.id}');
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['data'] as List<dynamic>?) ?? [];
        if (mounted) {
          setState(() {
            _menuItems = list.map((item) => item as Map<String, dynamic>).toList();
            _isLoadingMenu = false;
          });
          return;
        }
      }
    } catch (_) {}

    // Fallback menu nếu không kết nối được
    if (mounted) {
      setState(() {
        _menuItems = [
          {
            'name': 'Món Đặc Trưng Số 1',
            'category': 'Món Chính',
            'description': 'Được chế biến từ nguyên liệu tươi sống chọn lọc mỗi ngày.',
            'price': widget.restaurant.minPrice,
            'imageUrl': widget.restaurant.coverImageUrl,
          },
          {
            'name': 'Món Đặc Trưng Số 2',
            'category': 'Món Bếp Trưởng',
            'description': 'Công thức bí truyền độc quyền chuẩn hương vị Đà Nẵng.',
            'price': (widget.restaurant.minPrice + widget.restaurant.maxPrice) ~/ 2,
            'imageUrl': widget.restaurant.coverImageUrl,
          },
          {
            'name': 'Món Đặc Trưng Số 3',
            'category': 'Món Ăn Kèm',
            'description': 'Hương vị đậm đà hấp dẫn làm hài lòng mọi thực khách.',
            'price': widget.restaurant.maxPrice,
            'imageUrl': widget.restaurant.coverImageUrl,
          },
        ];
        _isLoadingMenu = false;
      });
    }
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    final phone = (phoneNumber != null && phoneNumber.trim().isNotEmpty)
        ? phoneNumber.replaceAll(RegExp(r'\s+'), '')
        : '0905207848';
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể thực hiện cuộc gọi: $e')),
        );
      }
    }
  }

  Future<void> _openGoogleMapsDirections() async {
    final lat = widget.restaurant.latitude;
    final lng = widget.restaurant.longitude;
    final googleMapsAppUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final webUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');

    try {
      if (await canLaunchUrl(googleMapsAppUri)) {
        await launchUrl(googleMapsAppUri);
        return;
      }
    } catch (_) {}

    try {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi mở bản đồ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header FConnect chuẩn đồng bộ
            _buildTopHeader(authProvider),

            // 2. Nội dung cuộn chính
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ảnh bìa quán + Overlay thông tin
                    _buildCoverHeroImage(r),

                    // Thanh Tab chuyển đổi: Thông tin, Thực đơn, Bài viết, Đánh giá
                    _buildSegmentedTabBar(),

                    // Nội dung theo từng tab
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildCurrentTabContent(r),
                    ),

                    const SizedBox(height: 80), // Padding cho thanh Sticky Bottom
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // 3. Thanh tác vụ dưới cùng: Gọi điện & Đặt bàn ngay
      bottomNavigationBar: _buildStickyBottomActionBar(r),
    );
  }

  // Widget Top Header
  Widget _buildTopHeader(AuthProvider authProvider) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          // Logo FConnect
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Nút chọn thành phố
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF0072FF)),
                const SizedBox(width: 4),
                Text(
                  widget.restaurant.city,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Ô tìm kiếm
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tìm quán, món ăn...',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Nút đăng nhập
          if (!authProvider.isAuthenticated)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              icon: const Icon(Icons.person_outline, size: 14),
              label: const Text('Đăng nhập', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0072FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
        ],
      ),
    );
  }

  // Widget Ảnh bìa Hero + Overlay thông tin quán
  Widget _buildCoverHeroImage(RestaurantModel r) {
    return SizedBox(
      height: 230,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ảnh quán
          Image.network(
            r.coverImageUrl ?? r.logoUrl ?? 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFF1E293B),
              child: const Icon(Icons.restaurant_rounded, size: 48, color: Colors.white54),
            ),
          ),

          // Gradient đen phủ từ dưới lên
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),

          // Nút Back + Nút Gọi & Nút Yêu thích ở trên
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.45),
                  radius: 18,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.black.withValues(alpha: 0.45),
                      radius: 18,
                      child: IconButton(
                        icon: const Icon(Icons.forum_rounded, color: Colors.white, size: 17),
                        tooltip: 'Chat với quán',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CustomerChatScreen(restaurant: r),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Colors.black.withValues(alpha: 0.45),
                      radius: 18,
                      child: IconButton(
                        icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 18),
                        onPressed: () => _makePhoneCall(r.phone),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Colors.black.withValues(alpha: 0.45),
                      radius: 18,
                      child: IconButton(
                        icon: Icon(
                          _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: _isFavorite ? const Color(0xFFEF4444) : Colors.white,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() => _isFavorite = !_isFavorite);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_isFavorite ? 'Đã thêm vào danh sách yêu thích' : 'Đã bỏ yêu thích'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Thông tin dưới chân ảnh bìa
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tag Trạng thái + Giá
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Đang mở cửa',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        r.formattedPrice,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Tên quán ăn
                Text(
                  r.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Danh mục + Đánh giá sao vàng
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      r.displayCategory,
                      style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12.5),
                    ),
                    InkWell(
                      onTap: () => setState(() => _selectedTabIndex = 3),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 18),
                            const SizedBox(width: 3),
                            Text(
                              '${r.rating}',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${_realReviews.isNotEmpty ? _realReviews.length : r.totalReviews} đánh giá)',
                              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5, decoration: TextDecoration.underline),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 10),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget Thanh Tab Segmented Bar
  Widget _buildSegmentedTabBar() {
    final tabs = [
      {'title': 'Thông tin', 'icon': Icons.info_outline_rounded},
      {'title': 'Thực đơn (${_menuItems.length})', 'icon': Icons.restaurant_menu_rounded},
      {'title': 'Bài viết (1)', 'icon': Icons.menu_book_rounded},
      {'title': 'Đánh giá (${_realReviews.isNotEmpty ? _realReviews.length : widget.restaurant.totalReviews})', 'icon': Icons.star_border_rounded},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(tabs.length, (idx) {
            final isSel = _selectedTabIndex == idx;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: InkWell(
                onTap: () => setState(() => _selectedTabIndex = idx),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF0072FF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSel ? const Color(0xFF0072FF) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        tabs[idx]['icon'] as IconData,
                        size: 15,
                        color: isSel ? Colors.white : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tabs[idx]['title'] as String,
                        style: TextStyle(
                          color: isSel ? Colors.white : const Color(0xFF334155),
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // Widget Nội dung theo Tab đang chọn
  Widget _buildCurrentTabContent(RestaurantModel r) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildInfoTabContent(r);
      case 1:
        return _buildMenuTabContent();
      case 2:
        return _buildArticlesTabContent();
      case 3:
        return _buildReviewsTabContent(r);
      default:
        return _buildInfoTabContent(r);
    }
  }

  // 1. Tab THÔNG TIN QUÁN (Giới thiệu, Điểm nổi bật & Tiện ích, Bản đồ định vị)
  Widget _buildInfoTabContent(RestaurantModel r) {
    final featuresList = [
      'Thanh toán chuyển khoản / QR',
      'Wifi tốc độ cao',
      'Chỗ để xe máy miễn phí',
      'Chỗ để ô tô rộng rãi',
      'Không gian ngoài trời / Sân vườn',
      'Thanh toán thẻ (POS)',
      'Xuất hóa đơn VAT',
      'Ghế trẻ em',
      ...r.vibes,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card 1: Giới thiệu quán
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFF0072FF), size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Giới thiệu quán',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                r.description.isNotEmpty
                    ? r.description
                    : 'Nhà hàng ẩm thực uy tín bậc nhất tại Đà Nẵng, không gian thoáng mát, đồ ăn tươi ngon đậm vị miền Trung.',
                style: const TextStyle(fontSize: 13.5, height: 1.5, color: Color(0xFF334155)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Card 2: Điểm nổi bật & Tiện ích
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Điểm nổi bật & Tiện ích',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: featuresList.toSet().map((feat) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, size: 13, color: Color(0xFF059669)),
                        const SizedBox(width: 5),
                        Text(
                          feat,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Card 3: Vị trí & Bản đồ
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.explore_outlined, color: Color(0xFF0072FF), size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Vị trí & Bản đồ',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _openGoogleMapsDirections,
                    child: const Row(
                      children: [
                        Text(
                          'Chỉ đường',
                          style: TextStyle(color: Color(0xFF0072FF), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF0072FF)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      r.address,
                      style: const TextStyle(color: Color(0xFF475569), fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Mini Map Pinned
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(r.latitude, r.longitude),
                          initialZoom: 15.5,
                          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                            fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'vn.fconnect.app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(r.latitude, r.longitude),
                                width: 44,
                                height: 44,
                                child: const Icon(Icons.location_pin, color: Color(0xFFEF4444), size: 40),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _openGoogleMapsDirections,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Card 4: Xem trước đánh giá từ thực khách
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x04000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Đánh giá thực khách (${_realReviews.isNotEmpty ? _realReviews.length : r.totalReviews})',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => setState(() => _selectedTabIndex = 3),
                    child: const Row(
                      children: [
                        Text(
                          'Xem tất cả',
                          style: TextStyle(color: Color(0xFF0072FF), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF0072FF)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    Text(
                      _realReviews.isNotEmpty
                          ? (_realReviews.fold<double>(0.0, (s, e) => s + e.rating) / _realReviews.length).toStringAsFixed(1)
                          : r.rating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (i) => const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 16),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_realReviews.isNotEmpty ? _realReviews.length : r.totalReviews} lượt đánh giá thực tế từ khách hàng',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_realReviews.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._realReviews.take(2).map((rev) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                rev.userName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                              ),
                              if (rev.isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF10B981)),
                              ],
                            ],
                          ),
                          Row(
                            children: List.generate(
                              rev.rating.round().clamp(1, 5),
                              (i) => const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rev.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                )),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _selectedTabIndex = 3),
                  icon: const Icon(Icons.rate_review_outlined, size: 16),
                  label: Text(
                    'Xem toàn bộ ${_realReviews.isNotEmpty ? _realReviews.length : r.totalReviews} đánh giá & Viết nhận xét',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0072FF),
                    side: const BorderSide(color: Color(0xFF0072FF)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 2. Tab THỰC ĐƠN MÓN ĂN
  Widget _buildMenuTabContent() {
    if (_isLoadingMenu) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_menuItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        alignment: Alignment.center,
        child: const Text('Thực đơn đang được quán cập nhật.', style: TextStyle(color: Color(0xFF64748B))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thực đơn món ăn đặc sắc',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 12),
        ..._menuItems.map((prod) {
          final id = (prod['_id'] ?? prod['id'] ?? 'item_${prod['name'].hashCode}').toString();
          final name = prod['name']?.toString() ?? 'Món ngon';
          final desc = prod['description']?.toString() ?? '';
          final price = (prod['price'] as num?)?.toDouble() ?? 50000.0;
          final img = prod['imageUrl']?.toString() ?? widget.restaurant.coverImageUrl;
          final cat = prod['category']?.toString() ?? 'Món chính';

          final productModel = ProductModel(
            id: id,
            category: cat,
            name: name,
            description: desc,
            price: price,
            imageUrl: img ?? '',
          );

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(
                      product: productModel,
                      businessId: widget.restaurant.id,
                      businessName: widget.restaurant.name,
                      branchId: widget.restaurant.branchId,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        img ?? 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=80',
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 76,
                          height: 76,
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(Icons.fastfood_rounded, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              cat,
                              style: const TextStyle(color: Color(0xFF0072FF), fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F172A)),
                          ),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              desc,
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            '${price.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ',
                            style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Nút + Thêm vào giỏ hàng trực tiếp
                    ElevatedButton(
                      onPressed: () {
                        final cartProvider = Provider.of<CartProvider>(context, listen: false);
                        cartProvider.addItem(
                          product: productModel,
                          targetBusinessId: widget.restaurant.id,
                          targetBusinessName: widget.restaurant.name,
                          targetBranchId: widget.restaurant.branchId,
                          quantity: 1,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã thêm "$name" vào giỏ hàng!'),
                            backgroundColor: const Color(0xFF10B981),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0072FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_shopping_cart_rounded, size: 15),
                          SizedBox(width: 4),
                          Text('Thêm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // 3. Tab BÀI VIẾT REVIEW
  Widget _buildArticlesTabContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              widget.restaurant.coverImageUrl ?? 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=600&q=80',
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Khám phá trải nghiệm ẩm thực đỉnh cao tại ${widget.restaurant.name}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bởi Ban Biên Tập FConnect • 4 phút đọc',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.restaurant.name} là một trong những điểm đến ẩm thực tiêu biểu tại Đà Nẵng, mang đến hương vị chuẩn mực và không gian phục vụ chuyên nghiệp...',
            style: const TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  // 4. Tab ĐÁNH GIÁ (100% Real Reviews từ MongoDB)
  int _customerReviewRatingFilter = 0; // 0 = Tất cả, 5, 4, 3, 2, 1

  Widget _buildReviewsTabContent(RestaurantModel r) {
    final hasRealReviews = _realReviews.isNotEmpty;
    final avgRating = hasRealReviews
        ? (_realReviews.fold<double>(0.0, (sum, item) => sum + item.rating) / _realReviews.length)
        : r.rating;
    final displayRating = avgRating > 0 ? avgRating.toStringAsFixed(1) : r.rating.toStringAsFixed(1);
    final totalCount = hasRealReviews ? _realReviews.length : r.totalReviews;
    final verifiedCount = _realReviews.where((rev) => rev.isVerified).length;
    final count5 = _realReviews.where((rev) => rev.rating.round() == 5).length;
    final count4 = _realReviews.where((rev) => rev.rating.round() == 4).length;
    final count3 = _realReviews.where((rev) => rev.rating.round() == 3).length;
    final count2OrLess = _realReviews.where((rev) => rev.rating.round() <= 2).length;

    // Lọc theo số sao nếu người dùng chọn
    final filteredReviews = _customerReviewRatingFilter == 0
        ? _realReviews
        : _realReviews.where((rev) => rev.rating.round() == _customerReviewRatingFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tổng quan điểm sao và hành động Đánh giá
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        displayRating,
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < avgRating.floor()
                                ? Icons.star_rounded
                                : (i < avgRating ? Icons.star_half_rounded : Icons.star_outline_rounded),
                            color: const Color(0xFFFBBF24),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalCount lượt đánh giá thực tế',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 70, color: const Color(0xFFE2E8F0)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Uy tín cộng đồng FConnect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '$verifiedCount đánh giá có xác thực',
                            style: const TextStyle(color: Color(0xFF059669), fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text('Món ăn ngon • Không gian đẹp', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFF1F5F9)),
              const SizedBox(height: 8),

              // Nút Viết đánh giá cho khách hàng
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddReviewModal(r),
                  icon: const Icon(Icons.rate_review_rounded, size: 18),
                  label: const Text('Viết đánh giá cho quán này', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Bộ lọc sao nhanh
        if (_realReviews.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCustomerFilterChip('Tất cả ($totalCount)', 0),
                const SizedBox(width: 8),
                _buildCustomerFilterChip('5 ★ ($count5)', 5),
                const SizedBox(width: 8),
                _buildCustomerFilterChip('4 ★ ($count4)', 4),
                const SizedBox(width: 8),
                _buildCustomerFilterChip('3 ★ ($count3)', 3),
                const SizedBox(width: 8),
                _buildCustomerFilterChip('≤ 2 ★ ($count2OrLess)', 2),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Danh sách đánh giá thực tế từ MongoDB
        if (_isLoadingReviews) ...[
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: const Column(
              children: [
                CircularProgressIndicator(strokeWidth: 2.5),
                SizedBox(height: 12),
                Text('Đang tải phản hồi từ thực khách...', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ],
            ),
          ),
        ] else if (filteredReviews.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            alignment: Alignment.center,
            child: Column(
              children: [
                const Icon(Icons.star_border_rounded, size: 48, color: Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                const Text(
                  'Chưa có đánh giá nào phù hợp',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 4),
                Text(
                  _customerReviewRatingFilter == 0
                      ? 'Hãy là người đầu tiên trải nghiệm và chia sẻ cảm nhận!'
                      : 'Không có đánh giá $_customerReviewRatingFilter sao nào.',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ] else ...[
          ...filteredReviews.map((rev) => _buildRealReviewCard(rev)),
        ],
      ],
    );
  }

  Widget _buildCustomerFilterChip(String label, int ratingVal) {
    final isSelected = _customerReviewRatingFilter == ratingVal;
    return InkWell(
      onTap: () => setState(() => _customerReviewRatingFilter = ratingVal),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildRealReviewCard(ReviewModel rev) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFEFF6FF),
                backgroundImage: (rev.userAvatar.isNotEmpty && rev.userAvatar.startsWith('http'))
                    ? NetworkImage(rev.userAvatar)
                    : null,
                child: (rev.userAvatar.isEmpty || !rev.userAvatar.startsWith('http'))
                    ? Text(
                        rev.userName.isNotEmpty ? rev.userName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 14),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            rev.userName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (rev.isVerified) ...[
                          const SizedBox(width: 6),
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
                                Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 10),
                                SizedBox(width: 3),
                                Text('Đã dùng bữa', style: TextStyle(color: Color(0xFF059669), fontSize: 9.5, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < rev.rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: const Color(0xFFFBBF24),
                              size: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          rev.timeAgo,
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rev.content,
            style: const TextStyle(color: Color(0xFF334155), fontSize: 13, height: 1.45),
          ),
          if (rev.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: rev.images.map((img) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    img,
                    width: 72,
                    height: 72,
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

  void _showAddReviewModal(RestaurantModel r) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để gửi đánh giá cho quán.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    double selectedStars = 5;
    final commentCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Đánh giá ${r.name}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(modalCtx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Bạn cảm thấy quán như thế nào?', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  const SizedBox(height: 10),

                  // Bộ chọn sao
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (idx) {
                      final starValue = idx + 1;
                      return IconButton(
                        iconSize: 36,
                        icon: Icon(
                          starValue <= selectedStars ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: const Color(0xFFFBBF24),
                        ),
                        onPressed: () {
                          setModalState(() => selectedStars = starValue.toDouble());
                        },
                      );
                    }),
                  ),
                  Center(
                    child: Text(
                      selectedStars == 5
                          ? 'Cực kỳ tuyệt vời! (5/5)'
                          : selectedStars == 4
                              ? 'Rất tốt (4/5)'
                              : selectedStars == 3
                                  ? 'Bình thường (3/5)'
                                  : selectedStars == 2
                                      ? 'Chưa hài lòng (2/5)'
                                      : 'Rất tệ (1/5)',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2563EB), fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Ô nhập nhận xét
                  TextField(
                    controller: commentCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Mô tả hương vị món ăn, thái độ nhân viên, không gian quán...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 18),

                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final text = commentCtrl.text.trim();
                            if (text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Vui lòng nhập nội dung đánh giá của bạn.')),
                              );
                              return;
                            }

                            setModalState(() => isSubmitting = true);
                            final res = await _reviewService.createReview(
                              businessId: r.id,
                              rating: selectedStars,
                              content: text,
                            );

                            if (mounted) {
                              Navigator.pop(modalCtx);
                              if (res['success'] == true) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Gửi đánh giá thành công! Cảm ơn bạn đã đóng góp cho cộng đồng FConnect.'),
                                    backgroundColor: Color(0xFF10B981),
                                  ),
                                );
                                _loadReviews();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res['message'] ?? 'Không thể gửi đánh giá.'),
                                    backgroundColor: const Color(0xFFEF4444),
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Gửi Đánh Giá Ngay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Widget Thanh Sticky Bottom
  Widget _buildStickyBottomActionBar(RestaurantModel r) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Nút Chat với quán
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
            ),
            child: IconButton(
              icon: const Icon(Icons.forum_rounded, color: Color(0xFF0072FF), size: 20),
              tooltip: 'Chat với quán',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomerChatScreen(restaurant: r),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),

          // Nút gọi điện thoại
          Expanded(
            flex: 4,
            child: OutlinedButton.icon(
              onPressed: () => _makePhoneCall(r.phone),
              icon: const Icon(Icons.phone_outlined, size: 17),
              label: const Text('Gọi quán', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Nút đặt bàn ngay
          Expanded(
            flex: 6,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0072FF).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingScreen(restaurant: r),
                    ),
                  );
                },
                icon: const Icon(Icons.table_restaurant_rounded, size: 18),
                label: const Text('Đặt bàn ngay', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

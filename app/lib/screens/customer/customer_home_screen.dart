import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/restaurant_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/restaurant_service.dart';
import '../auth/login_screen.dart';
import '../auth/profile_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentTabIndex = 0;
  final RestaurantService _restaurantService = RestaurantService();
  final TextEditingController _searchController = TextEditingController();

  List<RestaurantModel> _restaurants = [];
  bool _isLoading = true;
  String _selectedCity = 'Đà Nẵng';
  String _selectedCategory = 'Tất cả';
  String _selectedVibe = '';
  String _selectedPurpose = '';
  bool _sortByAi = true;

  final List<String> _cities = [
    'Đà Nẵng',
    'Hội An',
    'Huế',
    'Hà Nội',
    'TP. Hồ Chí Minh',
  ];

  final List<Map<String, dynamic>> _categoryOptions = [
    {'name': 'Tất cả', 'icon': Icons.restaurant_rounded},
    {'name': 'Hải Sản', 'icon': Icons.set_meal_rounded},
    {'name': 'Nhà Hàng', 'icon': Icons.dinner_dining_rounded},
    {'name': 'Cà Phê', 'icon': Icons.coffee_rounded},
    {'name': 'Pizza & Mì Ý', 'icon': Icons.local_pizza_rounded},
    {'name': 'Đặc Sản', 'icon': Icons.ramen_dining_rounded},
    {'name': 'Buffet', 'icon': Icons.kebab_dining_rounded},
    {'name': 'Ăn Vặt', 'icon': Icons.fastfood_rounded},
  ];

  final List<String> _vibeOptions = [
    'Tất cả',
    'Ngoài trời',
    'Gần biển',
    'Lãng mạn',
    'Máy lạnh',
    'Nhóm đông',
    'Truyền thống',
  ];

  final List<String> _purposeOptions = [
    'Tất cả',
    'Gia đình',
    'Bạn bè',
    'Hẹn hò',
    'Tiếp khách',
    'Check-in',
  ];

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRestaurants() async {
    setState(() => _isLoading = true);
    final results = await _restaurantService.getRestaurants(
      city: _selectedCity,
      keyword: _searchController.text,
      category: _selectedCategory == 'Tất cả' ? null : _selectedCategory,
      vibe: _selectedVibe == 'Tất cả' || _selectedVibe.isEmpty ? null : _selectedVibe,
      purpose: _selectedPurpose == 'Tất cả' || _selectedPurpose.isEmpty ? null : _selectedPurpose,
    );

    if (_sortByAi) {
      results.sort((a, b) => (b.aiMatchScore ?? 0).compareTo(a.aiMatchScore ?? 0));
    }

    if (mounted) {
      setState(() {
        _restaurants = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: IndexedStack(
          index: _currentTabIndex,
          children: [
            // Tab 0: Trang chủ
            _buildHomeTab(authProvider, user),
            // Tab 1: Bài viết
            _buildArticlesTab(),
            // Tab 2: Bản đồ
            _buildMapTab(),
            // Tab 3: AI Gợi ý
            _buildAiAssistantTab(),
            // Tab 4: Cá nhân
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // ==========================================
  // TAB 0: TRANG CHỦ FEED
  // ==========================================
  Widget _buildHomeTab(AuthProvider authProvider, User? user) {
    return RefreshIndicator(
      onRefresh: _loadRestaurants,
      color: const Color(0xFF0072FF),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          // 1. Header cố định ở trên
          SliverToBoxAdapter(
            child: _buildTopHeader(authProvider, user),
          ),

          // 2. Banner chính FConnect Food Familiar Fast
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: _buildBannerCard(),
            ),
          ),

          // 3. Thanh bộ lọc danh mục và thuộc tính (Horizontal Scroll)
          SliverToBoxAdapter(
            child: _buildFilterChipsSection(),
          ),

          // 4. Tiêu đề Khám phá & Gợi ý AI
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: Color(0xFF0072FF), size: 24),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Khám Phá Tất Cả Quán Ăn tại $_selectedCity',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Xếp theo thứ tự gợi ý của AI cao hơn đứng trước & phù hợp với bạn nhất',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 5. Danh sách các Quán ăn
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40.0),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: Color(0xFF0072FF), strokeWidth: 2.5),
                      SizedBox(height: 12),
                      Text(
                        'Đang tải danh sách quán ăn tại Đà Nẵng...',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_restaurants.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 50.0, horizontal: 20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded, size: 56, color: Color(0xFFCBD5E1)),
                      const SizedBox(height: 12),
                      const Text(
                        'Không tìm thấy quán ăn phù hợp',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Thử tìm với từ khóa khác hoặc xóa bớt bộ lọc',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _selectedCategory = 'Tất cả';
                            _selectedVibe = '';
                            _selectedPurpose = '';
                          });
                          _loadRestaurants();
                        },
                        child: const Text('Xem tất cả quán ăn'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final restaurant = _restaurants[index];
                    return _buildRestaurantCard(restaurant);
                  },
                  childCount: _restaurants.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // 1. TOP HEADER (LOGO, ĐÀ NẴNG, SEARCH, USER AVATAR / ĐĂNG NHẬP)
  // ==========================================
  Widget _buildTopHeader(AuthProvider authProvider, User? user) {
    final isLoggedIn = authProvider.isAuthenticated || user != null;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      child: Row(
        children: [
          // A. Logo tròn FConnect
          GestureDetector(
            onTap: () {
              setState(() {
                _currentTabIndex = 0;
              });
            },
            child: Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0072FF).withValues(alpha: 0.08),
                border: Border.all(color: const Color(0xFF0072FF).withValues(alpha: 0.25), width: 1.2),
              ),
              child: ClipOval(
                child: Image.asset(
                  'public/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.restaurant_menu_rounded,
                    color: Color(0xFF0072FF),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // B. Nút chọn địa điểm (Dropdown Đà Nẵng)
          GestureDetector(
            onTap: _showCityPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_outlined, color: Color(0xFF0072FF), size: 16),
                  const SizedBox(width: 3),
                  Text(
                    _selectedCity,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // C. Ô tìm kiếm quán, món
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _loadRestaurants(),
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Tìm quán, món...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 18),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                          onPressed: () {
                            _searchController.clear();
                            _loadRestaurants();
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // D. Phần hiển thị SAU KHI LOGIN (Avatar User / Hoặc Nút Đăng Nhập nếu chưa đăng nhập)
          if (isLoggedIn)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0072FF), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0072FF).withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF0072FF),
                  backgroundImage: (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: (user?.avatarUrl == null || user!.avatarUrl!.isEmpty)
                      ? Text(
                          (user?.fullName.isNotEmpty == true ? user!.fullName[0] : 'U').toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        )
                      : null,
                ),
              ),
            )
          else
            // Nút Đăng nhập cho khách
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              icon: const Icon(Icons.person, size: 16, color: Colors.white),
              label: const Text(
                'Đăng nhập',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0072FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. BANNER CARD (public/banner.png)
  // ==========================================
  Widget _buildBannerCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0072FF).withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 2.65,
          child: Image.asset(
            'public/banner.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0052D4), Color(0xFF4364F7), Color(0xFF6FB1FC)],
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FConnect F&B Platform',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'FOOD • FAMILIAR • FAST • Khám phá ẩm thực thông minh',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 3. FILTER CHIPS SECTION (DANH MỤC, KHÔNG GIAN, MỤC ĐÍCH, AI GỢI Ý)
  // ==========================================
  Widget _buildFilterChipsSection() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Chip Danh mục
          _buildFilterDropdownChip(
            label: _selectedCategory == 'Tất cả' ? 'Danh mục' : _selectedCategory,
            icon: Icons.category_outlined,
            isSelected: _selectedCategory != 'Tất cả',
            onTap: _showCategoryBottomSheet,
          ),
          const SizedBox(width: 8),

          // Chip Không gian
          _buildFilterDropdownChip(
            label: _selectedVibe.isEmpty || _selectedVibe == 'Tất cả' ? '🌿 Không gian' : '🌿 $_selectedVibe',
            icon: Icons.park_outlined,
            isSelected: _selectedVibe.isNotEmpty && _selectedVibe != 'Tất cả',
            onTap: _showVibeBottomSheet,
          ),
          const SizedBox(width: 8),

          // Chip Mục đích
          _buildFilterDropdownChip(
            label: _selectedPurpose.isEmpty || _selectedPurpose == 'Tất cả' ? '🎯 Mục đích' : '🎯 $_selectedPurpose',
            icon: Icons.flag_outlined,
            isSelected: _selectedPurpose.isNotEmpty && _selectedPurpose != 'Tất cả',
            onTap: _showPurposeBottomSheet,
          ),
          const SizedBox(width: 8),

          // Chip AI Gợi ý
          GestureDetector(
            onTap: () {
              setState(() {
                _sortByAi = !_sortByAi;
              });
              _loadRestaurants();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _sortByAi ? const Color(0xFFEFF6FF) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _sortByAi ? const Color(0xFF0072FF) : const Color(0xFFE2E8F0),
                  width: _sortByAi ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 15, color: _sortByAi ? const Color(0xFF0072FF) : const Color(0xFFF59E0B)),
                  const SizedBox(width: 5),
                  Text(
                    'AI Gợi ý',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: _sortByAi ? FontWeight.w700 : FontWeight.w500,
                      color: _sortByAi ? const Color(0xFF0072FF) : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdownChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0072FF) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF0072FF) : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isSelected ? const Color(0xFF0072FF) : const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 4. RESTAURANT CARD COMPONENT
  // ==========================================
  Widget _buildRestaurantCard(RestaurantModel r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A. Ảnh bìa nhà hàng kèm Badge
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    r.coverImageUrl ?? 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=800&q=80',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFE2E8F0),
                      child: const Center(
                        child: Icon(Icons.restaurant, color: Color(0xFF94A3B8), size: 40),
                      ),
                    ),
                  ),
                ),
              ),

              // Huy hiệu AI Match bên góc phải
              if (r.aiMatchScore != null)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0072FF), Color(0xFF00C6FF)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${r.aiMatchScore!.toStringAsFixed(0)}% Phù hợp',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

              // Huy hiệu danh mục chính góc trái
              if (r.categories.isNotEmpty)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      r.categories.first,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),

          // B. Nội dung chi tiết quán ăn
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tên quán
                Text(
                  r.name,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Đánh giá sao & Google reviews
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 15),
                          const SizedBox(width: 3),
                          Text(
                            r.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Color(0xFFB45309),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${r.totalReviews} đánh giá)',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    if (r.googleRating != null) ...[
                      const Text(' • ', style: TextStyle(color: Color(0xFFCBD5E1))),
                      const Icon(Icons.g_mobiledata_rounded, color: Color(0xFF4285F4), size: 18),
                      Text(
                        '${r.googleRating} ★ (${r.googleTotalReviews ?? 0}+)',
                        style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),

                // Địa chỉ
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        r.address,
                        style: const TextStyle(color: Color(0xFF475569), fontSize: 12.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Khoảng giá & Tags
                Row(
                  children: [
                    const Icon(Icons.monetization_on_outlined, size: 15, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      r.formattedPrice,
                      style: const TextStyle(color: Color(0xFF047857), fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    if (r.vibes.isNotEmpty)
                      Expanded(
                        child: Text(
                          '• ${r.vibes.take(2).join(', ')}',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Nút hành động Đặt bàn & Xem thực đơn
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showRestaurantDetailsModal(r),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0072FF),
                          side: const BorderSide(color: Color(0xFF0072FF), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                        ),
                        child: const Text('Xem menu & chi tiết', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showBookingModal(r),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0072FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.table_restaurant_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Đặt bàn ngay', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
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

  // ==========================================
  // MODAL ĐẶT BÀN NHANH (QUICK BOOKING)
  // ==========================================
  void _showBookingModal(RestaurantModel r) {
    int guestCount = 2;
    String selectedTime = '19:00';
    final List<String> times = ['11:30', '12:00', '12:30', '18:00', '18:30', '19:00', '19:30', '20:00'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.table_restaurant_rounded, color: Color(0xFF0072FF), size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đặt bàn tại ${r.name}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '📍 ${r.address}',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                ),
                const SizedBox(height: 18),

                // Số lượng khách
                const Text('Số lượng khách:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 8),
                Row(
                  children: [1, 2, 4, 6, 8, 10].map((guestNum) {
                    final isSel = guestCount == guestNum;
                    return GestureDetector(
                      onTap: () => setModalState(() => guestCount = guestNum),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF0072FF) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$guestNum người',
                          style: TextStyle(
                            color: isSel ? Colors.white : const Color(0xFF334155),
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Khung giờ đặt
                const Text('Khung giờ:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: times.map((t) {
                    final isSel = selectedTime == t;
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedTime = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF0072FF) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            color: isSel ? Colors.white : const Color(0xFF334155),
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),

                // Nút Xác nhận đặt bàn
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF10B981),
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Đặt bàn thành công lúc $selectedTime ($guestCount khách) tại ${r.name}!'),
                              ),
                            ],
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0072FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Xác nhận đặt bàn', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Modal Chi tiết quán ăn
  void _showRestaurantDetailsModal(RestaurantModel r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(r.coverImageUrl ?? ''),
                  fit: BoxFit.cover,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: ListView(
                  children: [
                    Text(r.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('📍 ${r.address}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    const SizedBox(height: 12),
                    Text(r.description, style: const TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF334155))),
                    const SizedBox(height: 16),
                    const Text('Không gian & Phù hợp:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [...r.vibes, ...r.purposes].map((tag) => Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 11)),
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // BOTTOM SHEETS BỘ LỌC
  // ==========================================
  void _showCityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Chọn Thành Phố', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ..._cities.map((c) => ListTile(
              title: Text(c, style: TextStyle(fontWeight: _selectedCity == c ? FontWeight.bold : FontWeight.normal)),
              trailing: _selectedCity == c ? const Icon(Icons.check, color: Color(0xFF0072FF)) : null,
              onTap: () {
                setState(() => _selectedCity = c);
                Navigator.pop(context);
                _loadRestaurants();
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showCategoryBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Chọn Danh Mục Ẩm Thực', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Expanded(
              child: ListView(
                children: _categoryOptions.map((cat) {
                  final name = cat['name'] as String;
                  final icon = cat['icon'] as IconData;
                  final isSel = _selectedCategory == name;
                  return ListTile(
                    leading: Icon(icon, color: isSel ? const Color(0xFF0072FF) : const Color(0xFF64748B)),
                    title: Text(name, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                    trailing: isSel ? const Icon(Icons.check, color: Color(0xFF0072FF)) : null,
                    onTap: () {
                      setState(() => _selectedCategory = name);
                      Navigator.pop(context);
                      _loadRestaurants();
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

  void _showVibeBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('🌿 Chọn Không Gian Quán', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ..._vibeOptions.map((v) => ListTile(
              title: Text(v, style: TextStyle(fontWeight: _selectedVibe == v ? FontWeight.bold : FontWeight.normal)),
              trailing: _selectedVibe == v ? const Icon(Icons.check, color: Color(0xFF0072FF)) : null,
              onTap: () {
                setState(() => _selectedVibe = v);
                Navigator.pop(context);
                _loadRestaurants();
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showPurposeBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('🎯 Chọn Mục Đích Bữa Ăn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ..._purposeOptions.map((p) => ListTile(
              title: Text(p, style: TextStyle(fontWeight: _selectedPurpose == p ? FontWeight.bold : FontWeight.normal)),
              trailing: _selectedPurpose == p ? const Icon(Icons.check, color: Color(0xFF0072FF)) : null,
              onTap: () {
                setState(() => _selectedPurpose = p);
                Navigator.pop(context);
                _loadRestaurants();
              },
            )),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: BÀI VIẾT (FOOD BLOG & REVIEW)
  // ==========================================
  Widget _buildArticlesTab() {
    final List<Map<String, String>> articles = [
      {
        'title': 'Top 10 Quán Hải Sản Tươi Sống Ngon Nức Tiếng Bờ Biển Mỹ Khê Đà Nẵng',
        'author': 'FConnect Food Critic',
        'date': 'Hôm nay',
        'image': 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=600&q=80',
        'readTime': '4 phút đọc',
      },
      {
        'title': 'Bí Quyết Nấu Mì Quảng Ếch Chuẩn Vị Xứ Quảng Của Các Đầu Bếp Lão Làng',
        'author': 'Master Chef FConnect',
        'date': 'Hôm qua',
        'image': 'https://images.unsplash.com/photo-1569058242253-92a9c755a0ec?auto=format&fit=crop&w=600&q=80',
        'readTime': '6 phút đọc',
      },
      {
        'title': 'Khám Phá Các Quán Cà Phê View Ngắm Trọn Sông Hàn & Cầu Rồng Lung Linh',
        'author': 'Reviewer Đà Nẵng',
        'date': '2 ngày trước',
        'image': 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=600&q=80',
        'readTime': '3 phút đọc',
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '📖 Bài Viết & Cẩm Nang Ẩm Thực',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        const Text('Cập nhật xu hướng ẩm thực, ưu đãi và đánh giá chuyên sâu', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        const SizedBox(height: 16),
        ...articles.map((art) => Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(art['image']!, height: 160, width: double.infinity, fit: BoxFit.cover),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(art['title']!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('✍️ ${art['author']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        const Spacer(),
                        Text(art['readTime']!, style: const TextStyle(fontSize: 12, color: Color(0xFF0072FF), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  // ==========================================
  // TAB 2: BẢN ĐỒ (FOOD MAP)
  // ==========================================
  Widget _buildMapTab() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0072FF).withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.map_rounded, size: 44, color: Color(0xFF0072FF)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bản Đồ Ẩm Thực Đà Nẵng',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Định vị các nhà hàng, quán ăn quanh bạn trên bản đồ với chỉ dẫn đường đi tối ưu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _currentTabIndex = 0);
              },
              icon: const Icon(Icons.explore_rounded),
              label: const Text('Xem danh sách quán ăn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0072FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: AI GỢI Ý (AI SOMMELIER)
  // ==========================================
  Widget _buildAiAssistantTab() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF0072FF)]),
              ),
              child: const Icon(Icons.auto_awesome, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Trợ Lý Ẩm Thực Thông Minh FConnect',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'AI Sommelier & Food Critic phân tích sở thích khẩu vị, ngân sách và thời tiết để đề xuất món ngon hoàn hảo nhất cho bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _sortByAi = true;
                  _currentTabIndex = 0;
                });
                _loadRestaurants();
              },
              icon: const Icon(Icons.auto_awesome, color: Colors.white),
              label: const Text('Xem danh sách AI đề xuất ngay', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0072FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 5. BOTTOM NAVIGATION BAR (5 TABS CHUẨN UI)
  // ==========================================
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF0072FF),
        unselectedItemColor: const Color(0xFF64748B),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_fire_department_rounded, size: 22),
            activeIcon: Icon(Icons.local_fire_department_rounded, size: 24, color: Color(0xFF0072FF)),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_rounded, size: 21),
            activeIcon: Icon(Icons.menu_book_rounded, size: 23, color: Color(0xFF0072FF)),
            label: 'Bài viết',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on_outlined, size: 22),
            activeIcon: Icon(Icons.location_on, size: 24, color: Color(0xFF0072FF)),
            label: 'Bản đồ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_outlined, size: 22),
            activeIcon: Icon(Icons.auto_awesome, size: 24, color: Color(0xFF0072FF)),
            label: 'AI gợi ý',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded, size: 22),
            activeIcon: Icon(Icons.person_rounded, size: 24, color: Color(0xFF0072FF)),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }
}

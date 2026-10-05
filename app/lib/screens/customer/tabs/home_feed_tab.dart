import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/restaurant_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../auth/login_screen.dart';
import '../../auth/profile_screen.dart';
import '../widgets/restaurant_modals.dart';

class HomeFeedTab extends StatelessWidget {
  final List<RestaurantModel> restaurants;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final String selectedCity;
  final Function(String) onCityChanged;
  final String selectedCategory;
  final Function(String) onCategoryChanged;
  final String selectedVibe;
  final Function(String) onVibeChanged;
  final String selectedPurpose;
  final Function(String) onPurposeChanged;
  final bool sortByAi;
  final VoidCallback onToggleSortByAi;
  final TextEditingController searchController;
  final VoidCallback onSearch;
  final VoidCallback onResetFilters;
  final Function(RestaurantModel)? onShowBooking;
  final Function(RestaurantModel)? onShowDetails;

  const HomeFeedTab({
    super.key,
    required this.restaurants,
    required this.isLoading,
    required this.onRefresh,
    required this.selectedCity,
    required this.onCityChanged,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.selectedVibe,
    required this.onVibeChanged,
    required this.selectedPurpose,
    required this.onPurposeChanged,
    required this.sortByAi,
    required this.onToggleSortByAi,
    required this.searchController,
    required this.onSearch,
    required this.onResetFilters,
    this.onShowBooking,
    this.onShowDetails,
  });

  static const List<String> cities = [
    'Đà Nẵng',
    'Hội An',
    'Huế',
    'Hà Nội',
    'TP. Hồ Chí Minh',
  ];

  static const List<Map<String, dynamic>> categoryOptions = [
    {'name': 'Tất cả', 'icon': Icons.restaurant_rounded},
    {'name': 'Hải Sản', 'icon': Icons.set_meal_rounded},
    {'name': 'Nhà Hàng', 'icon': Icons.dinner_dining_rounded},
    {'name': 'Cà Phê', 'icon': Icons.coffee_rounded},
    {'name': 'Lẩu Nướng BBQ', 'icon': Icons.outdoor_grill_rounded},
    {'name': 'Buffet', 'icon': Icons.kebab_dining_rounded},
    {'name': 'Trà Sữa', 'icon': Icons.local_drink_rounded},
    {'name': 'Tiệm Bánh', 'icon': Icons.cake_rounded},
    {'name': 'Chè & Tráng Miệng', 'icon': Icons.icecream_rounded},
  ];

  static const List<String> vibeOptions = [
    'Tất cả',
    'Ngoài trời / Sân vườn',
    'Hiện đại / Sang trọng',
    'Lãng mạn / Hẹn hò',
    'Cổ điển / Vintage',
    'Rooftop / View trên cao',
    'Check-in sống ảo',
  ];

  static const List<String> purposeOptions = [
    'Tất cả',
    'Bữa ăn gia đình',
    'Gặp gỡ bạn bè',
    'Hẹn hò cặp đôi',
    'Tiếp khách / Đối tác',
    'Sinh nhật / Tiệc',
    'Thư giãn cuối tuần',
  ];

  void _showCityPicker(BuildContext context) {
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
              child: Text(
                '📍 Chọn Tỉnh / Thành Phố',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ...cities.map((city) => ListTile(
              title: Text(
                city,
                style: TextStyle(
                  fontWeight: selectedCity == city ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: selectedCity == city ? const Icon(Icons.check, color: Color(0xFF0072FF)) : null,
              onTap: () {
                Navigator.pop(context);
                onCityChanged(city);
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showCategoryBottomSheet(BuildContext context) {
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
              child: Text('📂 Chọn Danh Mục Ẩm Thực', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ...categoryOptions.map((cat) {
              final name = cat['name'] as String;
              final icon = cat['icon'] as IconData;
              return ListTile(
                leading: Icon(icon, color: selectedCategory == name ? const Color(0xFF0072FF) : Colors.grey),
                title: Text(
                  name,
                  style: TextStyle(fontWeight: selectedCategory == name ? FontWeight.bold : FontWeight.normal),
                ),
                trailing: selectedCategory == name ? const Icon(Icons.check, color: Color(0xFF0072FF)) : null,
                onTap: () {
                  Navigator.pop(context);
                  onCategoryChanged(name);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showVibeBottomSheet(BuildContext context) {
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
            ...vibeOptions.map((v) => ListTile(
              title: Text(v, style: TextStyle(fontWeight: selectedVibe == v ? FontWeight.bold : FontWeight.normal)),
              trailing: selectedVibe == v ? const Icon(Icons.check, color: Color(0xFF0072FF)) : null,
              onTap: () {
                Navigator.pop(context);
                onVibeChanged(v);
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showPurposeBottomSheet(BuildContext context) {
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
            ...purposeOptions.map((p) => ListTile(
              title: Text(p, style: TextStyle(fontWeight: selectedPurpose == p ? FontWeight.bold : FontWeight.normal)),
              trailing: selectedPurpose == p ? const Icon(Icons.check, color: Color(0xFF0072FF)) : null,
              onTap: () {
                Navigator.pop(context);
                onPurposeChanged(p);
              },
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFF0072FF),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          // 1. Header cố định ở trên
          SliverToBoxAdapter(
            child: _buildTopHeader(context, authProvider, user),
          ),

          // 2. Banner chính FConnect
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: _buildBannerCard(),
            ),
          ),

          // 3. Thanh bộ lọc danh mục và thuộc tính
          SliverToBoxAdapter(
            child: _buildFilterChipsSection(context),
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
                          'Khám Phá Tất Cả Quán Ăn tại $selectedCity',
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
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 14),
                      SizedBox(width: 4),
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
          if (isLoading)
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
          else if (restaurants.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 50.0, horizontal: 20),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.search_off_rounded, size: 56, color: Color(0xFFCBD5E1)),
                      const SizedBox(height: 12),
                      const Text(
                        'Không tìm thấy quán ăn phù hợp',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Thử tìm với từ khóa khác hoặc xóa bớt bộ lọc',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: onResetFilters,
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
                    final restaurant = restaurants[index];
                    return _buildRestaurantCard(context, restaurant);
                  },
                  childCount: restaurants.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context, AuthProvider authProvider, User? user) {
    final isLoggedIn = authProvider.isAuthenticated || user != null;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      child: Row(
        children: [
          // Logo tròn FConnect
          Container(
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
          const SizedBox(width: 8),

          // Nút chọn địa điểm (Dropdown Đà Nẵng)
          GestureDetector(
            onTap: () => _showCityPicker(context),
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
                    selectedCity,
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

          // Ô tìm kiếm quán, món
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => onSearch(),
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Tìm quán, món...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 18),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                          onPressed: () {
                            searchController.clear();
                            onSearch();
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

          // User Avatar / Nút Đăng nhập
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

  Widget _buildFilterChipsSection(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Chip Danh mục
          _buildFilterDropdownChip(
            label: selectedCategory == 'Tất cả' ? 'Danh mục' : selectedCategory,
            icon: Icons.category_outlined,
            isSelected: selectedCategory != 'Tất cả',
            onTap: () => _showCategoryBottomSheet(context),
          ),
          const SizedBox(width: 8),

          // Chip Không gian
          _buildFilterDropdownChip(
            label: selectedVibe.isEmpty || selectedVibe == 'Tất cả' ? '🌿 Không gian' : '🌿 $selectedVibe',
            icon: Icons.park_outlined,
            isSelected: selectedVibe.isNotEmpty && selectedVibe != 'Tất cả',
            onTap: () => _showVibeBottomSheet(context),
          ),
          const SizedBox(width: 8),

          // Chip Mục đích
          _buildFilterDropdownChip(
            label: selectedPurpose.isEmpty || selectedPurpose == 'Tất cả' ? '🎯 Mục đích' : '🎯 $selectedPurpose',
            icon: Icons.flag_outlined,
            isSelected: selectedPurpose.isNotEmpty && selectedPurpose != 'Tất cả',
            onTap: () => _showPurposeBottomSheet(context),
          ),
          const SizedBox(width: 8),

          // Chip AI Gợi ý
          GestureDetector(
            onTap: onToggleSortByAi,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sortByAi ? const Color(0xFFEFF6FF) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sortByAi ? const Color(0xFF0072FF) : const Color(0xFFE2E8F0),
                  width: sortByAi ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 15,
                    color: sortByAi ? const Color(0xFF0072FF) : const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'AI Gợi ý',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: sortByAi ? FontWeight.w700 : FontWeight.w500,
                      color: sortByAi ? const Color(0xFF0072FF) : const Color(0xFF334155),
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

  Widget _buildRestaurantCard(BuildContext context, RestaurantModel r) {
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
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Image.network(
                    r.coverImageUrl ??
                        r.logoUrl ??
                        'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=800&q=80',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFFEFF6FF),
                        child: const Center(
                          child: Icon(Icons.restaurant_rounded, size: 50, color: Color(0xFF0072FF)),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // AI Match Score Badge (Góc trên trái)
              if (r.aiMatchScore != null && r.aiMatchScore! > 0)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF38BDF8), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, color: Color(0xFF38BDF8), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${r.aiMatchScore!.toStringAsFixed(0)}% phù hợp',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Rating Google Maps Badge (Góc trên phải)
              if (r.googleRating != null && r.googleRating! > 0)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 16),
                        const SizedBox(width: 3),
                        Text(
                          r.googleRating!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (r.googleTotalReviews != null) ...[
                          const SizedBox(width: 2),
                          Text(
                            '(${r.googleTotalReviews})',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // Category tag (Góc dưới trái ảnh bìa)
              Positioned(
                bottom: 10,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0072FF).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    r.displayCategory,
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
                if (r.recommendationReason != null && r.recommendationReason!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      r.recommendationReason!,
                      style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 11, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 8),

                // Rating FConnect
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                    const SizedBox(width: 3),
                    Text(
                      r.rating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${r.totalReviews} đánh giá FConnect)',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
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
                        (r.distanceText != null && r.distanceText!.isNotEmpty)
                            ? '${r.distanceText} • ${r.address}'
                            : r.address,
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
                        onPressed: () {
                          if (onShowDetails != null) {
                            onShowDetails!(r);
                          } else {
                            RestaurantModals.showDetails(context, r);
                          }
                        },
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
                        onPressed: () {
                          if (onShowBooking != null) {
                            onShowBooking!(r);
                          } else {
                            RestaurantModals.showBooking(context, r);
                          }
                        },
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
}

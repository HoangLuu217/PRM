import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/restaurant_model.dart';
import '../../providers/favorite_provider.dart';
import 'restaurant_detail_screen.dart';
import 'widgets/restaurant_modals.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Tất cả';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FavoriteProvider>().loadFavorites();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favProvider = context.watch<FavoriteProvider>();
    final allFavorites = favProvider.favorites;

    // Lọc theo từ khóa tìm kiếm & danh mục
    final filtered = allFavorites.where((r) {
      final matchesSearch = _searchController.text.trim().isEmpty ||
          r.name.toLowerCase().contains(_searchController.text.toLowerCase().trim()) ||
          r.address.toLowerCase().contains(_searchController.text.toLowerCase().trim());

      final matchesCategory = _selectedCategory == 'Tất cả' ||
          r.displayCategory == _selectedCategory ||
          r.categories.contains(_selectedCategory);

      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text(
              'Quán yêu thích',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                '${favProvider.count}',
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      body: favProvider.isLoading && !favProvider.isInitialLoaded
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0072FF)),
            )
          : RefreshIndicator(
              color: const Color(0xFF0072FF),
              onRefresh: () => favProvider.loadFavorites(force: true),
              child: Column(
                children: [
                  // 1. Ô tìm kiếm trong danh sách yêu thích
                  _buildSearchBar(),

                  // 2. Nội dung danh sách hoặc trạng thái trống
                  Expanded(
                    child: allFavorites.isEmpty
                        ? _buildEmptyState(context)
                        : filtered.isEmpty
                            ? _buildNoResultsState()
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final restaurant = filtered[index];
                                  return _buildFavoriteItemCard(context, restaurant, favProvider);
                                },
                              ),
                  ),
                ],
              ),
            ),
    );
  }

  // ==========================================
  // Ô TÌM KIẾM
  // ==========================================
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: 'Tìm kiếm quán đã lưu...',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // CARD QUÁN ĂN YÊU THÍCH
  // ==========================================
  Widget _buildFavoriteItemCard(
    BuildContext context,
    RestaurantModel restaurant,
    FavoriteProvider favProvider,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A. Ảnh bìa kèm nút Heart & Tags
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: AspectRatio(
                      aspectRatio: 2.3,
                      child: restaurant.coverImageUrl != null && restaurant.coverImageUrl!.isNotEmpty
                          ? Image.network(
                              restaurant.coverImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
                            )
                          : _buildPlaceholderImage(),
                    ),
                  ),

                  // Nút bỏ yêu thích (Trái tim đỏ góc trên phải)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.favorite_rounded, color: Color(0xFFEF4444), size: 20),
                        tooltip: 'Bỏ yêu thích',
                        onPressed: () => _confirmRemoveFavorite(context, restaurant, favProvider),
                      ),
                    ),
                  ),

                  // Tag danh mục (Góc dưới trái)
                  Positioned(
                    bottom: 10,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0072FF).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        restaurant.displayCategory,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // Đánh giá Google Maps (Góc trên trái)
                  if (restaurant.googleRating != null && restaurant.googleRating! > 0)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 15),
                            const SizedBox(width: 2),
                            Text(
                              restaurant.googleRating!.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // B. Thông tin chi tiết
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Địa chỉ
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            restaurant.address,
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Giá & Giờ mở cửa
                    Row(
                      children: [
                        const Icon(Icons.monetization_on_outlined, size: 14, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(
                          restaurant.formattedPrice,
                          style: const TextStyle(color: Color(0xFF047857), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        if (restaurant.openTime != null && restaurant.closeTime != null) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            '${restaurant.openTime} - ${restaurant.closeTime}',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),

                    // C. Nút hành động Đặt bàn & Xem chi tiết
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0072FF),
                              side: const BorderSide(color: Color(0xFF0072FF), width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('Xem menu & chi tiết', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => RestaurantModals.showBooking(context, restaurant),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0072FF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.table_restaurant_rounded, size: 15),
                                SizedBox(width: 4),
                                Text('Đặt bàn ngay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
        ),
      ),
    );
  }

  // Placeholder ảnh khi không có coverImageUrl
  Widget _buildPlaceholderImage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.restaurant_rounded, color: Colors.white54, size: 40),
      ),
    );
  }

  // Xác nhận bỏ yêu thích
  void _confirmRemoveFavorite(BuildContext context, RestaurantModel r, FavoriteProvider favProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bỏ quán yêu thích?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Bạn có chắc muốn xóa "${r.name}" khỏi danh sách yêu thích không?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              favProvider.removeFavorite(r.id, context: context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Bỏ yêu thích'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // EMPTY STATE (CHƯA CÓ QUÁN YÊU THÍCH)
  // ==========================================
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.favorite_border_rounded, size: 42, color: Color(0xFFF43F5E)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chưa có quán yêu thích nào',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Lưu lại những quán ăn, quán cà phê bạn ấn tượng nhất để dễ dàng đặt bàn và ghé lại bất kỳ lúc nào!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: const Text('Khám phá quán ngon ngay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0072FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // KHÔNG TÌM THẤY KẾT QUẢ TÌM KIẾM
  // ==========================================
  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 56, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text(
              'Không tìm thấy quán nào',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Thử tìm với từ khóa khác trong danh sách yêu thích của bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _selectedCategory = 'Tất cả');
              },
              child: const Text('Xóa bộ lọc'),
            ),
          ],
        ),
      ),
    );
  }
}

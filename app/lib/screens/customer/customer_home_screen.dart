import 'package:flutter/material.dart';
import '../../models/restaurant_model.dart';
import '../../services/location_service.dart';
import '../../services/restaurant_service.dart';
import '../auth/profile_screen.dart';
import 'tabs/ai_sommelier_tab.dart';
import 'tabs/articles_tab.dart';
import 'tabs/food_map_tab.dart';
import 'tabs/home_feed_tab.dart';
import 'widgets/restaurant_modals.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentTabIndex = 0;
  final RestaurantService _restaurantService = RestaurantService();
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();

  List<RestaurantModel> _restaurants = [];
  bool _isLoading = true;
  String _selectedCity = 'Đà Nẵng';
  String _selectedCategory = 'Tất cả';
  String _selectedVibe = '';
  String _selectedPurpose = '';
  bool _sortByAi = true;

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
    // Thử lấy vị trí GPS hiện tại của người dùng (nếu đã cấp quyền)
    final loc = await _locationService.getCurrentLocation(requestIfNeeded: false);
    final results = await _restaurantService.getRestaurants(
      city: _selectedCity,
      keyword: _searchController.text,
      category: _selectedCategory == 'Tất cả' ? null : _selectedCategory,
      vibe: _selectedVibe == 'Tất cả' || _selectedVibe.isEmpty ? null : _selectedVibe,
      purpose: _selectedPurpose == 'Tất cả' || _selectedPurpose.isEmpty ? null : _selectedPurpose,
      lat: loc?.latitude,
      lng: loc?.longitude,
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

  void _onResetFilters() {
    _searchController.clear();
    setState(() {
      _selectedCategory = 'Tất cả';
      _selectedVibe = '';
      _selectedPurpose = '';
    });
    _loadRestaurants();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: IndexedStack(
          index: _currentTabIndex,
          children: [
            // Tab 0: Trang chủ Feed
            HomeFeedTab(
              restaurants: _restaurants,
              isLoading: _isLoading,
              onRefresh: _loadRestaurants,
              selectedCity: _selectedCity,
              onCityChanged: (city) {
                setState(() => _selectedCity = city);
                _loadRestaurants();
              },
              selectedCategory: _selectedCategory,
              onCategoryChanged: (cat) {
                setState(() => _selectedCategory = cat);
                _loadRestaurants();
              },
              selectedVibe: _selectedVibe,
              onVibeChanged: (vibe) {
                setState(() => _selectedVibe = vibe);
                _loadRestaurants();
              },
              selectedPurpose: _selectedPurpose,
              onPurposeChanged: (purpose) {
                setState(() => _selectedPurpose = purpose);
                _loadRestaurants();
              },
              sortByAi: _sortByAi,
              onToggleSortByAi: () {
                setState(() => _sortByAi = !_sortByAi);
                _loadRestaurants();
              },
              searchController: _searchController,
              onSearch: _loadRestaurants,
              onResetFilters: _onResetFilters,
              onShowBooking: (r) => RestaurantModals.showBooking(context, r, restaurantService: _restaurantService),
              onShowDetails: (r) => RestaurantModals.showDetails(context, r),
            ),

            // Tab 1: Bài viết ẩm thực
            const ArticlesTab(),

            // Tab 2: Bản đồ ẩm thực (OpenStreetMap & Satellite)
            FoodMapTab(
              restaurants: _restaurants,
              onShowBooking: (r) => RestaurantModals.showBooking(context, r, restaurantService: _restaurantService),
              onShowDetails: (r) => RestaurantModals.showDetails(context, r),
            ),

            // Tab 3: Trợ lý AI gợi ý
            AiSommelierTab(
              onExploreRecommendations: () {
                setState(() {
                  _sortByAi = true;
                  _currentTabIndex = 0;
                });
                _loadRestaurants();
              },
            ),

            // Tab 4: Cá nhân (Profile)
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // ==========================================
  // BOTTOM NAVIGATION BAR (5 TABS CHUẨN UI)
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

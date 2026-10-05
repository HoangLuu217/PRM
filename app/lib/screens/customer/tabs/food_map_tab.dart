import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/restaurant_model.dart';
import '../../../services/location_service.dart';
import '../widgets/restaurant_modals.dart';

class FoodMapTab extends StatefulWidget {
  final List<RestaurantModel> restaurants;
  final Function(RestaurantModel)? onShowBooking;
  final Function(RestaurantModel)? onShowDetails;

  const FoodMapTab({
    super.key,
    required this.restaurants,
    this.onShowBooking,
    this.onShowDetails,
  });

  @override
  State<FoodMapTab> createState() => _FoodMapTabState();
}

class _FoodMapTabState extends State<FoodMapTab> {
  final MapController _osmMapController = MapController();
  final TextEditingController _mapSearchController = TextEditingController();
  final LocationService _locationService = LocationService();

  RestaurantModel? _selectedMapRestaurant;
  String _mapCategoryFilter = 'Tất cả';
  bool _isSatelliteMode = false;
  LatLng? _myCurrentLocation;
  bool _isLocating = false;
  double _currentRotation = 0.0;
  static const LatLng _daNangCenter = LatLng(16.0544, 108.2022);

  @override
  void initState() {
    super.initState();
    // Tự động kiểm tra và lấy vị trí GPS hiện tại khi mở màn hình Bản đồ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _determineMyCurrentLocation(moveCamera: false);
    });
  }

  @override
  void dispose() {
    _mapSearchController.dispose();
    _osmMapController.dispose();
    super.dispose();
  }

  Future<void> _determineMyCurrentLocation({bool moveCamera = false}) async {
    setState(() => _isLocating = true);
    final pos = await _locationService.getCurrentLocation();
    if (!mounted) return;
    setState(() => _isLocating = false);

    if (pos != null) {
      final myLatLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _myCurrentLocation = myLatLng;
      });
      if (moveCamera) {
        _osmMapController.move(myLatLng, 16.0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã định vị vị trí của bạn: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0072FF),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else if (moveCamera) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.location_off_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Vui lòng bật định vị GPS và cấp quyền cho ứng dụng để nhận vị trí.'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Đà Nẵng',
            textColor: Colors.white,
            onPressed: () => _osmMapController.move(_daNangCenter, 14.0),
          ),
        ),
      );
    }
  }

  Future<void> _openGoogleMapsDirections(RestaurantModel r) async {
    final lat = (r.latitude != 0.0) ? r.latitude : 16.0544;
    final lng = (r.longitude != 0.0) ? r.longitude : 108.2022;
    final googleMapsAppUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final String originParam = _myCurrentLocation != null
        ? '&origin=${_myCurrentLocation!.latitude},${_myCurrentLocation!.longitude}'
        : '';
    final webUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng$originParam&travelmode=driving');

    try {
      if (await canLaunchUrl(googleMapsAppUri)) {
        await launchUrl(googleMapsAppUri);
        return;
      }
    } catch (_) {}

    try {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể mở Google Maps: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _zoomFitAllRestaurants() {
    if (widget.restaurants.isEmpty) return;
    double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    int validCount = 0;

    for (final r in widget.restaurants) {
      final lat = (r.latitude != 0.0) ? r.latitude : 16.0544;
      final lng = (r.longitude != 0.0) ? r.longitude : 108.2022;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
      validCount++;
    }

    if (validCount == 0) return;

    if (minLat == maxLat) {
      minLat -= 0.01;
      maxLat += 0.01;
    }
    if (minLng == maxLng) {
      minLng -= 0.01;
      maxLng += 0.01;
    }

    _osmMapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat, minLng),
          LatLng(maxLat, maxLng),
        ),
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  void _onSelectMapRestaurant(RestaurantModel r) {
    setState(() {
      _selectedMapRestaurant = r;
    });
    final lat = (r.latitude != 0.0) ? r.latitude : 16.0544;
    final lng = (r.longitude != 0.0) ? r.longitude : 108.2022;
    _osmMapController.move(LatLng(lat - 0.003, lng), 15.5);
  }

  List<Marker> _buildMapMarkers() {
    final filtered = widget.restaurants.where((r) {
      if (_mapCategoryFilter != 'Tất cả') {
        final matchesCat = r.categories.any((c) => c.toLowerCase() == _mapCategoryFilter.toLowerCase()) ||
            r.displayCategory.toLowerCase().contains(_mapCategoryFilter.toLowerCase()) ||
            (r.primaryCategoryName != null &&
                r.primaryCategoryName!.toLowerCase().contains(_mapCategoryFilter.toLowerCase()));
        if (!matchesCat) return false;
      }
      final query = _mapSearchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final matches = r.name.toLowerCase().contains(query) ||
            r.address.toLowerCase().contains(query) ||
            r.displayCategory.toLowerCase().contains(query);
        if (!matches) return false;
      }
      return true;
    }).toList();

    final markers = filtered.map<Marker>((r) {
      final isSelected = _selectedMapRestaurant?.id == r.id;
      final lat = (r.latitude != 0.0) ? r.latitude : 16.0544;
      final lng = (r.longitude != 0.0) ? r.longitude : 108.2022;

      return Marker(
        point: LatLng(lat, lng),
        width: isSelected ? 48 : 36,
        height: isSelected ? 48 : 36,
        child: GestureDetector(
          onTap: () => _onSelectMapRestaurant(r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0072FF) : const Color(0xFFEF4444),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: isSelected ? 2.5 : 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: isSelected ? 8 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              isSelected ? Icons.place_rounded : Icons.restaurant_rounded,
              color: Colors.white,
              size: isSelected ? 26 : 18,
            ),
          ),
        ),
      );
    }).toList();

    // Thêm marker vị trí GPS người dùng nếu đã xác định được
    if (_myCurrentLocation != null) {
      markers.add(
        Marker(
          point: _myCurrentLocation!,
          width: 52,
          height: 52,
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('📍 Vị trí GPS hiện tại của bạn'),
                    ],
                  ),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Color(0xFF0072FF),
                ),
              );
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Vòng sóng radar lan tỏa
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0072FF).withValues(alpha: 0.22),
                  ),
                ),
                // Viền trắng bảo vệ
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                // Chấm tròn định vị xanh dương đậm
                Container(
                  width: 15,
                  height: 15,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF0072FF),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildMapTopBar() {
    final categories = [
      'Tất cả',
      'Hải Sản',
      'Nhà Hàng',
      'Cà Phê',
      'Lẩu Nướng BBQ',
      'Buffet',
      'Trà Sữa',
      'Tiệm Bánh'
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Ô tìm kiếm quán
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              const Icon(Icons.search_rounded, color: Color(0xFF0072FF), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _mapSearchController,
                  decoration: const InputDecoration(
                    hintText: 'Tìm kiếm quán ăn trên bản đồ...',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (_mapSearchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _mapSearchController.clear();
                    setState(() {});
                  },
                ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_buildMapMarkers().length} quán',
                  style: const TextStyle(color: Color(0xFF0072FF), fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 2. Bộ lọc danh mục lướt ngang
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (ctx, i) {
              final cat = categories[i];
              final isSel = _mapCategoryFilter == cat;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _mapCategoryFilter = cat;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF0072FF) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSel ? const Color(0xFF0072FF) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                      color: isSel ? Colors.white : const Color(0xFF334155),
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

  Widget _buildMapFloatingControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Chuyển đổi bản đồ Vệ tinh / Đường phố
        FloatingActionButton.small(
          heroTag: 'map_type_btn',
          onPressed: () {
            setState(() {
              _isSatelliteMode = !_isSatelliteMode;
            });
          },
          backgroundColor: Colors.white,
          foregroundColor: _isSatelliteMode ? const Color(0xFF0072FF) : const Color(0xFF334155),
          elevation: 3,
          tooltip: 'Chế độ bản đồ vệ tinh / đường phố',
          child: Icon(_isSatelliteMode ? Icons.map_rounded : Icons.satellite_alt_rounded, size: 20),
        ),
        const SizedBox(height: 8),
        // Phóng to +
        FloatingActionButton.small(
          heroTag: 'zoom_in_btn',
          onPressed: () {
            final curZoom = _osmMapController.camera.zoom;
            _osmMapController.move(_osmMapController.camera.center, (curZoom + 1).clamp(6.0, 19.0));
          },
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 3,
          tooltip: 'Phóng to',
          child: const Icon(Icons.add_rounded, size: 20),
        ),
        const SizedBox(height: 8),
        // Thu nhỏ -
        FloatingActionButton.small(
          heroTag: 'zoom_out_btn',
          onPressed: () {
            final curZoom = _osmMapController.camera.zoom;
            _osmMapController.move(_osmMapController.camera.center, (curZoom - 1).clamp(6.0, 19.0));
          },
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 3,
          tooltip: 'Thu nhỏ',
          child: const Icon(Icons.remove_rounded, size: 20),
        ),
        const SizedBox(height: 8),
        // Nút La Bàn / Căn chỉnh hướng Bắc - Nam (North Up)
        FloatingActionButton.small(
          heroTag: 'compass_north_btn',
          onPressed: () {
            _osmMapController.rotate(0.0);
            setState(() => _currentRotation = 0.0);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.explore_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('🧭 Đã chỉnh bản đồ về đúng hướng Bắc - Nam'),
                  ],
                ),
                backgroundColor: Color(0xFF0072FF),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 1),
              ),
            );
          },
          backgroundColor: Colors.white,
          elevation: 3,
          tooltip: 'Chỉnh lại hướng Bắc - Nam',
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: -(_currentRotation * math.pi / 180),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_drop_up_rounded, size: 22, color: Color(0xFFEF4444)),
                    Icon(Icons.arrow_drop_down_rounded, size: 22, color: Color(0xFF64748B)),
                  ],
                ),
              ),
              const Positioned(
                top: 2,
                child: Text(
                  'N',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Xem toàn bộ quán
        FloatingActionButton.small(
          heroTag: 'fit_all_btn',
          onPressed: _zoomFitAllRestaurants,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0072FF),
          elevation: 3,
          tooltip: 'Bao quát tất cả quán',
          child: const Icon(Icons.zoom_out_map_rounded, size: 20),
        ),
        const SizedBox(height: 8),
        // Vị trí GPS hiện tại của tôi
        FloatingActionButton.small(
          heroTag: 'my_loc_btn',
          onPressed: _isLocating ? null : () => _determineMyCurrentLocation(moveCamera: true),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0072FF),
          elevation: 3,
          tooltip: 'Vị trí GPS của tôi',
          child: _isLocating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0072FF)),
                )
              : const Icon(Icons.my_location_rounded, size: 20),
        ),
      ],
    );
  }

  Widget _buildSelectedRestaurantCard(RestaurantModel r) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row: Ảnh + Thông tin quán + Nút đóng
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 86,
                  height: 86,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        r.coverImageUrl ??
                            r.logoUrl ??
                            'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=400&q=80',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFFEFF6FF),
                          child: const Icon(Icons.restaurant, color: Color(0xFF0072FF)),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 12),
                              const SizedBox(width: 2),
                              Text(
                                '${r.rating}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.name,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _selectedMapRestaurant = null),
                          borderRadius: BorderRadius.circular(16),
                          child: const Padding(
                            padding: EdgeInsets.all(2.0),
                            child: Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            r.displayCategory,
                            style: const TextStyle(
                              color: Color(0xFF0072FF),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          r.formattedPrice,
                          style: const TextStyle(
                            color: Color(0xFF047857),
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF64748B)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              String distanceInfo = r.distanceText ?? '';
                              if (_myCurrentLocation != null) {
                                final dMeters = _locationService.distanceBetween(
                                  _myCurrentLocation!.latitude,
                                  _myCurrentLocation!.longitude,
                                  r.latitude,
                                  r.longitude,
                                );
                                distanceInfo = 'Cách bạn ${_locationService.formatDistance(dMeters)}';
                              }

                              return Text(
                                distanceInfo.isNotEmpty
                                    ? '$distanceInfo • ${r.address}'
                                    : r.address,
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    if (r.openTime != null && r.closeTime != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF10B981)),
                          const SizedBox(width: 3),
                          Text(
                            'Mở cửa: ${r.openTime} - ${r.closeTime}',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Nút hành động: Chỉ đường Google Maps & Đặt bàn
          Row(
            children: [
              Expanded(
                flex: 6,
                child: ElevatedButton.icon(
                  onPressed: () => _openGoogleMapsDirections(r),
                  icon: const Icon(Icons.directions_rounded, size: 17),
                  label: const Text('Chỉ đường GG Maps', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0072FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 9.5),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (widget.onShowBooking != null) {
                      widget.onShowBooking!(r);
                    } else {
                      RestaurantModals.showBooking(context, r);
                    }
                  },
                  icon: const Icon(Icons.table_restaurant_rounded, size: 16),
                  label: const Text('Đặt bàn', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0072FF),
                    side: const BorderSide(color: Color(0xFF0072FF), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 9.5),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: () {
                  if (widget.onShowDetails != null) {
                    widget.onShowDetails!(r);
                  } else {
                    RestaurantModals.showDetails(context, r);
                  }
                },
                icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF475569), size: 20),
                tooltip: 'Xem chi tiết quán',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = _buildMapMarkers();

    return Stack(
      children: [
        // 1. FlutterMap (Google Maps Raster Tiles & Satellite)
        Positioned.fill(
          child: FlutterMap(
            mapController: _osmMapController,
            options: MapOptions(
              initialCenter: _daNangCenter,
              initialZoom: 13.8,
              minZoom: 6.0,
              maxZoom: 20.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onPositionChanged: (camera, hasGesture) {
                if ((camera.rotation - _currentRotation).abs() > 0.5) {
                  setState(() {
                    _currentRotation = camera.rotation;
                  });
                }
              },
              onTap: (_, _) {
                if (_selectedMapRestaurant != null) {
                  setState(() => _selectedMapRestaurant = null);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _isSatelliteMode
                    ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                    : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'vn.fconnect.app',
                maxZoom: 20,
              ),
              MarkerLayer(
                markers: markers,
              ),
            ],
          ),
        ),

        // 2. Top Bar (Tìm kiếm & Bộ lọc thể loại)
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: _buildMapTopBar(),
        ),

        // 3. Floating Action Controls (Góc phải)
        Positioned(
          right: 16,
          bottom: _selectedMapRestaurant != null ? 220 : 20,
          child: _buildMapFloatingControls(),
        ),

        // 4. Card Xem Trước Quán Ăn (Góc dưới)
        if (_selectedMapRestaurant != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildSelectedRestaurantCard(_selectedMapRestaurant!),
          ),
      ],
    );
  }
}

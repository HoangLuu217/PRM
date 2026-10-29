import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/administrative_division_service.dart';
import '../../../services/restaurant_service.dart';

class MerchantOnboardingDialog extends StatefulWidget {
  final VoidCallback? onCompleted;
  final AdministrativeDivisionService? administrativeDivisionService;

  const MerchantOnboardingDialog({
    super.key,
    this.onCompleted,
    this.administrativeDivisionService,
  });

  static Future<bool?> show(BuildContext context, {VoidCallback? onCompleted}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => MerchantOnboardingDialog(onCompleted: onCompleted),
    );
  }

  @override
  State<MerchantOnboardingDialog> createState() =>
      _MerchantOnboardingDialogState();
}

class _MerchantOnboardingDialogState extends State<MerchantOnboardingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _restaurantService = RestaurantService();
  late final AdministrativeDivisionService _administrativeDivisionService;

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _streetController;
  late TextEditingController _googleMapsController;
  late TextEditingController _minPriceController;
  late TextEditingController _maxPriceController;
  late TextEditingController _phoneController;

  String _selectedCategory = 'RESTAURANT';
  List<AdministrativeDivision> _provinces = [];
  List<AdministrativeDivision> _wards = [];
  AdministrativeDivision? _selectedProvince;
  AdministrativeDivision? _selectedWard;
  String? _savedProvinceName;
  String? _savedWardName;
  bool _isLoadingProvinces = true;
  bool _isLoadingWards = false;
  String? _locationError;

  final List<String> _selectedVibes = [
    'Yên tĩnh / Làm việc',
    'Ấm cúng / Gia đình',
  ];
  final List<String> _selectedPurposes = ['Gặp gỡ bạn bè', 'Bữa ăn gia đình'];

  bool _isSubmitting = false;

  final Map<String, String> _categories = const {
    'RESTAURANT': 'Nhà hàng ẩm thực cao cấp / gia đình',
    'CAFE': 'Quán Cà phê / Đồ uống',
    'BBQ': 'Lẩu Nướng BBQ',
    'BUFFET': 'Buffet ẩm thực',
    'BAKERY': 'Tiệm Bánh & Tráng miệng',
    'MILK_TEA': 'Trà Sữa & Ăn vặt',
    'FAST_FOOD': 'Thức ăn nhanh',
    'BAR': 'Bar & Pub',
    'OTHER': 'Mô hình kinh doanh khác',
  };

  final List<String> _availableVibes = const [
    'Yên tĩnh / Làm việc',
    'Lãng mạn / Hẹn hò',
    'Ngoài trời / Sân vườn',
    'Hiện đại / Sang trọng',
    'Ấm cúng / Gia đình',
    'Check-in sống ảo',
    'Rooftop / View trên cao',
    'Vỉa hè / Đường phố',
  ];

  final List<String> _availablePurposes = const [
    'Hẹn hò cặp đôi',
    'Họp nhóm / Học bài',
    'Gặp gỡ bạn bè',
    'Bữa ăn gia đình',
    'Tiếp khách / Công việc',
    'Tổ chức sinh nhật / Tiệc',
  ];

  @override
  void initState() {
    super.initState();
    _administrativeDivisionService =
        widget.administrativeDivisionService ?? AdministrativeDivisionService();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final biz = user?.business;
    final primaryBranch = biz?['primaryBranch'];
    final branchAddress =
        primaryBranch is Map && primaryBranch['address'] is Map
        ? Map<String, dynamic>.from(primaryBranch['address'] as Map)
        : null;
    final businessAddress = biz?['address'] is Map
        ? Map<String, dynamic>.from(biz!['address'] as Map)
        : null;
    final branchHasAddress = branchAddress != null &&
        ['street', 'ward', 'district', 'city'].any(
          (field) => branchAddress[field]?.toString().trim().isNotEmpty == true,
        );
    final savedAddress = branchHasAddress
        ? branchAddress
        : businessAddress ?? branchAddress;

    _nameController = TextEditingController(
      text: biz?['name']?.toString() ?? '',
    );
    _descController = TextEditingController(
      text: biz?['description']?.toString() ?? '',
    );
    _streetController = TextEditingController(
      text: savedAddress?['street']?.toString() ?? '',
    );
    _googleMapsController = TextEditingController(
      text: biz?['googleMapsUrl']?.toString() ?? '',
    );
    _phoneController = TextEditingController(
      text: user?.phone ?? biz?['phone']?.toString() ?? '',
    );
    _savedProvinceName = savedAddress?['city']?.toString();
    _savedWardName = savedAddress?['ward']?.toString();

    final minP = biz?['priceRange']?['min'] ?? 20000;
    final maxP = biz?['priceRange']?['max'] ?? 100000;
    _minPriceController = TextEditingController(text: minP.toString());
    _maxPriceController = TextEditingController(text: maxP.toString());

    if (biz != null) {
      if (biz['categories'] is List && (biz['categories'] as List).isNotEmpty) {
        _selectedCategory = biz['categories'][0].toString();
      }
      if (biz['vibes'] is List) {
        _selectedVibes.clear();
        for (var v in biz['vibes']) {
          _selectedVibes.add(v.toString());
        }
      }
      if (biz['purposes'] is List) {
        _selectedPurposes.clear();
        for (var p in biz['purposes']) {
          _selectedPurposes.add(p.toString());
        }
      }
    }
    _loadProvinces();
  }

  @override
  void dispose() {
    if (widget.administrativeDivisionService == null) {
      _administrativeDivisionService.close();
    }
    _nameController.dispose();
    _descController.dispose();
    _streetController.dispose();
    _googleMapsController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    setState(() {
      _isLoadingProvinces = true;
      _locationError = null;
    });

    try {
      final provinces = await _administrativeDivisionService.fetchProvinces();
      final selectedProvince =
          provinces.where((province) {
            return province.name == _savedProvinceName;
          }).firstOrNull ??
          provinces.where((province) => province.code == 48).firstOrNull ??
          provinces.first;

      if (!mounted) return;
      setState(() {
        _provinces = provinces;
        _selectedProvince = selectedProvince;
        _isLoadingProvinces = false;
      });
      await _loadWards(selectedProvince);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingProvinces = false;
        _locationError = error.toString();
      });
    }
  }

  Future<void> _loadWards(AdministrativeDivision province) async {
    setState(() {
      _isLoadingWards = true;
      _wards = [];
      _selectedWard = null;
      _locationError = null;
    });

    try {
      final wards = await _administrativeDivisionService.fetchWards(
        province.code,
      );
      if (!mounted) return;
      setState(() {
        _wards = wards;
        _selectedWard = wards.where((ward) {
          return ward.name == _savedWardName;
        }).firstOrNull;
        _isLoadingWards = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingWards = false;
        _locationError = error.toString();
      });
    }
  }

  String _formatVnd(String text) {
    final numVal = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return '${numVal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}đ';
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final minPrice = int.tryParse(_minPriceController.text.trim()) ?? 20000;
    final maxPrice = int.tryParse(_maxPriceController.text.trim()) ?? 100000;

    final result = await _restaurantService.onboardBusiness(
      name: _nameController.text.trim(),
      category: _selectedCategory,
      description: _descController.text.trim(),
      city: _selectedProvince?.name ?? '',
      ward: _selectedWard?.name ?? '',
      street: _streetController.text.trim(),
      googleMapsUrl: _googleMapsController.text.trim(),
      minPrice: minPrice,
      maxPrice: maxPrice,
      vibes: _selectedVibes,
      purposes: _selectedPurposes,
      phone: _phoneController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      // Làm mới lại auth user và profile
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await authProvider.checkAuthStatus();
      await userProvider.fetchProfile();
      final responseData = result['data'];
      if (responseData is Map && responseData['business'] is Map) {
        final savedBusiness = Map<String, dynamic>.from(
          responseData['business'] as Map,
        );
        final savedBranch = responseData['branch'];
        if (savedBranch is Map) {
          savedBusiness['primaryBranch'] ??= savedBranch;
          savedBusiness['address'] ??= savedBranch['address'];
        }
        authProvider.updateBusiness(savedBusiness);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result['message'] ??
                      'Đã lưu và kích hoạt hồ sơ quán thành công!',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      widget.onCompleted?.call();
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result['message'] ?? 'Không thể lưu thông tin quán',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 780),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 35,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Scaffold(
                backgroundColor: Colors.white,
                appBar: AppBar(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  titleSpacing: 20,
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 14,
                              color: Color(0xFF2563EB),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'BƯỚC 2: HOÀN THIỆN HỒ SƠ QUÁN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF64748B),
                      ),
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                body: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Title & Subtitle
                        const Text(
                          'Thông Tin Quán / Thương Hiệu F&B',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Điền thông tin cơ sở kinh doanh để mở bán và đón khách đặt bàn trên FConnect.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 1. Tên Quán / Thương hiệu F&B *
                        _buildSectionLabel(
                          'Tên Quán / Thương hiệu F&B',
                          isRequired: true,
                        ),
                        TextFormField(
                          controller: _nameController,
                          decoration: _inputDecoration(
                            hintText: 'Ví dụ: Highland Coffee, Lẩu Nướng Tokbokki Seoul...',
                            prefixIcon: Icons.storefront_outlined,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Vui lòng nhập tên quán hoặc thương hiệu F&B';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // 2. Mô hình kinh doanh F&B *
                        _buildSectionLabel(
                          'Mô hình kinh doanh F&B',
                          isRequired: true,
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          isExpanded: true,
                          decoration: _inputDecoration(
                            hintText: 'Chọn mô hình kinh doanh',
                            prefixIcon: Icons.category_outlined,
                          ),
                          items: _categories.entries.map((e) {
                            return DropdownMenuItem<String>(
                              value: e.key,
                              child: Text(
                                e.value,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedCategory = val);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // 3. Mô tả ngắn gọn về quán
                        _buildSectionLabel('Mô tả ngắn gọn về quán'),
                        TextFormField(
                          controller: _descController,
                          maxLines: 3,
                          decoration: _inputDecoration(
                            hintText: 'Giới thiệu phong cách ẩm thực, không gian quán, món signature...',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 4. Tỉnh / Thành phố & Phường / Xã
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionLabel(
                                    'Tỉnh / Thành phố',
                                    isRequired: true,
                                  ),
                                  DropdownButtonFormField<int>(
                                    key: ValueKey(_selectedProvince?.code),
                                    initialValue: _selectedProvince?.code,
                                    isExpanded: true,
                                    decoration: _inputDecoration(
                                      hintText: _isLoadingProvinces
                                          ? 'Đang tải tỉnh/thành...'
                                          : 'Chọn tỉnh/thành',
                                    ),
                                    items: _provinces.map((province) {
                                      return DropdownMenuItem(
                                        value: province.code,
                                        child: Text(
                                          province.name,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (v) {
                                      if (v == null) return;
                                      final province = _provinces.firstWhere(
                                        (item) => item.code == v,
                                      );
                                      setState(() {
                                        _selectedProvince = province;
                                        _savedWardName = null;
                                      });
                                      _loadWards(province);
                                    },
                                    validator: (value) => value == null
                                        ? 'Vui lòng chọn tỉnh/thành'
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionLabel(
                                    'Phường / Xã',
                                    isRequired: true,
                                  ),
                                  DropdownButtonFormField<int>(
                                    key: ValueKey(
                                      '${_selectedProvince?.code}-${_selectedWard?.code}',
                                    ),
                                    initialValue: _selectedWard?.code,
                                    isExpanded: true,
                                    decoration: _inputDecoration(
                                      hintText: _isLoadingWards
                                          ? 'Đang tải phường/xã...'
                                          : 'Chọn phường/xã',
                                    ),
                                    items: _wards.map((ward) {
                                      return DropdownMenuItem(
                                        value: ward.code,
                                        child: Text(
                                          ward.name,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: _isLoadingWards
                                        ? null
                                        : (v) {
                                            if (v == null) return;
                                            setState(() {
                                              _selectedWard = _wards.firstWhere(
                                                (item) => item.code == v,
                                              );
                                            });
                                          },
                                    validator: (value) => value == null
                                        ? 'Vui lòng chọn phường/xã'
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_locationError != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _locationError!,
                                  style: const TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed:
                                    _isLoadingProvinces || _isLoadingWards
                                    ? null
                                    : _selectedProvince == null
                                    ? _loadProvinces
                                    : () => _loadWards(_selectedProvince!),
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),

                        // 5. Địa chỉ cụ thể *
                        _buildSectionLabel(
                          'Địa chỉ cụ thể (Số nhà, tên đường, phường/xã)',
                          isRequired: true,
                        ),
                        TextFormField(
                          controller: _streetController,
                          decoration: _inputDecoration(
                            hintText: 'Ví dụ: 123 Nguyễn Văn Linh, Phường Nam Dương...',
                            prefixIcon: Icons.location_on_outlined,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Vui lòng nhập địa chỉ cụ thể của quán';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // 6. Số điện thoại hotline liên hệ
                        _buildSectionLabel('Số điện thoại liên hệ / Đặt bàn'),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDecoration(
                            hintText: 'Ví dụ: 0905123456',
                            prefixIcon: Icons.phone_outlined,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 7. Link vị trí Google Maps của quán
                        _buildSectionLabel('Link vị trí Google Maps của quán'),
                        TextFormField(
                          controller: _googleMapsController,
                          decoration: _inputDecoration(
                            hintText: 'https://maps.app.goo.gl/... hoặc https://goo.gl/maps/...',
                            prefixIcon: Icons.link_rounded,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Tip Google Maps
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('💡 ', style: TextStyle(fontSize: 15)),
                              Expanded(
                                child: Text(
                                  'Mẹo: Mở ứng dụng Google Maps > Chọn địa điểm quán > Nhấn Chia sẻ > Sao chép liên kết và dán vào đây để thực khách dễ dàng bấm định vị chỉ đường.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF92400E),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 8. Khoảng giá phục vụ (VNĐ)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _buildSectionLabel(
                                '💵 Khoảng giá phục vụ (VNĐ)',
                              ),
                            ),
                            Text(
                              '${_formatVnd(_minPriceController.text)} – ${_formatVnd(_maxPriceController.text)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _minPriceController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration(hintText: '20000'),
                                onChanged: (v) => setState(() {}),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '—',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextFormField(
                                controller: _maxPriceController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration(
                                  hintText: '100000',
                                ),
                                onChanged: (v) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // 9. Không gian / Vibe của quán
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _buildSectionLabel(
                                '🌿 Không gian / Vibe của quán',
                              ),
                            ),
                            const Text(
                              'Chọn các đặc trưng phù hợp',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableVibes.map((vibe) {
                            final isSelected = _selectedVibes.contains(vibe);
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedVibes.remove(vibe);
                                  } else {
                                    _selectedVibes.add(vibe);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFF0FDF4)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFCBD5E1),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isSelected ? '✓ ' : '+ ',
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF059669)
                                            : const Color(0xFF64748B),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      vibe,
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF065F46)
                                            : const Color(0xFF334155),
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // 10. Mục đích sử dụng phù hợp
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _buildSectionLabel(
                                '🎯 Mục đích sử dụng phù hợp',
                              ),
                            ),
                            const Text(
                              'Dịp khách thường ghé quán',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8B5CF6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availablePurposes.map((purpose) {
                            final isSelected = _selectedPurposes.contains(
                              purpose,
                            );
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedPurposes.remove(purpose);
                                  } else {
                                    _selectedPurposes.add(purpose);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFF5F3FF)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF8B5CF6)
                                        : const Color(0xFFCBD5E1),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isSelected ? '✓ ' : '+ ',
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF7C3AED)
                                            : const Color(0xFF64748B),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      purpose,
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF6D28D9)
                                            : const Color(0xFF334155),
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 32),

                        // Bottom Actions: Để sau & Lưu & Kích hoạt
                        Row(
                          children: [
                            // Nút Để sau
                            Expanded(
                              flex: 4,
                              child: OutlinedButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => Navigator.of(context).pop(false),
                                icon: const Icon(
                                  Icons.schedule_rounded,
                                  size: 16,
                                ),
                                label: const Text('Để sau'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF475569),
                                  side: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Nút Lưu & Kích Hoạt Gian Hàng Ngay
                            Expanded(
                              flex: 7,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check_rounded, size: 18),
                                          SizedBox(width: 6),
                                          Text(
                                            'Lưu & Kích Hoạt Ngay',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text.rich(
        TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
          children: isRequired
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 18, color: const Color(0xFF64748B))
          : null,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }
}

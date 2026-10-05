import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _editFormKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _avatarController;
  late TextEditingController _businessNameController;
  late TextEditingController _businessAddressController;

  String? _selectedArea;
  List<String> _selectedCategories = [];
  RangeValues _priceRange = const RangeValues(20000, 500000);

  // Available Areas in Da Nang
  final List<String> _availableAreas = [
    'Hải Châu',
    'Sơn Trà',
    'Ngũ Hành Sơn',
    'Thanh Khê',
    'Cẩm Lệ',
    'Liên Chiểu',
    'Hòa Vang',
  ];

  // Available F&B Categories
  final Map<String, String> _categoryOptions = {
    'RESTAURANT': '🍽️ Nhà hàng',
    'CAFE': '☕ Cà phê',
    'MILK_TEA': '🧋 Trà sữa',
    'BBQ': '🥩 BBQ & Nướng',
    'BUFFET': '🍲 Buffet & Lẩu',
    'BAKERY': '🍰 Bánh & Tráng miệng',
    'FAST_FOOD': '🍕 Thức ăn nhanh',
    'BAR': '🍸 Quán Bar & Pub',
  };

  final List<String> _presetAvatars = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=400&q=80',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _avatarController = TextEditingController();
    _businessNameController = TextEditingController();
    _businessAddressController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  void _loadUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) {
      authProvider.checkAuthStatus().then((_) {
        if (mounted && authProvider.user != null) {
          _populateFields(authProvider.user!);
        }
      });
    } else {
      _populateFields(authProvider.user!);
    }
  }

  void _populateFields(User user) {
    setState(() {
      _nameController.text = user.fullName;
      _phoneController.text = user.phone ?? '';
      _avatarController.text = user.avatarUrl ?? '';
      _businessNameController.text = user.business?['name']?.toString() ?? '';
      _businessAddressController.text = user.business?['address']?['street']?.toString() ??
          user.business?['address']?.toString() ??
          '';

      _selectedCategories = List.from(user.preferences.favoriteCategories);
      if (user.preferences.preferredAreas.isNotEmpty) {
        _selectedArea = user.preferences.preferredAreas.first;
      }
      _priceRange = RangeValues(
        user.preferences.minPrice.toDouble().clamp(0, 1000000),
        user.preferences.maxPrice.toDouble().clamp(0, 1000000),
      );
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _avatarController.dispose();
    _businessNameController.dispose();
    _businessAddressController.dispose();
    super.dispose();
  }

  String _formatCurrency(num value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M đ';
    }
    return '${(value / 1000).round()}k đ';
  }

  void _handleSaveProfile() async {
    if (_editFormKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final updatePayload = {
        'fullName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'avatarUrl': _avatarController.text.trim().isNotEmpty
            ? _avatarController.text.trim()
            : authProvider.user?.avatarUrl,
        'preferences': {
          'favoriteCategories': _selectedCategories,
          'preferredAreas': _selectedArea != null ? [_selectedArea!] : [],
          'priceRange': {
            'min': _priceRange.start.round(),
            'max': _priceRange.end.round(),
          },
        },
      };

      final success = await authProvider.updateProfile(updatePayload);

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('Cập nhật thông tin thành công!')),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(authProvider.errorMessage ?? 'Cập nhật thất bại')),
              ],
            ),
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // Mở BottomSheet chỉnh sửa thông tin
  void _openEditProfileModal(User user, bool isOwner) {
    _populateFields(user);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final authProvider = Provider.of<AuthProvider>(context);

          return Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // Modal Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Modal Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isOwner ? 'Chỉnh Sửa Hồ Sơ Chủ Quán' : 'Chỉnh Sửa Hồ Sơ',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Modal Form Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Form(
                      key: _editFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar Edit
                          Center(
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 44,
                                  backgroundColor: const Color(0xFFEFF6FF),
                                  backgroundImage: NetworkImage(
                                    _avatarController.text.isNotEmpty
                                        ? _avatarController.text
                                        : (user.avatarUrl ?? _presetAvatars.first),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _showAvatarPicker(setModalState),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Full Name Input
                          Text(
                            isOwner ? 'Họ tên chủ sở hữu / Người đại diện' : 'Họ và tên',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155), fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nameController,
                            decoration: _buildInputDecoration(hint: 'Nguyễn Văn A', icon: Icons.person_outline_rounded),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Họ tên không được để trống' : null,
                          ),
                          const SizedBox(height: 14),

                          // Phone Input
                          Text(
                            isOwner ? 'Số điện thoại hotline cơ sở' : 'Số điện thoại',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155), fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: _buildInputDecoration(hint: '0901234567', icon: Icons.phone_outlined),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return null;
                              final phoneRegex = RegExp(r'^(0[3|5|7|8|9])[0-9]{8}$');
                              if (!phoneRegex.hasMatch(value.trim())) {
                                return 'Số điện thoại không hợp lệ (10 số)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          if (isOwner) ...[
                            // Business Name Input
                            const Text(
                              'Tên thương hiệu nhà hàng / quán ăn',
                              style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155), fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _businessNameController,
                              decoration: _buildInputDecoration(hint: 'Ví dụ: Hải Sản Bé Mặn', icon: Icons.storefront_rounded),
                            ),
                            const SizedBox(height: 14),

                            // Business Address Input
                            const Text(
                              'Địa chỉ chi nhánh chính tại Đà Nẵng',
                              style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155), fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _businessAddressController,
                              decoration: _buildInputDecoration(hint: 'Ví dụ: Lô 11 Võ Nguyên Giáp', icon: Icons.location_on_outlined),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Living / Business Area
                          Text(
                            isOwner ? 'Khu vực hoạt động tại Đà Nẵng' : 'Khu vực tại Đà Nẵng',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155), fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedArea,
                            decoration: _buildInputDecoration(hint: 'Chọn quận/huyện', icon: Icons.map_outlined),
                            items: _availableAreas
                                .map((area) => DropdownMenuItem(value: area, child: Text(area)))
                                .toList(),
                            onChanged: (val) => setModalState(() => _selectedArea = val),
                          ),
                          const SizedBox(height: 20),

                          // Preferences / Categories
                          Text(
                            isOwner ? 'Mô hình ẩm thực & dịch vụ của quán' : 'Sở thích ẩm thực',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155), fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _categoryOptions.entries.map((entry) {
                              final isSelected = _selectedCategories.contains(entry.key);
                              return FilterChip(
                                label: Text(entry.value),
                                selected: isSelected,
                                selectedColor: const Color(0xFFDBEAFE),
                                backgroundColor: const Color(0xFFF1F5F9),
                                checkmarkColor: const Color(0xFF2563EB),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                side: BorderSide(
                                  color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
                                ),
                                labelStyle: TextStyle(
                                  color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12.5,
                                ),
                                onSelected: (selected) {
                                  setModalState(() {
                                    if (selected) {
                                      _selectedCategories.add(entry.key);
                                    } else {
                                      _selectedCategories.remove(entry.key);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),

                          // Price Range Slider
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isOwner ? 'Khung giá món ăn tại quán:' : 'Khoảng giá mong muốn:',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155), fontSize: 13),
                              ),
                              Text(
                                '${_formatCurrency(_priceRange.start)} - ${_formatCurrency(_priceRange.end)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 13),
                              ),
                            ],
                          ),
                          RangeSlider(
                            values: _priceRange,
                            min: 0,
                            max: 1000000,
                            divisions: 20,
                            activeColor: const Color(0xFF2563EB),
                            inactiveColor: const Color(0xFFE2E8F0),
                            onChanged: (newValues) {
                              setModalState(() {
                                _priceRange = newValues;
                              });
                            },
                          ),
                          const SizedBox(height: 12),

                          // Change Password Link
                          if (user.authProvider == 'LOCAL')
                            Center(
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showChangePasswordDialog();
                                },
                                icon: const Icon(Icons.lock_reset_rounded, size: 18, color: Color(0xFF2563EB)),
                                label: const Text('Đổi mật khẩu tài khoản', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                              ),
                            ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),

                // Save Action Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, -4)),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: authProvider.isLoading ? null : _handleSaveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: authProvider.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Lưu Thay Đổi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    );
  }

  void _showAvatarPicker(void Function(void Function()) setModalState) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (pickerCtx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chọn ảnh đại diện / Logo quán', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _presetAvatars.length,
                separatorBuilder: (_, idx) => const SizedBox(width: 12),
                itemBuilder: (_, idx) {
                  final url = _presetAvatars[idx];
                  return GestureDetector(
                    onTap: () {
                      setModalState(() {
                        _avatarController.text = url;
                      });
                      Navigator.pop(pickerCtx);
                    },
                    child: CircleAvatar(
                      radius: 32,
                      backgroundImage: NetworkImage(url),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _avatarController,
              decoration: InputDecoration(
                labelText: 'Hoặc dán URL ảnh trực tuyến',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.link_rounded),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setModalState(() {});
                  Navigator.pop(pickerCtx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Áp dụng ảnh'),
              ),
            ),
          ],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Đổi Mật Khẩu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: passFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPassController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu hiện tại',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập mật khẩu hiện tại' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newPassController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu mới (từ 6 ký tự)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null || v.length < 6 ? 'Mật khẩu phải từ 6 ký tự' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPassController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Xác nhận mật khẩu mới',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v != newPassController.text ? 'Mật khẩu xác nhận không khớp' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Hủy')),
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
                            content: Text(success ? 'Đổi mật khẩu thành công!' : (authProvider.errorMessage ?? 'Thất bại')),
                            backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFE53935),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Đăng xuất tài khoản', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi FConnect?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();

    if (!mounted) return;
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
    final isOwner = authProvider.isOwner;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isOwner ? 'Merchant Profile' : 'Profile',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: authProvider.isLoading && user == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : user == null
              ? _buildErrorState()
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. User Hero Profile Card
                      _buildUserHeroCard(user, isOwner),
                      const SizedBox(height: 14),

                      // 2. Stats Row (Dynamic for Owner vs Customer)
                      isOwner ? _buildOwnerStatsRow(user) : _buildCustomerStatsRow(),
                      const SizedBox(height: 20),

                      // 3. Section 1: OUTLET & BUSINESS (or ACTIVITY & PLACES for Customer)
                      _buildSectionHeader(isOwner ? 'OUTLET & BUSINESS' : 'ACTIVITY & PLACES'),
                      const SizedBox(height: 8),
                      isOwner ? _buildOwnerBusinessGroup(user) : _buildCustomerActivityGroup(user),
                      const SizedBox(height: 20),

                      // 4. Section 2: OPERATIONS & COMMS (or PREFERENCES & COMMS for Customer)
                      _buildSectionHeader(isOwner ? 'OPERATIONS & COMMS' : 'PREFERENCES & COMMS'),
                      const SizedBox(height: 8),
                      isOwner ? _buildOwnerOperationsGroup(user) : _buildCustomerPreferencesGroup(user),
                      const SizedBox(height: 20),

                      // 5. Section 3: ACCOUNT & SECURITY (For Owner)
                      if (isOwner) ...[
                        _buildSectionHeader('ACCOUNT & SECURITY'),
                        const SizedBox(height: 8),
                        _buildOwnerSecurityGroup(user),
                        const SizedBox(height: 20),
                      ],

                      // 6. Logout Card
                      _buildLogoutCard(),
                      const SizedBox(height: 24),

                      // 7. Footer Brand Note
                      Center(
                        child: Column(
                          children: [
                            Text(
                              isOwner ? 'FConnect Partner Portal v2.4.1 (Build 890)' : 'FConnect Client v2.4.1 (Build 890)',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.blueGrey.shade400,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isOwner ? 'Designed for seamless restaurant operations' : 'Designed with precision for seamless dining',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blueGrey.shade300,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  // 1. User Hero Card (matching reference design with role badge)
  Widget _buildUserHeroCard(User user, bool isOwner) {
    final avatarImg = user.avatarUrl ?? _presetAvatars.first;
    final businessName = user.business?['name']?.toString() ?? 'Chủ Quán Đối Tác';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with Verified badge
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isOwner ? const Color(0xFFF97316) : const Color(0xFF3B82F6),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFFEFF6FF),
                  backgroundImage: NetworkImage(avatarImg),
                ),
              ),
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Name
          Text(
            user.fullName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 3),

          // Subtitle (Business Name or Email)
          Text(
            isOwner ? '$businessName • ${user.email}' : user.email,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 14),

          // Edit Profile Pill Button
          InkWell(
            onTap: () => _openEditProfileModal(user, isOwner),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isOwner ? const Color(0xFFFFF7ED) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 15,
                    color: isOwner ? const Color(0xFFEA580C) : const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOwner ? 'Edit Business Profile' : 'Edit Profile',
                    style: TextStyle(
                      color: isOwner ? const Color(0xFFEA580C) : const Color(0xFF2563EB),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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

  // 2a. Stats Row for Customer (Completed Visits & Favorite Spots)
  Widget _buildCustomerStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.calendar_today_rounded,
            iconBg: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF3B82F6),
            value: '12',
            label: 'Completed Visits',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.favorite_rounded,
            iconBg: const Color(0xFFECFDF5),
            iconColor: const Color(0xFF10B981),
            value: '8',
            label: 'Favorite Spots',
          ),
        ),
      ],
    );
  }

  // 2b. Stats Row for Owner (Rating, Bookings, Active Dishes)
  Widget _buildOwnerStatsRow(User user) {
    final rating = user.business?['ratingSummary']?['average']?.toString() ??
        user.business?['googleRating']?['rating']?.toString() ??
        '4.8';

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.star_rounded,
            iconBg: const Color(0xFFFEF3C7),
            iconColor: const Color(0xFFD97706),
            value: '$rating ★',
            label: 'Rating Score',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.table_restaurant_rounded,
            iconBg: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF2563EB),
            value: '18',
            label: 'Bookings Today',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3a. Owner Business Group
  Widget _buildOwnerBusinessGroup(User user) {
    final businessName = user.business?['name']?.toString() ?? 'Quán của bạn';

    return _buildCardGroup([
      _buildGroupItem(
        icon: Icons.storefront_rounded,
        iconBg: const Color(0xFFFFF7ED),
        iconColor: const Color(0xFFEA580C),
        title: 'Restaurant Profile',
        subtitle: businessName,
        onTap: () => _openEditProfileModal(user, true),
      ),
      _buildGroupItem(
        icon: Icons.location_on_outlined,
        iconBg: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
        title: 'Outlet & Branches',
        subtitle: 'Da Nang locations & Google Maps',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quản lý chi nhánh & vị trí (Member 2)')),
          );
        },
      ),
      _buildGroupItem(
        icon: Icons.schedule_rounded,
        iconBg: const Color(0xFFF0FDF4),
        iconColor: const Color(0xFF10B981),
        title: 'Operating Hours & Price',
        subtitle: 'Open 09:00 - 23:00 daily',
        onTap: () => _openEditProfileModal(user, true),
      ),
      _buildGroupItem(
        icon: Icons.account_balance_wallet_outlined,
        iconBg: const Color(0xFFFDF4FF),
        iconColor: const Color(0xFFC026D3),
        title: 'Banking & Payout',
        subtitle: 'QR Code deposit & billing account',
        isLast: true,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cấu hình tài khoản thụ hưởng thanh toán')),
          );
        },
      ),
    ]);
  }

  // 3b. Customer Activity Group
  Widget _buildCustomerActivityGroup(User user) {
    return _buildCardGroup([
      _buildGroupItem(
        icon: Icons.person_outline_rounded,
        iconBg: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
        title: 'Personal Information',
        subtitle: 'Manage personal details',
        onTap: () => _openEditProfileModal(user, false),
      ),
      _buildGroupItem(
        icon: Icons.favorite_border_rounded,
        iconBg: const Color(0xFFFFF1F2),
        iconColor: const Color(0xFFF43F5E),
        title: 'My Favorites',
        subtitle: 'Saved dining spots & cafes',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tính năng Quán yêu thích (Member 2)')),
          );
        },
      ),
      _buildGroupItem(
        icon: Icons.calendar_today_outlined,
        iconBg: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF3B82F6),
        title: 'My Bookings',
        subtitle: 'Upcoming & past reservations',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tính năng Đặt bàn (Member 4)')),
          );
        },
      ),
      _buildGroupItem(
        icon: Icons.receipt_long_outlined,
        iconBg: const Color(0xFFF0FDF4),
        iconColor: const Color(0xFF10B981),
        title: 'My Orders',
        subtitle: 'Food & drink orders',
        isLast: true,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tính năng Đơn hàng (Member 4)')),
          );
        },
      ),
    ]);
  }

  // 4a. Owner Operations Group
  Widget _buildOwnerOperationsGroup(User user) {
    return _buildCardGroup([
      _buildGroupItem(
        icon: Icons.notifications_active_outlined,
        iconBg: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
        title: 'Booking Alerts & Bells',
        subtitle: 'Realtime customer reservation push',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cài đặt chuông thông báo đặt bàn')),
          );
        },
      ),
      _buildGroupItem(
        icon: Icons.chat_bubble_outline_rounded,
        iconBg: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
        title: 'Customer Inquiries & Chat',
        subtitle: 'Direct messages with guests',
        badgeNumber: 1,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hộp thư tư vấn thực khách')),
          );
        },
      ),
      _buildGroupItem(
        icon: Icons.badge_outlined,
        iconBg: const Color(0xFFFEF3C7),
        iconColor: const Color(0xFFD97706),
        title: 'Staff Access & Roles',
        subtitle: 'Manage waiters and cashier staff',
        isLast: true,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quản lý phân quyền nhân viên quán')),
          );
        },
      ),
    ]);
  }

  // 4b. Customer Preferences Group
  Widget _buildCustomerPreferencesGroup(User user) {
    return _buildCardGroup([
      _buildGroupItem(
        icon: Icons.notifications_none_rounded,
        iconBg: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
        title: 'Notifications',
        subtitle: 'Push & booking alerts',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tính năng Thông báo')),
          );
        },
      ),
      _buildGroupItem(
        icon: Icons.chat_bubble_outline_rounded,
        iconBg: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
        title: 'Chat',
        subtitle: 'Direct messages with places',
        badgeNumber: 1,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tính năng Chat trực tiếp')),
          );
        },
      ),
      _buildGroupItem(
        icon: Icons.settings_outlined,
        iconBg: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
        title: 'Settings',
        subtitle: 'App preferences & security',
        isLast: true,
        onTap: () => _openEditProfileModal(user, false),
      ),
    ]);
  }

  // 5. Owner Security Group
  Widget _buildOwnerSecurityGroup(User user) {
    return _buildCardGroup([
      _buildGroupItem(
        icon: Icons.lock_outline_rounded,
        iconBg: const Color(0xFFF1F5F9),
        iconColor: const Color(0xFF475569),
        title: 'Security & Password',
        subtitle: 'Update owner login password',
        onTap: _showChangePasswordDialog,
      ),
      _buildGroupItem(
        icon: Icons.headset_mic_outlined,
        iconBg: const Color(0xFFF0FDF4),
        iconColor: const Color(0xFF10B981),
        title: 'Merchant Support 24/7',
        subtitle: 'Direct hotline & partner agreements',
        isLast: true,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hotline đối tác FConnect: 1900-8888')),
          );
        },
      ),
    ]);
  }

  // Section Header Text
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF64748B),
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  // Card Group Container
  Widget _buildCardGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  // Card Group Item Tile
  Widget _buildGroupItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    int? badgeNumber,
    bool isLast = false,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon Box
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                // Badge (if any)
                if (badgeNumber != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$badgeNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // Chevron
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            indent: 70,
            endIndent: 16,
            color: Color(0xFFF1F5F9),
          ),
      ],
    );
  }

  // Logout Standalone Card
  Widget _buildLogoutCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: _handleLogout,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFEF4444),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFEF4444),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            const Text(
              'Không thể tải thông tin hồ sơ. Vui lòng đăng nhập lại.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Đến trang Đăng nhập'),
            ),
          ],
        ),
      ),
    );
  }
}

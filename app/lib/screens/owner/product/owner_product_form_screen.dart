import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/product_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/product_provider.dart';

class OwnerProductFormScreen extends StatefulWidget {
  final ProductModel? product;
  final String? businessId;

  const OwnerProductFormScreen({
    super.key,
    this.product,
    this.businessId,
  });

  @override
  State<OwnerProductFormScreen> createState() => _OwnerProductFormScreenState();
}

class _OwnerProductFormScreenState extends State<OwnerProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late TextEditingController _imageUrlController;

  bool _isAvailable = true;
  List<ProductSize> _sizes = [];
  List<ProductOption> _options = [];
  bool _isSubmitting = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _categoryController = TextEditingController(text: widget.product?.category ?? 'Món chính');
    _priceController = TextEditingController(text: widget.product != null ? widget.product!.price.toInt().toString() : '');
    _descriptionController = TextEditingController(text: widget.product?.description ?? '');
    _imageUrlController = TextEditingController(text: widget.product?.imageUrl ?? '');
    _isAvailable = widget.product?.isAvailable ?? true;
    _sizes = List.from(widget.product?.sizes ?? []);
    _options = List.from(widget.product?.options ?? []);

    _imageUrlController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13.5, fontWeight: FontWeight.w500),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: const Color(0xFF2563EB), size: 19) : null,
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }

  Widget _buildFormSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailingAction,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: const Color(0xFF2563EB), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              if (trailingAction != null) trailingAction,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    final url = _imageUrlController.text.trim();
    if (url.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 24),
                SizedBox(width: 8),
                Text('Đường dẫn hình ảnh không hợp lệ', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addSizeDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.aspect_ratio_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Thêm kích cỡ món ăn (Size)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: _buildInputDecoration(
                labelText: 'Tên size *',
                hintText: 'Ví dụ: Size S, M, L, Lớn, Vừa',
                prefixIcon: Icons.text_fields_rounded,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: _buildInputDecoration(
                labelText: 'Giá bán cho size này (đ) *',
                hintText: 'Ví dụ: 45000',
                prefixIcon: Icons.payments_rounded,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              if (name.isNotEmpty && price > 0) {
                setState(() {
                  _sizes.add(ProductSize(
                    name: name,
                    price: price,
                    isDefault: _sizes.isEmpty,
                  ));
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Thêm Size'),
          ),
        ],
      ),
    );
  }

  void _addOptionDialog() {
    final optionNameCtrl = TextEditingController();
    bool isRequired = false;
    bool isMultiple = true;
    final List<ProductOptionValue> localValues = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.tune_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Thêm nhóm tùy chọn (Option)'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: optionNameCtrl,
                  decoration: _buildInputDecoration(
                    labelText: 'Tên nhóm tùy chọn *',
                    hintText: 'Ví dụ: Topping, Mức đường, Mức đá',
                    prefixIcon: Icons.tune_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Bắt buộc chọn (Required)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Khách phải chọn ít nhất 1 mục', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                        value: isRequired,
                        activeColor: const Color(0xFF2563EB),
                        dense: true,
                        onChanged: (v) => setDialogState(() => isRequired = v),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      SwitchListTile(
                        title: const Text('Cho phép chọn nhiều (Multiple)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Khách có thể tích chọn nhiều mục', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                        value: isMultiple,
                        activeColor: const Color(0xFF2563EB),
                        dense: true,
                        onChanged: (v) => setDialogState(() => isMultiple = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Danh sách lựa chọn con:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Thêm mục'),
                      onPressed: () {
                        final valNameCtrl = TextEditingController();
                        final valPriceCtrl = TextEditingController(text: '0');
                        showDialog(
                          context: ctx,
                          builder: (subCtx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('Thêm lựa chọn con'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: valNameCtrl,
                                  decoration: _buildInputDecoration(
                                    labelText: 'Tên lựa chọn *',
                                    hintText: 'Ví dụ: Trân châu đen, 100% Đá',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: valPriceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: _buildInputDecoration(
                                    labelText: 'Phụ thu thêm (đ)',
                                    hintText: 'Nhập 0 nếu miễn phí',
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(subCtx), child: const Text('Hủy')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  final vName = valNameCtrl.text.trim();
                                  final vPrice = double.tryParse(valPriceCtrl.text.trim()) ?? 0.0;
                                  if (vName.isNotEmpty) {
                                    setDialogState(() {
                                      localValues.add(ProductOptionValue(name: vName, price: vPrice));
                                    });
                                    Navigator.pop(subCtx);
                                  }
                                },
                                child: const Text('Lưu lựa chọn'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (localValues.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: localValues.map((lv) {
                      return Chip(
                        backgroundColor: const Color(0xFFEFF6FF),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        label: Text('${lv.name} (+${lv.price.toInt()}đ)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF))),
                        deleteIcon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF1E40AF)),
                        onDeleted: () => setDialogState(() => localValues.remove(lv)),
                      );
                    }).toList(),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Color(0xFF94A3B8), size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('Chưa có lựa chọn con nào. Nhấn "Thêm mục" để thêm.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final optName = optionNameCtrl.text.trim();
                if (optName.isNotEmpty) {
                  setState(() {
                    _options.add(ProductOption(
                      name: optName,
                      required: isRequired,
                      isMultiple: isMultiple,
                      values: localValues,
                    ));
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Tạo Option'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final token = authProvider.token ?? '';

    final name = _nameController.text.trim();
    final category = _categoryController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final description = _descriptionController.text.trim();
    final imageUrl = _imageUrlController.text.trim();

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_isEditing) {
        final updateData = {
          'name': name,
          'category': category,
          'price': price,
          'description': description,
          'imageUrl': imageUrl,
          'isAvailable': _isAvailable,
          'sizes': _sizes.map((s) => s.toJson()).toList(),
          'options': _options.map((o) => o.toJson()).toList(),
        };
        await productProvider.updateProduct(widget.product!.id, updateData, token);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Cập nhật món ăn & tùy chọn thành công!'),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        final newProd = ProductModel(
          id: '',
          businessId: widget.businessId,
          category: category,
          name: name,
          description: description,
          price: price,
          imageUrl: imageUrl,
          isAvailable: _isAvailable,
          sizes: _sizes,
          options: _options,
        );
        await productProvider.createProduct(newProd, token);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Thêm món ăn mới thành công!'),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
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
              child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              _isEditing ? 'Chỉnh sửa món ăn' : 'Thêm món ăn mới',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section 1: Basic Information
                  _buildFormSection(
                    title: '1. Thông tin cơ bản món ăn',
                    icon: Icons.fastfood_rounded,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: _buildInputDecoration(
                          labelText: 'Tên món ăn *',
                          hintText: 'Ví dụ: Cơm gà xối mỡ, Trà sữa trân châu, Lẩu hải sản',
                          prefixIcon: Icons.fastfood_rounded,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập tên món ăn';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final isWide = constraints.maxWidth > 500;
                          if (isWide) {
                            return Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _categoryController,
                                    decoration: _buildInputDecoration(
                                      labelText: 'Danh mục *',
                                      hintText: 'Ví dụ: Món chính, Đồ uống, Lẩu',
                                      prefixIcon: Icons.category_rounded,
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Vui lòng nhập danh mục';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _priceController,
                                    keyboardType: TextInputType.number,
                                    decoration: _buildInputDecoration(
                                      labelText: 'Giá bán cơ bản (đ) *',
                                      hintText: 'Ví dụ: 45000',
                                      prefixIcon: Icons.payments_rounded,
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Nhập giá bán';
                                      }
                                      final numVal = double.tryParse(val.trim());
                                      if (numVal == null || numVal < 0) {
                                        return 'Giá không hợp lệ';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                TextFormField(
                                  controller: _categoryController,
                                  decoration: _buildInputDecoration(
                                    labelText: 'Danh mục *',
                                    hintText: 'Ví dụ: Món chính, Đồ uống',
                                    prefixIcon: Icons.category_rounded,
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Vui lòng nhập danh mục';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _priceController,
                                  keyboardType: TextInputType.number,
                                  decoration: _buildInputDecoration(
                                    labelText: 'Giá bán cơ bản (đ) *',
                                    hintText: 'Ví dụ: 45000',
                                    prefixIcon: Icons.payments_rounded,
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Nhập giá bán';
                                    }
                                    final numVal = double.tryParse(val.trim());
                                    if (numVal == null || numVal < 0) {
                                      return 'Giá không hợp lệ';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            );
                          }
                        },
                      ),
                    ],
                  ),

                  // Section 2: Description & Image
                  _buildFormSection(
                    title: '2. Mô tả & Hình ảnh món ăn',
                    icon: Icons.image_outlined,
                    children: [
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: _buildInputDecoration(
                          labelText: 'Mô tả chi tiết món ăn',
                          hintText: 'Mô tả hương vị, nguyên liệu chế biến, định lượng...',
                          prefixIcon: Icons.description_rounded,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _imageUrlController,
                        decoration: _buildInputDecoration(
                          labelText: 'Đường dẫn hình ảnh (URL)',
                          hintText: 'https://images.unsplash.com/...',
                          prefixIcon: Icons.link_rounded,
                        ),
                      ),
                      _buildImagePreview(),
                    ],
                  ),

                  // Section 3: Availability
                  _buildFormSection(
                    title: '3. Trạng thái kinh doanh',
                    icon: Icons.storefront_rounded,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isAvailable ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _isAvailable ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
                        ),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Trạng thái phục vụ món',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _isAvailable ? const Color(0xFF166534) : const Color(0xFF991B1B),
                            ),
                          ),
                          subtitle: Text(
                            _isAvailable ? 'Món đang sẵn sàng phục vụ thực khách' : 'Món hiện đang tạm hết / tạm ngưng',
                            style: TextStyle(
                              fontSize: 12,
                              color: _isAvailable ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                            ),
                          ),
                          value: _isAvailable,
                          activeColor: const Color(0xFF16A34A),
                          onChanged: (val) {
                            setState(() {
                              _isAvailable = val;
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  // Section 4: Sizes
                  _buildFormSection(
                    title: '4. Kích cỡ món ăn (Size)',
                    icon: Icons.aspect_ratio_rounded,
                    trailingAction: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _addSizeDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Thêm size'),
                    ),
                    children: [
                      if (_sizes.isNotEmpty)
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _sizes.map((s) {
                            return Chip(
                              backgroundColor: const Color(0xFFEFF6FF),
                              side: const BorderSide(color: Color(0xFFBFDBFE)),
                              avatar: const Icon(Icons.straighten_rounded, size: 16, color: Color(0xFF1E40AF)),
                              label: Text('${s.name}: ${s.price.toInt()}đ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1E40AF))),
                              deleteIcon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF1E40AF)),
                              onDeleted: () {
                                setState(() {
                                  _sizes.remove(s);
                                });
                              },
                            );
                          }).toList(),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: Color(0xFF94A3B8), size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('Chưa thiết lập size (sẽ sử dụng giá bán cơ bản mặc định)', style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Section 5: Options & Toppings
                  _buildFormSection(
                    title: '5. Tùy chọn món ăn (Product Options)',
                    icon: Icons.tune_rounded,
                    trailingAction: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _addOptionDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Thêm Option'),
                    ),
                    children: [
                      if (_options.isNotEmpty)
                        Column(
                          children: _options.map((opt) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF2563EB)),
                                          const SizedBox(width: 8),
                                          Text(opt.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                                        ],
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          setState(() => _options.remove(opt));
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${opt.required ? "Bắt buộc chọn" : "Không bắt buộc"} • ${opt.isMultiple ? "Chọn nhiều" : "Chọn 1"}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 10),
                                  if (opt.values.isNotEmpty)
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: opt.values.map((v) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                          ),
                                          child: Text('${v.name} (+${v.price.toInt()}đ)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF334155))),
                                        );
                                      }).toList(),
                                    )
                                  else
                                    const Text('Chưa có lựa chọn con', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                                ],
                              ),
                            );
                          }).toList(),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: Color(0xFF94A3B8), size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('Chưa thiết lập tùy chọn (ví dụ: Topping, Mức đường, Mức đá)', style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Bottom Submit Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Hủy bỏ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _saveProduct,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_isEditing ? Icons.save_rounded : Icons.check_circle_rounded, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isEditing ? 'Cập nhật món ăn' : 'Lưu món ăn mới',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

  void _addSizeDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm Size'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Tên size (ví dụ: Size S, M, L)'),
            ),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Giá (đ)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
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
            child: const Text('Thêm'),
          ),
        ],
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
        };
        await productProvider.updateProduct(widget.product!.id, updateData, token);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cập nhật món ăn thành công!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } else {
        final newProd = ProductModel(
          id: '',
          category: category,
          name: name,
          description: description,
          price: price,
          imageUrl: imageUrl,
          isAvailable: _isAvailable,
          sizes: _sizes,
        );
        await productProvider.createProduct(newProd, token);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thêm món ăn mới thành công!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.redAccent,
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
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Chỉnh sửa món ăn' : 'Thêm món ăn mới',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên món ăn *',
                  hintText: 'Nhập tên món ăn',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập tên món ăn';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category & Price Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Danh mục *',
                        hintText: 'Ví dụ: Món chính, Đồ uống',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Nhập danh mục';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Giá bán (đ) *',
                        hintText: 'Ví dụ: 35000',
                        border: OutlineInputBorder(),
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
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Mô tả món ăn',
                  hintText: 'Mô tả nguyên liệu, hương vị đặc trưng...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Image URL
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Đường dẫn hình ảnh (URL)',
                  hintText: 'https://...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Availability Switch
              SwitchListTile(
                title: const Text('Trạng thái kinh doanh (Còn món)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_isAvailable ? 'Món đang sẵn sàng phục vụ' : 'Món hiện đang tạm hết'),
                value: _isAvailable,
                activeColor: Colors.deepOrange,
                onChanged: (val) {
                  setState(() {
                    _isAvailable = val;
                  });
                },
              ),
              const Divider(height: 24),

              // Sizes Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Danh sách Size', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _addSizeDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm size'),
                  ),
                ],
              ),
              if (_sizes.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: _sizes.map((s) {
                    return Chip(
                      label: Text('${s.name}: ${s.price.toInt()}đ'),
                      onDeleted: () {
                        setState(() {
                          _sizes.remove(s);
                        });
                      },
                    );
                  }).toList(),
                )
              else
                Text('Chưa thiết lập size (sẽ sử dụng giá bán mặc định)', style: TextStyle(color: Colors.grey[600], fontSize: 13)),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isEditing ? 'Cập nhật món ăn' : 'Thêm món ăn',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

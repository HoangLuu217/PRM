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
        title: const Text('Thêm kích cỡ (Size)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Tên size (ví dụ: Size S, M, L)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Giá bán cho size này (đ)', border: OutlineInputBorder()),
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

  void _addOptionDialog() {
    final optionNameCtrl = TextEditingController();
    bool isRequired = false;
    bool isMultiple = true;
    final List<ProductOptionValue> localValues = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Thêm nhóm tùy chọn (Option)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: optionNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên nhóm tùy chọn *',
                    hintText: 'Ví dụ: Topping, Mức đường, Mức đá',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Bắt buộc chọn (Required)', style: TextStyle(fontSize: 13.5)),
                  value: isRequired,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialogState(() => isRequired = v ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Cho phép chọn nhiều (Multiple)', style: TextStyle(fontSize: 13.5)),
                  value: isMultiple,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialogState(() => isMultiple = v ?? true),
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Các lựa chọn con:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Thêm mục'),
                      onPressed: () {
                        final valNameCtrl = TextEditingController();
                        final valPriceCtrl = TextEditingController(text: '0');
                        showDialog(
                          context: ctx,
                          builder: (subCtx) => AlertDialog(
                            title: const Text('Thêm lựa chọn con'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: valNameCtrl,
                                  decoration: const InputDecoration(labelText: 'Tên lựa chọn (ví dụ: Trân châu đen)'),
                                ),
                                TextField(
                                  controller: valPriceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Phụ thu thêm (đ, để 0 nếu miễn phí)'),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(subCtx), child: const Text('Hủy')),
                              ElevatedButton(
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
                                child: const Text('Lưu'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                if (localValues.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    children: localValues.map((lv) {
                      return Chip(
                        label: Text('${lv.name} (+${lv.price.toInt()}đ)', style: const TextStyle(fontSize: 12)),
                        onDeleted: () => setDialogState(() => localValues.remove(lv)),
                      );
                    }).toList(),
                  )
                else
                  const Text('Chưa có lựa chọn con nào. Nhấn "Thêm mục" để thêm.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
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
            const SnackBar(content: Text('Cập nhật món ăn & tùy chọn thành công!'), backgroundColor: Colors.green),
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
          options: _options,
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
                title: const Text('Trạng thái kinh doanh (Bật/Tắt món)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_isAvailable ? 'Món đang sẵn sàng phục vụ thực khách' : 'Món hiện đang tạm hết'),
                value: _isAvailable,
                activeThumbColor: Colors.deepOrange,
                onChanged: (val) {
                  setState(() {
                    _isAvailable = val;
                  });
                },
              ),
              const Divider(height: 24),

              // 1. Sizes Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('1. Kích cỡ món ăn (Size)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

              const Divider(height: 32),

              // 2. Options Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('2. Tùy chọn món ăn (Product Options)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _addOptionDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm Option'),
                  ),
                ],
              ),
              if (_options.isNotEmpty)
                Column(
                  children: _options.map((opt) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.tune_rounded, size: 18, color: Colors.deepOrange),
                                    const SizedBox(width: 8),
                                    Text(opt.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: () {
                                    setState(() => _options.remove(opt));
                                  },
                                ),
                              ],
                            ),
                            Text(
                              '${opt.required ? "Bắt buộc chọn" : "Không bắt buộc"} • ${opt.isMultiple ? "Chọn nhiều" : "Chọn 1"}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            if (opt.values.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                children: opt.values.map((v) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('${v.name} (+${v.price.toInt()}đ)', style: const TextStyle(fontSize: 12)),
                                  );
                                }).toList(),
                              )
                            else
                              const Text('Chưa có lựa chọn con', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                )
              else
                Text('Chưa thiết lập tùy chọn (ví dụ: Topping, Mức đường, Mức đá)', style: TextStyle(color: Colors.grey[600], fontSize: 13)),

              const SizedBox(height: 36),

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
                          _isEditing ? 'Cập nhật món ăn & Tùy chọn' : 'Lưu món ăn mới',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

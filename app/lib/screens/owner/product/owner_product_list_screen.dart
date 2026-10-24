import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/product_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../widgets/product_card.dart';
import 'owner_product_form_screen.dart';

class OwnerProductListScreen extends StatefulWidget {
  final String? businessId;

  const OwnerProductListScreen({
    super.key,
    this.businessId,
  });

  @override
  State<OwnerProductListScreen> createState() => _OwnerProductListScreenState();
}

class _OwnerProductListScreenState extends State<OwnerProductListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProducts();
    });
  }

  String? get _resolvedBusinessId {
    if (widget.businessId != null && widget.businessId!.isNotEmpty) {
      return widget.businessId;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return auth.user?.business?['_id']?.toString() ?? auth.user?.business?['id']?.toString();
  }

  void _loadProducts() {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    productProvider.fetchProducts(
      businessId: _resolvedBusinessId,
      includeUnavailable: true,
    );
  }

  void _confirmDelete(BuildContext context, ProductModel product, String token) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa món'),
        content: Text('Bạn có chắc chắn muốn xóa món "${product.name}" khỏi thực đơn không? Action này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final productProvider = Provider.of<ProductProvider>(context, listen: false);
              try {
                await productProvider.deleteProduct(product.id, token);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã xóa món "${product.name}" thành công')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Không thể xóa: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Thực đơn & Món ăn', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: Column(
        children: [
          // Menu Management Header Card
          Container(
            margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Color(0xFF2563EB), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Thực đơn chính',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('ACTIVE', style: TextStyle(color: Color(0xFF15803D), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${productProvider.products.length} món ăn • ${productProvider.categories.length > 1 ? productProvider.categories.length - 1 : 1} danh mục',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Category Filter Bar
          if (productProvider.categories.length > 1)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: productProvider.categories.length,
                itemBuilder: (ctx, idx) {
                  final cat = productProvider.categories[idx];
                  final isSel = productProvider.selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSel,
                      selectedColor: Colors.deepOrange,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : Colors.black87,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) => productProvider.selectCategory(cat),
                    ),
                  );
                },
              ),
            ),

          // Product List
          Expanded(
            child: productProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : productProvider.filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            const Text(
                              'Chưa có món ăn nào trong thực đơn',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OwnerProductFormScreen(
                                      businessId: _resolvedBusinessId,
                                    ),
                                  ),
                                ).then((_) => _loadProducts());
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Thêm món đầu tiên'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: productProvider.filteredProducts.length,
                        itemBuilder: (ctx, idx) {
                          final prod = productProvider.filteredProducts[idx];
                          return ProductCard(
                            product: prod,
                            isOwnerView: true,
                            onToggleAvailable: (val) {
                              productProvider.toggleAvailability(prod.id, prod.isAvailable, token);
                            },
                            onEdit: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OwnerProductFormScreen(
                                    product: prod,
                                    businessId: _resolvedBusinessId,
                                  ),
                                ),
                              ).then((_) => _loadProducts());
                            },
                            onDelete: () => _confirmDelete(context, prod, token),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OwnerProductFormScreen(
                businessId: _resolvedBusinessId,
              ),
            ),
          ).then((_) => _loadProducts());
        },
        backgroundColor: Colors.deepOrange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Thêm món mới', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

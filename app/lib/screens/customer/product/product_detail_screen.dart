import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/cart_item_model.dart';
import '../../../models/product_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/booking_service.dart';
import '../../../services/restaurant_service.dart';
import '../../../widgets/product_quantity_selector.dart';
import '../widgets/restaurant_modals.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;
  final String businessId;
  final String businessName;
  final String? branchId;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.businessId,
    required this.businessName,
    this.branchId,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  ProductSize? _selectedSize;
  final Map<String, Set<ProductOptionValue>> _selectedOptionsMap = {};

  @override
  void initState() {
    super.initState();
    // Default size selection
    if (widget.product.sizes.isNotEmpty) {
      _selectedSize = widget.product.sizes.firstWhere(
        (s) => s.isDefault,
        orElse: () => widget.product.sizes.first,
      );
    }
  }

  double get _currentUnitPrice {
    double base = _selectedSize != null ? _selectedSize!.price : widget.product.price;
    double optionsPrice = 0.0;
    _selectedOptionsMap.forEach((_, valueSet) {
      for (var val in valueSet) {
        optionsPrice += val.price;
      }
    });
    return base + optionsPrice;
  }

  double get _totalPrice => _currentUnitPrice * _quantity;

  String _formatPrice(double price) {
    final intPrice = price.toInt();
    return '${intPrice.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')}đ';
  }

  void _showRequireBookingDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Yêu cầu Đặt bàn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Bạn chưa có lịch đặt bàn tại "${widget.businessName}". Quy định nhà hàng yêu cầu khách hàng phải đặt bàn thành công trước khi chọn món!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final restaurantService = RestaurantService();
              try {
                final list = await restaurantService.getRestaurants(city: 'Tất cả');
                final r = list.firstWhere(
                  (item) => item.id == widget.businessId,
                  orElse: () => list.first,
                );
                if (mounted) {
                  RestaurantModals.showBooking(context, r, restaurantService: restaurantService);
                }
              } catch (_) {}
            },
            icon: const Icon(Icons.table_restaurant_rounded, size: 18),
            label: const Text('Đặt bàn ngay'),
          ),
        ],
      ),
    );
  }

  void _onAddToCart() async {
    // Check if customer has an active booking for this restaurant
    try {
      final bookingService = BookingService();
      final myBookings = await bookingService.getMyBookings();
      final hasActiveBooking = myBookings.any((b) =>
          b.businessId == widget.businessId &&
          (b.isPending || b.isConfirmed || b.isCheckedIn));

      if (!hasActiveBooking) {
        if (!mounted) return;
        _showRequireBookingDialog();
        return;
      }
    } catch (_) {}

    // Validate required options
    for (var opt in widget.product.options) {
      if (opt.required) {
        final selectedVals = _selectedOptionsMap[opt.name];
        if (selectedVals == null || selectedVals.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vui lòng chọn: ${opt.name}'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
      }
    }

    // Convert options map to SelectedOption list
    final List<SelectedOption> flattenedOptions = [];
    _selectedOptionsMap.forEach((optName, valSet) {
      for (var val in valSet) {
        flattenedOptions.add(
          SelectedOption(
            name: optName,
            value: val.name,
            additionalPrice: val.price,
          ),
        );
      }
    });

    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    final result = cartProvider.addItem(
      product: widget.product,
      targetBusinessId: widget.businessId,
      targetBusinessName: widget.businessName,
      targetBranchId: widget.branchId,
      quantity: _quantity,
      selectedSize: _selectedSize,
      selectedOptions: flattenedOptions,
    );

    if (result == AddToCartResult.differentBusinessConflict) {
      _showBusinessConflictDialog(flattenedOptions);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm "${widget.product.name}" vào giỏ hàng!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _showBusinessConflictDialog(List<SelectedOption> flattenedOptions) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi nhà hàng?'),
        content: Text(
          'Giỏ hàng của bạn đang có sản phẩm từ quán "${Provider.of<CartProvider>(context, listen: false).businessName}". Bạn có muốn xóa giỏ hàng cũ để thêm món từ "${widget.businessName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
            onPressed: () {
              Navigator.pop(ctx);
              final cartProvider = Provider.of<CartProvider>(context, listen: false);
              cartProvider.resetCartForNewBusiness(
                widget.businessId,
                widget.businessName,
                brId: widget.branchId,
                product: widget.product,
                quantity: _quantity,
                selectedSize: _selectedSize,
                selectedOptions: flattenedOptions,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã tạo giỏ hàng mới thành công!'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('Đồng ý', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Banner & App Bar
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: widget.product.imageUrl.isNotEmpty
                      ? Image.network(
                          widget.product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
              ),

              // Content Details
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Badge
                      if (widget.product.category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.product.category,
                            style: const TextStyle(
                              color: Colors.deepOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),

                      // Name
                      Text(
                        widget.product.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Price
                      Text(
                        _formatPrice(_currentUnitPrice),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Description
                      if (widget.product.description.isNotEmpty) ...[
                        Text(
                          widget.product.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                        ),
                        const Divider(height: 28),
                      ],

                      // Sizes Section
                      if (widget.product.sizes.isNotEmpty) ...[
                        const Text(
                          'Kích thước (Size)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          children: widget.product.sizes.map((size) {
                            final isSelected = _selectedSize?.name == size.name;
                            return ChoiceChip(
                              label: Text('${size.name} (${_formatPrice(size.price)})'),
                              selected: isSelected,
                              selectedColor: Colors.deepOrange,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (_) {
                                setState(() {
                                  _selectedSize = size;
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const Divider(height: 28),
                      ],

                      // Options Section
                      if (widget.product.options.isNotEmpty) ...[
                        ...widget.product.options.map((opt) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    opt.name,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  if (opt.required)
                                    const Text(
                                      ' *',
                                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ...opt.values.map((val) {
                                final selectedSet = _selectedOptionsMap[opt.name] ?? {};
                                final isChecked = selectedSet.contains(val);

                                if (opt.isMultiple) {
                                  return CheckboxListTile(
                                    title: Text(val.name),
                                    subtitle: val.price > 0 ? Text('+${_formatPrice(val.price)}') : null,
                                    value: isChecked,
                                    activeColor: Colors.deepOrange,
                                    onChanged: (bool? checked) {
                                      setState(() {
                                        final currentSet = _selectedOptionsMap[opt.name] ?? {};
                                        if (checked == true) {
                                          currentSet.add(val);
                                        } else {
                                          currentSet.remove(val);
                                        }
                                        _selectedOptionsMap[opt.name] = currentSet;
                                      });
                                    },
                                  );
                                } else {
                                  return RadioListTile<ProductOptionValue>(
                                    title: Text(val.name),
                                    subtitle: val.price > 0 ? Text('+${_formatPrice(val.price)}') : null,
                                    value: val,
                                    groupValue: selectedSet.isNotEmpty ? selectedSet.first : null,
                                    activeColor: Colors.deepOrange,
                                    onChanged: (ProductOptionValue? selected) {
                                      setState(() {
                                        if (selected != null) {
                                          _selectedOptionsMap[opt.name] = {selected};
                                        }
                                      });
                                    },
                                  );
                                }
                              }),
                              const Divider(height: 20),
                            ],
                          );
                        }),
                      ],

                      // Quantity Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Số lượng',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          ProductQuantitySelector(
                            quantity: _quantity,
                            onChanged: (newQty) {
                              setState(() {
                                _quantity = newQty;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 100), // Padding for bottom bar
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Bottom Add to Cart Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: widget.product.isAvailable ? _onAddToCart : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      widget.product.isAvailable
                          ? 'Thêm vào giỏ - ${_formatPrice(_totalPrice)}'
                          : 'Sản phẩm tạm hết',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      alignment: Alignment.center,
      child: const Icon(Icons.fastfood, size: 64, color: Colors.grey),
    );
  }
}

import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';

class OrderProvider with ChangeNotifier {
  final OrderService _orderService = OrderService();

  List<OrderModel> _myOrders = [];
  List<OrderModel> _ownerOrders = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<OrderModel> get myOrders => _myOrders;
  List<OrderModel> get ownerOrders => _ownerOrders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Thống kê nhanh cho Owner Dashboard
  int get pendingOrdersCount => _ownerOrders.where((o) => o.isPending).length;
  int get preparingOrdersCount => _ownerOrders.where((o) => o.isPreparing).length;
  int get readyOrdersCount => _ownerOrders.where((o) => o.isReady).length;
  int get servedOrdersCount => _ownerOrders.where((o) => o.isServed).length;
  int get todayOrdersCount => _ownerOrders.length;

  /// Tải danh sách đơn hàng của khách hàng
  Future<void> fetchMyOrders() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _myOrders = await _orderService.getMyOrders();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Tải danh sách đơn hàng cho Chủ quán
  Future<void> fetchOwnerOrders({String? status, String? orderType, bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _ownerOrders = await _orderService.getOwnerOrders(
        status: status,
        orderType: orderType,
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Khách hàng tạo đơn đặt món
  Future<Map<String, dynamic>> createOrder({
    required String businessId,
    String? branchId,
    String? bookingId,
    String? tableId,
    String orderType = 'PRE_ORDER',
    required List<Map<String, dynamic>> items,
    int discount = 0,
    String? note,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _orderService.createOrder(
        businessId: businessId,
        branchId: branchId,
        bookingId: bookingId,
        tableId: tableId,
        orderType: orderType,
        items: items,
        discount: discount,
        note: note,
      );

      if (res['success'] == true && res['order'] is OrderModel) {
        _myOrders.insert(0, res['order'] as OrderModel);
      }

      return res;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Chủ quán cập nhật trạng thái đơn hàng (CONFIRMED, PREPARING, READY, SERVED, COMPLETED, CANCELLED)
  Future<Map<String, dynamic>> updateOrderStatus(String id, String status) async {
    final res = await _orderService.updateOrderStatus(id, status);

    if (res['success'] == true && res['order'] is OrderModel) {
      final updated = res['order'] as OrderModel;
      final idx = _ownerOrders.indexWhere((o) => o.id == id);
      if (idx != -1) {
        _ownerOrders[idx] = updated;
      }
      notifyListeners();
    }

    return res;
  }

  /// Xem chi tiết 1 đơn hàng
  Future<OrderModel?> getOrderById(String id) async {
    return await _orderService.getOrderById(id);
  }
}

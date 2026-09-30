import { Order, Notification, Cart, UserInteraction } from '../models/index.js';

const generateOrderCode = () => {
  const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const randomNum = Math.floor(1000 + Math.random() * 9000);
  return `FCO${dateStr}${randomNum}`;
};

// @desc    Create new order (PRE_ORDER or DINE_IN)
// @route   POST /api/orders
// @access  Private (Customer)
export const createOrder = async (req, res) => {
  try {
    const {
      businessId,
      branchId,
      bookingId,
      tableId,
      orderType = 'PRE_ORDER',
      items,
      discount = 0,
      note,
    } = req.body;

    if (!items || items.length === 0) {
      return res.status(400).json({ success: false, message: 'Danh sách món ăn không được trống' });
    }

    let subtotal = 0;
    const formattedItems = items.map((item) => {
      const baseUnitPrice = item.selectedSize?.price != null ? Number(item.selectedSize.price) : Number(item.unitPrice || 0);
      const optionsPrice = item.selectedOptions?.reduce((sum, opt) => sum + (Number(opt.additionalPrice) || 0), 0) || 0;
      const itemSubtotal = (baseUnitPrice + optionsPrice) * item.quantity;
      subtotal += itemSubtotal;
      return {
        productId: item.productId,
        productName: item.productName,
        unitPrice: baseUnitPrice,
        quantity: item.quantity,
        selectedSize: item.selectedSize || undefined,
        selectedOptions: item.selectedOptions || [],
        subtotal: itemSubtotal,
      };
    });

    const total = Math.max(0, subtotal - discount);
    const orderCode = generateOrderCode();

    const order = await Order.create({
      orderCode,
      userId: req.user._id,
      businessId,
      branchId,
      bookingId,
      tableId,
      orderType,
      items: formattedItems,
      subtotal,
      discount,
      total,
      note,
      status: 'PENDING',
    });

    // Clear cart if pre-order placed
    await Cart.findOneAndDelete({ userId: req.user._id, branchId });

    // Automatically record interaction for personalized recommendations
    UserInteraction.create({
      userId: req.user._id,
      businessId,
      branchId,
      type: 'ORDER',
      metadata: { total, itemCount: formattedItems.length, orderType },
    }).catch(() => {});

    res.status(201).json({
      success: true,
      data: order,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get current user's orders
// @route   GET /api/orders/my
// @access  Private
export const getMyOrders = async (req, res) => {
  try {
    const orders = await Order.find({ userId: req.user._id })
      .populate('businessId', 'name logoUrl')
      .populate('branchId', 'name address phone')
      .populate('bookingId', 'bookingCode bookingDate startTime')
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      count: orders.length,
      data: orders,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get orders for branch (Staff / Merchant)
// @route   GET /api/orders/branch/:branchId
// @access  Private (Staff / Owner)
export const getBranchOrders = async (req, res) => {
  try {
    const { status, orderType } = req.query;
    const query = { branchId: req.params.branchId };

    if (status) query.status = status;
    if (orderType) query.orderType = orderType;

    const orders = await Order.find(query)
      .populate('userId', 'fullName phone')
      .populate('tableId', 'name location')
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      count: orders.length,
      data: orders,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update order status
// @route   PUT /api/orders/:id/status
// @access  Private (Staff / Owner)
export const updateOrderStatus = async (req, res) => {
  try {
    const { status } = req.body;
    const order = await Order.findById(req.params.id);

    if (!order) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy đơn hàng' });
    }

    order.status = status;
    await order.save();

    // Map status to notification type
    const notifTypeMap = {
      CONFIRMED: 'ORDER_CONFIRMED',
      PREPARING: 'ORDER_PREPARING',
      READY: 'ORDER_READY',
      COMPLETED: 'ORDER_COMPLETED',
    };

    if (notifTypeMap[status]) {
      await Notification.create({
        userId: order.userId,
        type: notifTypeMap[status],
        title: `Đơn hàng #${order.orderCode} - Trạng thái: ${status}`,
        message: `Đơn hàng của bạn đã cập nhật trạng thái mới thành: ${status}`,
        referenceId: order._id,
      });
    }

    res.json({
      success: true,
      data: order,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

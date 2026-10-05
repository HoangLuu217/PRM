import { randomUUID } from 'node:crypto';
import { operationError } from '../utils/operations.js';
import {
  Order,
  Notification,
  Cart,
  UserInteraction,
  Branch,
  Business,
  Product,
  Menu,
  Booking,
  Table,
} from '../models/index.js';

const generateOrderCode = () => {
  const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const randomNum = randomUUID().replaceAll('-', '').slice(0, 12);
  return `FCO${dateStr}${randomNum}`;
};

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

    if (!['USER', 'CUSTOMER'].includes(req.user.role)) {
      return res.status(403).json({ success: false, message: 'Chỉ khách hàng mới có thể đặt món' });
    }
    if (!businessId || !branchId || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ success: false, message: 'Cần có businessId, branchId và ít nhất một món' });
    }
    if (!['PRE_ORDER', 'DINE_IN', 'PICKUP', 'DELIVERY'].includes(orderType)) {
      return res.status(400).json({ success: false, message: 'Loại đơn hàng không hợp lệ' });
    }

    const branch = await Branch.findById(branchId);
    if (!branch || String(branch.businessId) !== String(businessId) || branch.status !== 'ACTIVE') {
      return res.status(400).json({ success: false, message: 'Chi nhánh không hợp lệ hoặc đang ngừng hoạt động' });
    }
    const business = await Business.findById(businessId);
    if (!business || business.status !== 'APPROVED') {
      return res.status(400).json({ success: false, message: 'Doanh nghiệp hiện không nhận đơn hàng' });
    }

    let selectedTableId = tableId;
    if (bookingId) {
      const booking = await Booking.findOne({
        _id: bookingId,
        userId: req.user._id,
        branchId,
        status: { $in: ['CONFIRMED', 'CHECKED_IN'] },
      });
      if (!booking) {
        return res.status(400).json({ success: false, message: 'Booking không hợp lệ cho đơn hàng này' });
      }
      if (tableId && String(tableId) !== String(booking.tableId)) {
        return res.status(400).json({ success: false, message: 'Table must match the booking' });
      }
      selectedTableId = booking.tableId;
    }
    if (tableId && !(await Table.exists({ _id: tableId, branchId }))) {
      return res.status(400).json({ success: false, message: 'Bàn không thuộc chi nhánh đã chọn' });
    }

    const formattedItems = [];
    let subtotal = 0;
    for (const item of items) {
      if (!item || typeof item !== 'object' || !Array.isArray(item.selectedOptions || [])) {
        return res.status(400).json({ success: false, message: 'Invalid order item or options' });
      }
      const quantity = Number(item.quantity);
      if (!Number.isInteger(quantity) || quantity < 1 || quantity > 99) {
        return res.status(400).json({ success: false, message: 'Số lượng mỗi món phải từ 1 đến 99' });
      }

      const product = await Product.findById(item.productId);
      if (!product || !product.isAvailable) {
        return res.status(400).json({ success: false, message: 'Một món trong đơn không tồn tại hoặc đã hết hàng' });
      }
      const menu = await Menu.findById(product.menuId).select('businessId branchId status');
      const belongsToBranch = menu && menu.status === 'ACTIVE'
        && String(menu.businessId) === String(businessId)
        && (!menu.branchId || String(menu.branchId) === String(branchId))
        && (!product.branchId || String(product.branchId) === String(branchId));
      if (!belongsToBranch) {
        return res.status(400).json({ success: false, message: `Món "${product.name}" không thuộc chi nhánh đã chọn` });
      }

      let unitPrice = product.price;
      let selectedSize;
      if (item.selectedSize) {
        const size = product.sizes.find((candidate) => candidate.name === item.selectedSize.name);
        if (!size) {
          return res.status(400).json({ success: false, message: `Kích cỡ món "${product.name}" không hợp lệ` });
        }
        selectedSize = { name: size.name, price: size.price };
        unitPrice = size.price;
      }

      const selectedOptions = [];
      const selectedPairs = new Set();
      for (const selected of item.selectedOptions || []) {
        if (!selected || typeof selected !== 'object') {
          return res.status(400).json({ success: false, message: 'Invalid product option' });
        }
        const key = JSON.stringify([selected.name, selected.value]);
        if (selectedPairs.has(key)) return res.status(400).json({ success: false, message: 'Duplicate option value' });
        selectedPairs.add(key);
        const option = product.options.find((candidate) => candidate.name === selected.name);
        const value = option?.values.find((candidate) => candidate.name === selected.value);
        if (!value) {
          return res.status(400).json({ success: false, message: `Tùy chọn món "${product.name}" không hợp lệ` });
        }
        if (!option.isMultiple && selectedOptions.some((choice) => choice.name === option.name)) {
          return res.status(400).json({ success: false, message: 'Only one value allowed for this option' });
        }
        selectedOptions.push({
          name: option.name,
          value: value.name,
          additionalPrice: value.price,
        });
      }
      for (const option of product.options) {
        if (option.required && !selectedOptions.some((selected) => selected.name === option.name)) {
          return res.status(400).json({ success: false, message: `Vui lòng chọn ${option.name} cho món "${product.name}"` });
        }
      }

      const itemSubtotal = (unitPrice + selectedOptions.reduce((sum, option) => sum + option.additionalPrice, 0)) * quantity;
      subtotal += itemSubtotal;
      formattedItems.push({
        productId: product._id,
        productName: product.name,
        unitPrice,
        quantity,
        selectedSize,
        selectedOptions,
        subtotal: itemSubtotal,
      });
    }

    const safeDiscount = Number(discount);
    if (!Number.isFinite(safeDiscount) || safeDiscount < 0 || safeDiscount > subtotal) {
      return res.status(400).json({ success: false, message: 'Mức giảm giá không hợp lệ' });
    }
    if (safeDiscount !== 0) {
      return res.status(400).json({ success: false, message: 'Mã giảm giá cần được xác thực từ chương trình khuyến mãi' });
    }

    const order = await Order.create({
      orderCode: generateOrderCode(),
      userId: req.user._id,
      businessId,
      branchId,
      bookingId,
      tableId: selectedTableId,
      orderType,
      items: formattedItems,
      subtotal,
      discount: safeDiscount,
      total: subtotal - safeDiscount,
      note,
      status: 'PENDING',
    });

    await Cart.findOneAndDelete({ userId: req.user._id, branchId }).catch((error) => console.error('Cart cleanup failed:', error.message));
    UserInteraction.create({
      userId: req.user._id,
      businessId,
      branchId,
      type: 'ORDER',
      metadata: { total: order.total, itemCount: formattedItems.length, orderType },
    }).catch((error) => console.error('Failed to record order interaction:', error.message));

    res.status(201).json({ success: true, data: order });
  } catch (error) {
    return operationError(res, error);
  }
};

export const getMyOrders = async (req, res) => {
  try {
    const orders = await Order.find({ userId: req.user._id })
      .populate('businessId', 'name logoUrl')
      .populate('branchId', 'name address phone')
      .populate('bookingId', 'bookingCode bookingDate startTime')
      .sort({ createdAt: -1 });

    res.json({ success: true, count: orders.length, data: orders });
  } catch (error) {
    return operationError(res, error);
  }
};

export const getOrderById = async (req, res) => {
  try {
    const order = await Order.findById(req.params.id)
      .populate('businessId', 'name logoUrl')
      .populate('branchId', 'name address phone')
      .populate('bookingId', 'bookingCode bookingDate startTime')
      .populate('tableId', 'name location');
    if (!order) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy đơn hàng' });
    }

    const isCustomer = String(order.userId) === String(req.user._id);
    const isOwner = req.user.role === 'ADMIN'
      || (order.businessId && await Business.exists({ _id: order.businessId._id, ownerId: req.user._id }));
    if (!isCustomer && !isOwner) {
      return res.status(403).json({ success: false, message: 'Bạn không có quyền xem đơn hàng này' });
    }

    res.json({ success: true, data: order });
  } catch (error) {
    return operationError(res, error);
  }
};

export const getBranchOrders = async (req, res) => {
  try {
    const { status, orderType } = req.query;
    const branchId = req.params.branchId || req.query.branchId;
    if (branchId && req.user.role !== 'ADMIN'
      && !(await Branch.exists({ _id: branchId, businessId: { $in: req.ownerBusinessIds || [] } }))) {
      return res.status(403).json({ success: false, message: 'Bạn không có quyền xem đơn hàng của chi nhánh này' });
    }
    const ownerBranchIds = branchId
      ? [branchId]
      : await Branch.find(req.user.role === 'ADMIN' ? {} : { businessId: { $in: req.ownerBusinessIds || [] } }).distinct('_id');
    const query = { branchId: { $in: ownerBranchIds } };

    if (status) query.status = status;
    if (orderType) query.orderType = orderType;

    const orders = await Order.find(query)
      .populate('userId', 'fullName phone')
      .populate('tableId', 'name location')
      .sort({ createdAt: -1 });

    res.json({ success: true, count: orders.length, data: orders });
  } catch (error) {
    return operationError(res, error);
  }
};

export const updateOrderStatus = async (req, res) => {
  try {
    const { status } = req.body;
    const order = await Order.findById(req.params.id);
    if (!order) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy đơn hàng' });
    }

    const transitions = {
      PENDING: ['CONFIRMED', 'CANCELLED'],
      CONFIRMED: ['PREPARING', 'CANCELLED'],
      PREPARING: ['READY'],
      READY: ['SERVED'],
      SERVED: ['COMPLETED'],
      COMPLETED: [],
      CANCELLED: [],
    };
    if (!transitions[order.status]?.includes(status)) {
      return res.status(400).json({
        success: false,
        message: `Không thể chuyển trạng thái đơn hàng từ ${order.status} sang ${status}`,
      });
    }

    const isOwner = req.user.role === 'ADMIN'
      || await Business.exists({ _id: order.businessId, ownerId: req.user._id });
    if (!isOwner) return res.status(403).json({ success: false, message: 'Only the business owner can update this order' });
    const updated = await Order.findOneAndUpdate(
      { _id: order._id, status: order.status }, { status }, { new: true, runValidators: true }
    );
    if (!updated) return res.status(409).json({ success: false, message: 'Order changed; refresh before retrying' });
    order.status = updated.status;

    const notificationType = {
      CONFIRMED: 'ORDER_CONFIRMED',
      PREPARING: 'ORDER_PREPARING',
      READY: 'ORDER_READY',
      SERVED: 'ORDER_SERVED',
      COMPLETED: 'ORDER_COMPLETED',
      CANCELLED: 'ORDER_CANCELLED',
    }[status];
    if (notificationType) {
      await Notification.create({
        userId: order.userId,
        type: notificationType,
        title: `Đơn hàng #${order.orderCode} - Trạng thái: ${status}`,
        message: `Đơn hàng của bạn đã cập nhật trạng thái mới thành: ${status}`,
        referenceId: order._id,
      }).catch((error) => console.error('Order notification failed:', error.message));
    }

    res.json({ success: true, data: order });
  } catch (error) {
    return operationError(res, error);
  }
};

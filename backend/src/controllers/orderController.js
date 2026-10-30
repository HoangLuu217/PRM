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
  Transaction,
  User,
} from '../models/index.js';
import { createPayOSPaymentLink } from '../services/payosService.js';
import { sendPushToUser } from '../services/pushNotificationService.js';

const generateOrderCode = () => {
  const timestampPart = Math.floor(Date.now() / 1000) % 1000000;
  const randomPart = Math.floor(1000 + Math.random() * 9000);
  return Number(`${timestampPart}${randomPart}`);
};

export const createOrder = async (req, res) => {
  try {
    let {
      businessId,
      branchId,
      bookingId,
      tableId,
      orderType = 'PRE_ORDER',
      items,
      discount = 0,
      note,
      paymentMethod = 'CASH',
    } = req.body;

    if (!['USER', 'CUSTOMER'].includes(req.user.role)) {
      return res.status(403).json({ success: false, message: 'Chỉ khách hàng mới có thể đặt món' });
    }

    const isValidObjectId = (id) => typeof id === 'string' && /^[0-9a-fA-F]{24}$/.test(id);

    let selectedTableId = tableId;
    let resolvedBookingId = bookingId;

    // 1. Lấy thông tin từ Đơn Đặt Bàn chuẩn
    if (resolvedBookingId && isValidObjectId(resolvedBookingId)) {
      const booking = await Booking.findOne({
        _id: resolvedBookingId,
        userId: req.user._id,
        status: { $in: ['PENDING', 'CONFIRMED', 'CHECKED_IN'] },
      });
      if (!booking) {
        return res.status(400).json({ success: false, message: 'Đơn đặt bàn không hợp lệ hoặc đã kết thúc/hủy' });
      }
      if (!branchId || !isValidObjectId(branchId)) branchId = booking.branchId ? String(booking.branchId) : null;
      if (!businessId || !isValidObjectId(businessId)) businessId = booking.businessId ? String(booking.businessId) : null;
      selectedTableId = booking.tableId || selectedTableId;
    } else {
      const query = {
        userId: req.user._id,
        status: { $in: ['PENDING', 'CONFIRMED', 'CHECKED_IN'] },
      };
      if (businessId && isValidObjectId(businessId)) query.businessId = businessId;

      const activeBooking = await Booking.findOne(query).sort({ createdAt: -1 });

      if (!activeBooking) {
        return res.status(400).json({
          success: false,
          message: 'Bạn bắt buộc phải đặt bàn tại quán trước khi thực hiện đặt món. Vui lòng đặt bàn trước!',
        });
      }
      resolvedBookingId = activeBooking._id;
      if (!branchId || !isValidObjectId(branchId)) branchId = activeBooking.branchId ? String(activeBooking.branchId) : null;
      if (!businessId || !isValidObjectId(businessId)) businessId = activeBooking.businessId ? String(activeBooking.businessId) : null;
      selectedTableId = activeBooking.tableId || selectedTableId;
    }

    // 2. Tự động truy vấn hoặc tạo chi nhánh chuẩn cho nhà hàng
    let business = (businessId && isValidObjectId(businessId)) ? await Business.findById(businessId) : null;
    let branch = (branchId && isValidObjectId(branchId)) ? await Branch.findById(branchId) : null;

    if (!branch && businessId && isValidObjectId(businessId)) {
      branch = await Branch.findOne({ businessId, status: 'ACTIVE' }) || await Branch.findOne({ businessId });
      if (!branch) {
        branch = await Branch.create({
          businessId,
          name: `${business?.name || 'Nhà hàng'} - Chi nhánh chính`,
          address: business?.address || { street: 'Địa chỉ', district: 'Đà Nẵng', city: 'Đà Nẵng' },
          status: 'ACTIVE',
        });
      }
      if (branch) branchId = String(branch._id);
    }

    if (!business && branch?.businessId) {
      business = await Business.findById(branch.businessId);
      if (business) businessId = String(business._id);
    }

    if (!businessId || !isValidObjectId(businessId) || !branchId || !isValidObjectId(branchId) || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ success: false, message: 'Cần có businessId, branchId hợp lệ và ít nhất một món' });
    }

    if (!['PRE_ORDER', 'DINE_IN', 'PICKUP', 'DELIVERY'].includes(orderType)) {
      return res.status(400).json({ success: false, message: 'Loại đơn hàng không hợp lệ' });
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
      const belongsToBusiness = (menu && String(menu.businessId) === String(businessId))
        || (product && String(product.businessId) === String(businessId));

      if (!belongsToBusiness) {
        // Món thuộc nhà hàng khác -> Bỏ qua không tính vào đơn hàng này
        continue;
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

    const numericOrderCode = generateOrderCode();

    const order = await Order.create({
      orderCode: numericOrderCode,
      userId: req.user._id,
      businessId,
      branchId,
      bookingId: resolvedBookingId,
      tableId: selectedTableId,
      orderType,
      items: formattedItems,
      subtotal,
      discount: safeDiscount,
      total: subtotal - safeDiscount,
      note,
      paymentMethod,
      paymentStatus: 'PENDING',
      status: 'PENDING',
    });

    if (resolvedBookingId) {
      await Booking.findByIdAndUpdate(resolvedBookingId, { preOrderId: order._id });
    }

    // Register PayOS Payment Link & Transaction
    if (paymentMethod === 'PAYOS_QR' || paymentMethod === 'BANK_TRANSFER') {
      try {
        const user = await User.findById(req.user._id);
        const description = `DAT MON ${numericOrderCode}`.slice(0, 25);
        const paymentResult = await createPayOSPaymentLink({
          orderCode: numericOrderCode,
          amount: order.total,
          description,
          items: formattedItems.map((it) => ({
            name: it.productName.slice(0, 50),
            quantity: it.quantity,
            price: it.unitPrice,
          })),
          buyerName: user?.fullName || 'Khách hàng',
          buyerEmail: user?.email || '',
          buyerPhone: user?.phone || '',
        });

        const commissionRate = 10;
        const commissionAmount = Math.round((order.total * commissionRate) / 100);
        const merchantAmount = order.total - commissionAmount;

        await Transaction.create({
          orderCode: numericOrderCode,
          userId: req.user._id,
          businessId,
          branchId,
          amount: order.total,
          commissionRate,
          commissionAmount,
          merchantAmount,
          paymentMethod: 'PAYOS_VIETQR',
          status: 'PENDING',
          description,
          payosPaymentLinkId: paymentResult.paymentLinkId,
          payosCheckoutUrl: paymentResult.checkoutUrl,
          payosQrCode: paymentResult.qrCode,
        });
      } catch (payosErr) {
        console.warn('Register PayOS Payment Link warning:', payosErr.message);
      }
    }

    await Cart.findOneAndDelete({ userId: req.user._id, branchId }).catch((error) => console.error('Cart cleanup failed:', error.message));
    UserInteraction.create({
      userId: req.user._id,
      businessId,
      branchId,
      type: 'ORDER',
      metadata: { total: order.total, itemCount: formattedItems.length, orderType },
    }).catch((error) => console.error('Failed to record order interaction:', error.message));

    // 1. Tạo Notification cho Khách hàng & Gửi Push Notification
    Notification.create({
      userId: req.user._id,
      businessId,
      type: 'ORDER_CREATED',
      referenceId: order._id,
      title: `Đặt món thành công #${order.orderCode}`,
      message: `Đơn hàng của bạn trị giá ${order.total.toLocaleString('vi-VN')}đ đã được gửi đến nhà hàng.`,
    }).catch((err) => console.error('Order notif customer err:', err));

    sendPushToUser(
      req.user._id,
      `Đặt món thành công #${order.orderCode}`,
      `Đơn hàng của bạn trị giá ${order.total.toLocaleString('vi-VN')}đ đã được gửi đến nhà hàng.`,
      { orderId: String(order._id), orderCode: String(order.orderCode), type: 'ORDER_CREATED' }
    ).catch(() => {});

    // 2. Tạo Notification & Gửi Push Notification cho Chủ Quán
    try {
      const biz = await Business.findById(businessId).select('ownerId name');
      let ownerUserId = biz?.ownerId;
      if (!ownerUserId) {
        const anyOwner = await User.findOne({ role: { $in: ['MERCHANT', 'OWNER'] } });
        if (anyOwner) ownerUserId = anyOwner._id;
      }
      if (ownerUserId) {
        Notification.create({
          userId: ownerUserId,
          businessId,
          type: 'NEW_ORDER_ALERT',
          referenceId: order._id,
          title: `Đơn gọi món mới #${order.orderCode}`,
          message: `Khách hàng vừa đặt đơn mới trị giá ${order.total.toLocaleString('vi-VN')}đ.`,
        }).catch((err) => console.error('Order notif owner err:', err));

        sendPushToUser(
          ownerUserId,
          `Đơn gọi món mới #${order.orderCode}`,
          `Khách hàng vừa đặt đơn mới trị giá ${order.total.toLocaleString('vi-VN')}đ.`,
          { orderId: String(order._id), orderCode: String(order.orderCode), type: 'NEW_ORDER' }
        ).catch(() => {});
      }
    } catch (notifErr) {
      console.warn('Order notification owner warning:', notifErr.message);
    }

    const orderData = order.toObject();
    if (typeof paymentResult !== 'undefined' && paymentResult) {
      orderData.payosData = {
        accountNumber: paymentResult.accountNumber,
        accountName: paymentResult.accountName,
        bin: paymentResult.bin,
        qrCode: paymentResult.qrCode,
        checkoutUrl: paymentResult.checkoutUrl,
      };
    }

    res.status(201).json({ success: true, data: orderData });
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
      .populate('branchId', 'name address phone')
      .populate('bookingId', 'bookingCode bookingDate startTime')
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

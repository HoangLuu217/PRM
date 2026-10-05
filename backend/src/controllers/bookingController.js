import mongoose from 'mongoose';
import { randomUUID } from 'node:crypto';
import { fail, validDate, validTime, overlapFilter } from '../utils/operations.js';
import { operationError } from '../utils/operations.js';
import { Booking, Branch, Business, Notification, Table, Order, UserInteraction } from '../models/index.js';
import { emitBookingUpdate } from '../socket.js';

// Helper to generate unique booking code FCBYYYYMMXXXX
const generateBookingCode = () => {
  const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const randomNum = randomUUID().replaceAll('-', '').slice(0, 12);
  return `FCB${dateStr}${randomNum}`;
};

// @desc    Create new booking
// @route   POST /api/bookings
// @access  Private (Customer)
export const createBooking = async (req, res) => {
  try {
    const {
      businessId,
      branchId,
      tableId,
      bookingDate,
      startTime,
      endTime = '23:59',
      guestCount = 2,
      note,
      preOrderId,
    } = req.body;

    if (!['USER', 'CUSTOMER'].includes(req.user.role)) {
      return res.status(403).json({ success: false, message: 'Chỉ khách hàng mới có thể đặt bàn' });
    }
    if (!businessId || !branchId || !bookingDate || !startTime) {
      return res.status(400).json({ success: false, message: 'Thiếu businessId, branchId, bookingDate hoặc startTime' });
    }
    if (!validDate(bookingDate) || !validTime(startTime) || !validTime(endTime) || endTime <= startTime) {
      return res.status(400).json({ success: false, message: 'Invalid booking date or time range' });
    }
    if (!Number.isInteger(Number(guestCount)) || Number(guestCount) < 1) {
      return res.status(400).json({ success: false, message: 'Số khách phải là số nguyên lớn hơn 0' });
    }

    const [branch, business] = await Promise.all([
      Branch.findById(branchId),
      Business.findById(businessId),
    ]);
    if (!branch || !business || String(branch.businessId) !== String(business._id)) {
      return res.status(400).json({ success: false, message: 'Chi nhánh không thuộc doanh nghiệp đã chọn' });
    }
    if (branch.status !== 'ACTIVE' || business.status !== 'APPROVED' || !business.isBookingEnabled) {
      return res.status(400).json({ success: false, message: 'Chi nhánh hiện không nhận đặt bàn' });
    }
    if (tableId) {
      const table = await Table.findOne({ _id: tableId, branchId, status: { $in: ['AVAILABLE', 'RESERVED'] } });
      if (!table || table.capacity < Number(guestCount)) {
        return res.status(400).json({ success: false, message: 'Bàn không khả dụng hoặc không đủ chỗ cho số khách' });
      }
    }

    if (new Date(bookingDate + 'T' + startTime + ':00+07:00') <= new Date()) {
      return res.status(400).json({ success: false, message: 'Booking must be in the future (Asia/Ho_Chi_Minh)' });
    }
    if (tableId && await Booking.exists(overlapFilter({ tableId, bookingDate, startTime, endTime }))) {
      return res.status(409).json({ success: false, message: 'Table is already booked for this time range' });
    }
    if (preOrderId && !(await Order.exists({
      _id: preOrderId, userId: req.user._id, branchId, businessId, status: { $ne: 'CANCELLED' },
    }))) return res.status(400).json({ success: false, message: 'Invalid pre-order for this booking' });
    const bookingCode = generateBookingCode();

    // Check Business Subscription Booking Limits
    const maxBookings = business.subscription?.features?.maxBookingsPerMonth ?? 30;
    const startOfMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
    const currentMonthBookings = await Booking.countDocuments({
      businessId,
      createdAt: { $gte: startOfMonth },
      status: { $ne: 'CANCELLED' },
    });

    if (currentMonthBookings >= maxBookings) {
      return res.status(403).json({
        success: false,
        message: `Nhà hàng hiện đã đạt hạn mức nhận ${maxBookings} lượt đặt bàn trong tháng này (Gói ${business.subscription?.plan || 'STARTER'}).`,
        requiresUpgrade: true,
      });
    }

    const booking = await Booking.create({
      userId: req.user._id,
      businessId,
      branchId,
      tableId,
      bookingCode,
      bookingDate,
      startTime,
      endTime,
      guestCount: Number(guestCount),
      note,
      preOrderId,
      depositRequired: false,
      depositAmount: 0,
      depositStatus: 'NONE',
      status: 'PENDING',
    });

    // Phát tín hiệu Realtime cho Merchant Dashboard nhận thông báo đặt bàn tức thời
    emitBookingUpdate(businessId, booking, 'created');

    // Automatically record interaction for personalized recommendations
    UserInteraction.create({
      userId: req.user._id,
      businessId,
      branchId,
      type: 'BOOKING',
      metadata: { guestCount, bookingDate, startTime },
    }).catch(() => {});

    res.status(201).json({
      success: true,
      data: booking,
    });
  } catch (error) {
    return operationError(res, error);
  }
};

// @desc    Get current user's bookings
// @route   GET /api/bookings/my
// @access  Private
export const getMyBookings = async (req, res) => {
  try {
    const bookings = await Booking.find({ userId: req.user._id })
      .populate('businessId', 'name logoUrl categories slug address coverUrl')
      .populate('branchId', 'name address phone')
      .populate('tableId', 'name capacity location')
      .populate('preOrderId')
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      count: bookings.length,
      data: bookings,
    });
  } catch (error) {
    return operationError(res, error);
  }
};

export const getBookingById = async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id)
      .populate('businessId', 'name logoUrl')
      .populate('branchId', 'name address phone')
      .populate('tableId', 'name capacity location status')
      .populate('preOrderId');

    if (!booking) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy thông tin đặt bàn' });
    }

    const isCustomer = String(booking.userId) === String(req.user._id);
    const isAdmin = req.user.role === 'ADMIN';
    const isOwner = isAdmin || (booking.businessId && await Business.exists({ _id: booking.businessId._id, ownerId: req.user._id }));
    if (!isCustomer && !isOwner) {
      return res.status(403).json({ success: false, message: 'Bạn không có quyền xem đặt bàn này' });
    }

    res.json({ success: true, data: booking });
  } catch (error) {
    return operationError(res, error);
  }
};

// @desc    Get bookings for owned branches
// @route   GET /api/bookings/branch/:branchId
// @access  Private (Owner / Admin)
export const getBranchBookings = async (req, res) => {
  try {
    const { status, bookingDate } = req.query;
    const branchId = req.params.branchId || req.query.branchId;
    if (branchId && req.user.role !== 'ADMIN'
      && !(await Branch.exists({ _id: branchId, businessId: { $in: req.ownerBusinessIds || [] } }))) {
      return res.status(403).json({ success: false, message: 'Bạn không có quyền xem booking của chi nhánh này' });
    }
    const branchFilter = branchId
      ? [branchId]
      : await Branch.find(req.user.role === 'ADMIN' ? {} : { businessId: { $in: req.ownerBusinessIds || [] } }).distinct('_id');
    const query = { branchId: { $in: branchFilter } };

    if (status) query.status = status;
    if (bookingDate) query.bookingDate = bookingDate;

    const bookings = await Booking.find(query)
      .populate('userId', 'fullName phone avatarUrl')
      .populate('tableId', 'name capacity location status')
      .populate('preOrderId')
      .sort({ bookingDate: 1, startTime: 1 });

    res.json({
      success: true,
      count: bookings.length,
      data: bookings,
    });
  } catch (error) {
    return operationError(res, error);
  }
};

// @desc    Update booking status (Confirm / Reject / Cancel)
// @route   PUT /api/bookings/:id/status
// @access  Private
export const updateBookingStatus = async (req, res) => {
  try {
    let booking;
    await mongoose.connection.transaction(async (session) => {
      booking = await Booking.findById(req.params.id).session(session);
      if (!booking) fail(404, 'Booking not found');
      const isOwner = req.user.role === 'ADMIN'
        || await Business.exists({ _id: booking.businessId, ownerId: req.user._id }).session(session);
      const isCustomer = String(booking.userId) === String(req.user._id);
      const { status, tableId } = req.body;
      if (!isOwner && (!isCustomer || status !== 'CANCELLED' || !['PENDING', 'CONFIRMED'].includes(booking.status))) {
        fail(403, 'Only the booking customer can cancel; other operations require the owner');
      }
      const transitions = {
        PENDING: ['CONFIRMED', 'REJECTED', 'CANCELLED'],
        CONFIRMED: ['CHECKED_IN', 'CANCELLED'], CHECKED_IN: ['COMPLETED'],
        REJECTED: [], CANCELLED: [], COMPLETED: [],
      };
      if (!transitions[booking.status]?.includes(status)) fail(400, 'Invalid booking transition');
      const previousStatus = booking.status;
      if (status === 'CONFIRMED') {
        const targetTableId = tableId || booking.tableId;
        if (!targetTableId) fail(400, 'Select a table before confirming');
        const table = await Table.findOne({ _id: targetTableId, branchId: booking.branchId }).session(session);
        if (!table || table.capacity < booking.guestCount) fail(400, 'Table not found or capacity too small');
        if (!['AVAILABLE', 'RESERVED'].includes(table.status)) fail(409, 'Table unavailable');
        booking.tableId = table._id;
        if (await Booking.exists({
          ...overlapFilter(booking), _id: { $ne: booking._id },
        }).session(session)) fail(409, 'Table is already reserved for this time range');
        // Write the shared table to serialize competing confirmations.
        table.status = 'RESERVED';
        table.markModified('status');
        await table.save({ session });
      }
      if (status === 'CHECKED_IN') {
        if (!booking.tableId) fail(400, 'Booking has no table');
        const table = await Table.findOneAndUpdate(
          { _id: booking.tableId, branchId: booking.branchId, status: 'RESERVED' },
          { status: 'UNAVAILABLE' }, { new: true, session }
        );
        if (!table) fail(409, 'Table is no longer reserved');
        booking.checkedInAt = new Date();
      }
      booking.status = status;
      if (status === 'COMPLETED') booking.completedAt = new Date();
      await booking.save({ session });
      // Cancelling a pending booking must not release another reservation.
      if (booking.tableId && (
        status === 'COMPLETED' || (status === 'CANCELLED' && previousStatus === 'CONFIRMED')
      )) {
        const occupied = await Booking.exists({
          tableId: booking.tableId, _id: { $ne: booking._id }, status: 'CHECKED_IN',
        }).session(session);
        const reserved = await Booking.exists({
          tableId: booking.tableId, _id: { $ne: booking._id }, status: 'CONFIRMED',
        }).session(session);
        await Table.findByIdAndUpdate(booking.tableId, {
          status: occupied ? 'UNAVAILABLE' : reserved ? 'RESERVED' : 'AVAILABLE',
        }, { session });
      }
    });
    await booking.populate('tableId', 'name capacity location status');
    const type = {
      CONFIRMED: 'BOOKING_CONFIRMED', REJECTED: 'BOOKING_REJECTED',
      CANCELLED: 'BOOKING_CANCELLED', CHECKED_IN: 'BOOKING_CHECKED_IN', COMPLETED: 'BOOKING_COMPLETED',
    }[booking.status];
    await Notification.create({
      userId: booking.userId, type, referenceId: booking._id,
      title: 'Booking #' + booking.bookingCode + ': ' + booking.status,
      message: 'Booking on ' + booking.bookingDate + ' at ' + booking.startTime + ': ' + booking.status,
    }).catch((error) => console.error('Booking notification failed:', error.message));
    emitBookingUpdate(booking.businessId, booking, 'updated');
    res.json({ success: true, data: booking });
  } catch (error) { return operationError(res, error); }
};
export const checkInBooking = (req, res) => {
  req.body = { ...req.body, status: 'CHECKED_IN' };
  return updateBookingStatus(req, res);
};

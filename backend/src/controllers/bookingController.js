import { Booking, Branch, Notification, Table, UserInteraction } from '../models/index.js';
import { emitBookingUpdate } from '../socket.js';

// Helper to generate unique booking code FCBYYYYMMXXXX
const generateBookingCode = () => {
  const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const randomNum = Math.floor(1000 + Math.random() * 9000);
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
      endTime,
      guestCount = 2,
      note,
      preOrderId,
    } = req.body;

    const bookingCode = generateBookingCode();

    // Check Business Subscription Booking Limits
    const business = await Business.findById(businessId);
    if (business) {
      const maxBookings = business.subscription?.features?.maxBookingsPerMonth || 30;
      const startOfMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
      const currentMonthBookings = await Booking.countDocuments({
        businessId,
        createdAt: { $gte: startOfMonth },
        status: { $ne: 'CANCELLED' },
      });

      if (currentMonthBookings >= maxBookings) {
        return res.status(403).json({
          success: false,
          message: `Nhà hàng hiện đã đạt hạn mức nhận ${maxBookings} lượt đặt bàn trong tháng này (Gói ${business.subscription?.plan || 'STARTER'}). Chủ quán vui lòng nâng cấp gói PRO VIP để nhận đặt bàn không giới hạn!`,
          requiresUpgrade: true,
        });
      }
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
    res.status(500).json({ success: false, message: error.message });
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
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get bookings for branch (Staff / Merchant)
// @route   GET /api/bookings/branch/:branchId
// @access  Private (Staff / Owner)
export const getBranchBookings = async (req, res) => {
  try {
    const { status, bookingDate } = req.query;
    const query = { branchId: req.params.branchId };

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
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update booking status (Confirm / Reject / Cancel)
// @route   PUT /api/bookings/:id/status
// @access  Private
export const updateBookingStatus = async (req, res) => {
  try {
    const { status, tableId } = req.body;
    const booking = await Booking.findById(req.params.id);

    if (!booking) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy thông tin đặt bàn' });
    }

    if (status === 'CONFIRMED') {
      const targetTableId = tableId || booking.tableId;
      if (!targetTableId) {
        return res.status(400).json({
          success: false,
          message: 'Quán phải chọn bàn có sẵn để duyệt đặt bàn!',
        });
      }

      const targetTable = await Table.findById(targetTableId);
      if (!targetTable) {
        return res.status(404).json({
          success: false,
          message: 'Bàn được chọn không tồn tại trong hệ thống',
        });
      }

      // Check if table is available (or if already assigned to this booking)
      if (
        targetTable.status !== 'AVAILABLE' &&
        String(booking.tableId) !== String(targetTable._id)
      ) {
        return res.status(400).json({
          success: false,
          message: `Bàn ${targetTable.name} hiện không ở trạng thái trống (Trạng thái: ${targetTable.status}). Vui lòng chọn bàn có sẵn khác!`,
        });
      }

      // If booking previously had another table reserved, revert the old table to AVAILABLE
      if (booking.tableId && String(booking.tableId) !== String(targetTable._id)) {
        await Table.findOneAndUpdate(
          { _id: booking.tableId, status: 'RESERVED' },
          { status: 'AVAILABLE' }
        );
      }

      // Assign table & update table status to RESERVED
      booking.tableId = targetTable._id;
      await Table.findByIdAndUpdate(targetTable._id, { status: 'RESERVED' });
    } else if (status === 'REJECTED' || status === 'CANCELLED') {
      // If booking was rejected/cancelled, free up the table if it was RESERVED
      if (booking.tableId) {
        await Table.findOneAndUpdate(
          { _id: booking.tableId, status: 'RESERVED' },
          { status: 'AVAILABLE' }
        );
      }
    } else if (status === 'CHECKED_IN') {
      booking.checkedInAt = new Date();
      if (booking.tableId) {
        await Table.findByIdAndUpdate(booking.tableId, { status: 'UNAVAILABLE' });
      }
    } else if (status === 'COMPLETED') {
      booking.completedAt = new Date();
      if (booking.tableId) {
        await Table.findOneAndUpdate(
          { _id: booking.tableId, status: { $in: ['RESERVED', 'UNAVAILABLE'] } },
          { status: 'AVAILABLE' }
        );
      }
    }

    booking.status = status;
    await booking.save();

    // Populate for response & realtime notification
    await booking.populate('tableId', 'name capacity location status');
    await booking.populate('userId', 'fullName phone avatarUrl');

    // Create Notification for customer
    await Notification.create({
      userId: booking.userId,
      type: status === 'CONFIRMED' ? 'BOOKING_CONFIRMED' : 'BOOKING_CANCELLED',
      title: `Booking #${booking.bookingCode} ${status === 'CONFIRMED' ? 'đã được xác nhận' : 'đã cập nhật trạng thái: ' + status}`,
      message: `Lịch đặt bàn ngày ${booking.bookingDate} lúc ${booking.startTime} của bạn có trạng thái mới: ${status}${booking.tableId ? ` (Bàn: ${booking.tableId.name})` : ''}`,
      referenceId: booking._id,
    });

    // Phát tín hiệu Realtime cho Merchant Dashboard và Khách hàng
    emitBookingUpdate(booking.businessId, booking, 'updated');

    res.json({
      success: true,
      data: booking,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Staff Check-in customer booking
// @route   POST /api/bookings/:id/checkin
// @access  Private (Staff)
export const checkInBooking = async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy đặt bàn' });
    }

    booking.status = 'CHECKED_IN';
    booking.checkedInAt = new Date();
    await booking.save();

    if (booking.tableId) {
      await Table.findByIdAndUpdate(booking.tableId, { status: 'UNAVAILABLE' });
    }

    res.json({
      success: true,
      message: 'Check-in thành công',
      data: booking,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

import mongoose from 'mongoose';
import { fail, validDate, validTime, overlapFilter } from '../utils/operations.js';
import { operationError } from '../utils/operations.js';
import { Booking, Branch, Table } from '../models/index.js';

// @desc    Get tables by branch
// @route   GET /api/tables
// @access  Public/Staff
export const getTables = async (req, res) => {
  try {
    const { branchId, status, bookingDate, startTime, endTime = '23:59', guestCount } = req.query;
    const query = {};

    if (branchId) query.branchId = branchId;
    if (status) query.status = status;

    if (status && !Table.schema.path('status').enumValues.includes(status)) fail(400, 'Invalid table status');
    if (guestCount !== undefined) {
      if (!Number.isInteger(Number(guestCount)) || Number(guestCount) < 1) fail(400, 'Invalid guest count');
      query.capacity = { $gte: Number(guestCount) };
    }
    if (bookingDate !== undefined || startTime !== undefined) {
      if (!branchId || !validDate(bookingDate) || !validTime(startTime) || !validTime(endTime) || endTime <= startTime) {
        fail(400, 'Availability requires branchId, bookingDate and a valid time range');
      }
      const conflicts = await Booking.find({
        ...overlapFilter({ bookingDate, startTime, endTime }), branchId, tableId: { $ne: null },
      }).distinct('tableId');
      query._id = { $nin: conflicts };
      query.status = { $in: ['AVAILABLE', 'RESERVED'] };
    }
    const tables = await Table.find(query).sort({ name: 1 });

    res.json({
      success: true,
      count: tables.length,
      data: tables,
    });
  } catch (error) {
    return operationError(res, error);
  }
};

// @desc    Create new table
// @route   POST /api/tables
// @access  Private (Owner/Staff)
export const createTable = async (req, res) => {
  try {
    const { branchId, name, capacity, location, status } = req.body;
    if (!branchId || typeof name !== 'string' || !name.trim() || !Number.isInteger(Number(capacity)) || Number(capacity) < 1) {
      return res.status(400).json({ success: false, message: 'Cần có branchId, tên bàn và sức chứa hợp lệ' });
    }
    if (!(await Branch.exists({ _id: branchId }))) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy chi nhánh' });
    }

    if (status && !Table.schema.path('status').enumValues.includes(status)) fail(400, 'Invalid table status');
    const table = await Table.create({
      branchId,
      name,
      capacity,
      location,
      status: status || 'AVAILABLE',
    });

    res.status(201).json({
      success: true,
      data: table,
    });
  } catch (error) {
    return operationError(res, error);
  }
};

// @desc    Update table status & info
// @route   PUT /api/tables/:id
// @access  Private (Owner/Staff)
export const updateTable = async (req, res) => {
  try {
    const updates = {};
    for (const field of ['name', 'capacity', 'location', 'status']) {
      if (req.body[field] !== undefined) updates[field] = req.body[field];
    }
    if (Object.keys(updates).length === 0) {
      return res.status(400).json({ success: false, message: 'Không có thông tin hợp lệ để cập nhật' });
    }
    if (updates.capacity !== undefined && (!Number.isInteger(Number(updates.capacity)) || Number(updates.capacity) < 1)) {
      return res.status(400).json({ success: false, message: 'Sức chứa phải là số nguyên lớn hơn 0' });
    }
    let table;
    await mongoose.connection.transaction(async (session) => {
      table = await Table.findById(req.params.id).session(session);
      if (!table) fail(404, 'Table not found');
      const activeBookings = await Booking.find({
        tableId: table._id, status: { $in: ['PENDING', 'CONFIRMED', 'CHECKED_IN'] },
      }).session(session);
      if (activeBookings.length && updates.status !== undefined && updates.status !== table.status) {
        fail(409, 'Use booking operations to change a table with active bookings');
      }
      if (updates.capacity !== undefined && activeBookings.some((booking) => booking.guestCount > Number(updates.capacity))) {
        fail(409, 'Capacity is too small for an active booking');
      }
      Object.assign(table, updates);
      await table.save({ session });
    });

    res.json({
      success: true,
      data: table,
    });
  } catch (error) {
    return operationError(res, error);
  }
};

// @desc    Delete table
// @route   DELETE /api/tables/:id
// @access  Private (Owner/Staff)
export const deleteTable = async (req, res) => {
  try {
    let table;
    await mongoose.connection.transaction(async (session) => {
      table = await Table.findById(req.params.id).session(session);
      if (!table) fail(404, 'Table not found');
      if (['RESERVED', 'UNAVAILABLE'].includes(table.status) || await Booking.exists({
        tableId: table._id, status: { $in: ['PENDING', 'CONFIRMED', 'CHECKED_IN'] },
      }).session(session)) fail(409, 'Cannot delete a table with active bookings');
      await Table.deleteOne({ _id: table._id }, { session });
    });

    res.json({
      success: true,
      message: 'Đã xóa bàn ăn thành công',
      data: table,
    });
  } catch (error) {
    return operationError(res, error);
  }
};

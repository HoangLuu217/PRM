import { Table } from '../models/index.js';

// @desc    Get tables by branch
// @route   GET /api/tables
// @access  Public/Staff
export const getTables = async (req, res) => {
  try {
    const { branchId, status } = req.query;
    const query = {};

    if (branchId) query.branchId = branchId;
    if (status) query.status = status;

    const tables = await Table.find(query).sort({ name: 1 });

    res.json({
      success: true,
      count: tables.length,
      data: tables,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Create new table
// @route   POST /api/tables
// @access  Private (Owner/Staff)
export const createTable = async (req, res) => {
  try {
    const { branchId, name, capacity, location, status } = req.body;

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
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update table status & info
// @route   PUT /api/tables/:id
// @access  Private (Owner/Staff)
export const updateTable = async (req, res) => {
  try {
    const table = await Table.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true,
    });
    if (!table) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy bàn' });
    }

    res.json({
      success: true,
      data: table,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Delete table
// @route   DELETE /api/tables/:id
// @access  Private (Owner/Staff)
export const deleteTable = async (req, res) => {
  try {
    const table = await Table.findByIdAndDelete(req.params.id);
    if (!table) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy bàn ăn để xóa' });
    }

    res.json({
      success: true,
      message: 'Đã xóa bàn ăn thành công',
      data: table,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};


import { Staff, User } from '../models/index.js';

// @desc    Assign user as staff to branch
// @route   POST /api/staff
// @access  Private (Owner/Admin)
export const createStaff = async (req, res) => {
  try {
    const { email, businessId, branchId, position, permissions } = req.body;

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy người dùng với email này' });
    }

    const staffExists = await Staff.findOne({ userId: user._id, branchId });
    if (staffExists) {
      return res.status(400).json({ success: false, message: 'Người dùng này đã là nhân viên của chi nhánh' });
    }

    const staff = await Staff.create({
      userId: user._id,
      businessId,
      branchId,
      position: position || 'RECEPTIONIST',
      permissions: permissions || ['BOOKING_MANAGE', 'ORDER_VIEW'],
      status: 'ACTIVE',
    });

    res.status(201).json({
      success: true,
      data: staff,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get staff members for branch
// @route   GET /api/staff/branch/:branchId
// @access  Private (Owner/Admin/Manager)
export const getBranchStaff = async (req, res) => {
  try {
    const staffMembers = await Staff.find({ branchId: req.params.branchId })
      .populate('userId', 'fullName email phone avatarUrl')
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      count: staffMembers.length,
      data: staffMembers,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update staff member status / permissions
// @route   PUT /api/staff/:id
// @access  Private (Owner/Admin)
export const updateStaff = async (req, res) => {
  try {
    const staff = await Staff.findByIdAndUpdate(req.params.id, req.body, { new: true })
      .populate('userId', 'fullName email phone');

    if (!staff) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy nhân viên' });
    }

    res.json({
      success: true,
      data: staff,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

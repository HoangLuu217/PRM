import { UserInteraction } from '../models/index.js';

// @desc    Log user interaction for AI Recommendation engine
// @route   POST /api/interactions
// @access  Private / Public (optional auth)
export const logInteraction = async (req, res) => {
  try {
    const { businessId, branchId, type, metadata } = req.body;

    if (!type) {
      return res.status(400).json({ success: false, message: 'Loại tương tác (type) là bắt buộc' });
    }

    const interaction = await UserInteraction.create({
      userId: req.user ? req.user._id : (req.body.userId || null),
      businessId,
      branchId,
      type,
      metadata: {
        ...(metadata || {}),
        hour: new Date().getHours(),
        dayOfWeek: new Date().getDay(),
      },
    });

    res.status(201).json({
      success: true,
      data: interaction,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get user interactions history
// @route   GET /api/interactions
// @access  Private (Customer/Admin)
export const getUserInteractions = async (req, res) => {
  try {
    const interactions = await UserInteraction.find({ userId: req.user._id })
      .populate('businessId', 'name logoUrl categories')
      .sort({ createdAt: -1 })
      .limit(50);

    res.json({
      success: true,
      count: interactions.length,
      data: interactions,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

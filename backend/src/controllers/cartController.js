import { Cart } from '../models/index.js';

// @desc    Get user cart for a branch
// @route   GET /api/carts/:branchId
// @access  Private
export const getCart = async (req, res) => {
  try {
    let cart = await Cart.findOne({ userId: req.user._id, branchId: req.params.branchId })
      .populate('items.productId');

    if (!cart) {
      cart = await Cart.create({
        userId: req.user._id,
        branchId: req.params.branchId,
        items: [],
      });
    }

    res.json({
      success: true,
      data: cart,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update / Replace items in cart
// @route   PUT /api/carts/:branchId
// @access  Private
export const updateCart = async (req, res) => {
  try {
    const { items } = req.body;

    const cart = await Cart.findOneAndUpdate(
      { userId: req.user._id, branchId: req.params.branchId },
      { items },
      { new: true, upsert: true }
    ).populate('items.productId');

    res.json({
      success: true,
      data: cart,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Clear cart
// @route   DELETE /api/carts/:branchId
// @access  Private
export const clearCart = async (req, res) => {
  try {
    await Cart.findOneAndDelete({ userId: req.user._id, branchId: req.params.branchId });

    res.json({
      success: true,
      message: 'Giỏ hàng đã được làm sạch',
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

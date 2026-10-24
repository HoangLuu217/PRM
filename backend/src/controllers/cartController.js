import { Cart, Product, Branch } from '../models/index.js';

// @desc    Get user cart
// @route   GET /api/cart or GET /api/carts/:branchId
// @access  Private
export const getCart = async (req, res) => {
  try {
    const branchId = req.params.branchId || req.query.branchId;
    const filter = { userId: req.user._id };
    if (branchId) filter.branchId = branchId;

    let cart = await Cart.findOne(filter)
      .sort({ updatedAt: -1 })
      .populate('items.productId')
      .populate('branchId', 'name address');

    if (!cart && branchId) {
      cart = await Cart.create({
        userId: req.user._id,
        branchId,
        items: [],
      });
    }

    res.json({
      success: true,
      data: cart || { userId: req.user._id, items: [] },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Add item to cart
// @route   POST /api/cart
// @access  Private
export const addToCart = async (req, res) => {
  try {
    const { productId, quantity = 1, selectedSize, selectedOptions = [], branchId: reqBranchId, businessId } = req.body;

    if (!productId) {
      return res.status(400).json({ success: false, message: 'Vui lòng cung cấp productId' });
    }

    const product = await Product.findById(productId);
    if (!product) {
      return res.status(404).json({ success: false, message: 'Sản phẩm không tồn tại' });
    }

    let branchId = reqBranchId || product.branchId;
    if (!branchId && businessId) {
      const branch = await Branch.findOne({ businessId });
      branchId = branch?._id;
    }
    if (!branchId) {
      const anyBranch = await Branch.findOne();
      branchId = anyBranch?._id;
    }

    let cart = await Cart.findOne({ userId: req.user._id, branchId });
    if (!cart) {
      cart = new Cart({
        userId: req.user._id,
        branchId,
        items: [],
      });
    }

    const normalizedOptions = (selectedOptions || []).map((opt) => ({
      name: opt.name || opt.optionName || 'Tùy chọn',
      value: opt.value || opt.choiceName || '',
      additionalPrice: Number(opt.additionalPrice || opt.price || 0),
    }));

    // Check if identical item (same product, same size, same options) exists
    const existingIndex = cart.items.findIndex((item) => {
      const sameProduct = item.productId.toString() === productId.toString();
      const sameSize = (item.selectedSize?.name || null) === (selectedSize?.name || null);
      const sameOptions = JSON.stringify(item.selectedOptions || []) === JSON.stringify(normalizedOptions);
      return sameProduct && sameSize && sameOptions;
    });

    if (existingIndex > -1) {
      cart.items[existingIndex].quantity += Number(quantity);
    } else {
      cart.items.push({
        productId,
        quantity: Number(quantity),
        selectedSize: selectedSize || undefined,
        selectedOptions: normalizedOptions,
      });
    }

    await cart.save();
    cart = await Cart.findById(cart._id).populate('items.productId');

    res.status(201).json({
      success: true,
      message: 'Đã thêm vào giỏ hàng',
      data: cart,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update cart items or update specific item quantity
// @route   PUT /api/cart or PUT /api/carts/:branchId
// @access  Private
export const updateCart = async (req, res) => {
  try {
    const branchId = req.params.branchId || req.body.branchId;
    const { items, itemId, quantity } = req.body;

    const filter = { userId: req.user._id };
    if (branchId) filter.branchId = branchId;

    let cart = await Cart.findOne(filter).sort({ updatedAt: -1 });

    if (!cart && branchId) {
      cart = new Cart({ userId: req.user._id, branchId, items: [] });
    }

    if (!cart) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy giỏ hàng' });
    }

    if (Array.isArray(items)) {
      cart.items = items;
    } else if (itemId && typeof quantity === 'number') {
      const itemIndex = cart.items.findIndex(
        (it) => it._id?.toString() === itemId.toString() || it.productId?.toString() === itemId.toString()
      );
      if (itemIndex > -1) {
        if (quantity <= 0) {
          cart.items.splice(itemIndex, 1);
        } else {
          cart.items[itemIndex].quantity = quantity;
        }
      }
    }

    await cart.save();
    cart = await Cart.findById(cart._id).populate('items.productId');

    res.json({
      success: true,
      message: 'Cập nhật giỏ hàng thành công',
      data: cart,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Delete single item from cart by itemId or productId
// @route   DELETE /api/cart/:itemId
// @access  Private
export const deleteCartItem = async (req, res) => {
  try {
    const { itemId } = req.params;

    const cart = await Cart.findOne({
      userId: req.user._id,
      $or: [
        { 'items._id': itemId },
        { 'items.productId': itemId },
      ],
    });

    if (!cart) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy sản phẩm trong giỏ' });
    }

    cart.items = cart.items.filter(
      (it) => it._id?.toString() !== itemId && it.productId?.toString() !== itemId
    );

    await cart.save();
    const updated = await Cart.findById(cart._id).populate('items.productId');

    res.json({
      success: true,
      message: 'Đã xóa món ăn khỏi giỏ hàng',
      data: updated,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Clear entire cart
// @route   DELETE /api/cart or DELETE /api/carts/:branchId
// @access  Private
export const clearCart = async (req, res) => {
  try {
    const branchId = req.params.branchId || req.query.branchId;
    const filter = { userId: req.user._id };
    if (branchId) filter.branchId = branchId;

    await Cart.deleteMany(filter);

    res.json({
      success: true,
      message: 'Giỏ hàng đã được làm sạch',
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

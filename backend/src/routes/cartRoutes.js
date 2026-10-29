import express from 'express';
import {
  getCart,
  addToCart,
  updateCart,
  deleteCartItem,
  clearCart,
} from '../controllers/cartController.js';
import { protect } from '../middlewares/auth.js';
import { Cart } from '../models/index.js';

const router = express.Router();

router.use(protect);

// Standard RESTful endpoints:
// GET    /api/cart
// POST   /api/cart
// PUT    /api/cart
// DELETE /api/cart
router.route('/')
  .get(getCart)
  .post(addToCart)
  .put(updateCart)
  .delete(clearCart);

// DELETE /api/cart/:itemId
// and Legacy compatibility for /api/carts/:branchId
router.route('/:id')
  .get(getCart)
  .put(updateCart)
  .delete(async (req, res, next) => {
    try {
      const isCartItem = await Cart.exists({
        userId: req.user._id,
        $or: [
          { 'items._id': req.params.id },
          { 'items.productId': req.params.id },
        ],
      });
      if (isCartItem) {
        req.params.itemId = req.params.id;
        return deleteCartItem(req, res, next);
      }
      req.params.branchId = req.params.id;
      return clearCart(req, res, next);
    } catch (err) {
      next(err);
    }
  });

export default router;

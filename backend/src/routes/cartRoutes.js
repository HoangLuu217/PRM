import express from 'express';
import {
  getCart,
  updateCart,
  clearCart,
} from '../controllers/cartController.js';
import { protect } from '../middlewares/auth.js';

const router = express.Router();

router.use(protect);

router.route('/:branchId')
  .get(getCart)
  .put(updateCart)
  .delete(clearCart);

export default router;

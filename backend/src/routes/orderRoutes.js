import express from 'express';
import {
  createOrder,
  getMyOrders,
  getBranchOrders,
  updateOrderStatus,
} from '../controllers/orderController.js';
import { protect, staffOnly } from '../middlewares/auth.js';

const router = express.Router();

router.post('/', protect, createOrder);
router.get('/my', protect, getMyOrders);
router.get('/branch/:branchId', protect, staffOnly, getBranchOrders);
router.put('/:id/status', protect, staffOnly, updateOrderStatus);

export default router;

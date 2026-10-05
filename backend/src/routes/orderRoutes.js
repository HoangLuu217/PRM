import { validateIds } from '../utils/operations.js';
import express from 'express';
import {
  createOrder,
  getMyOrders,
  getOrderById,
  getBranchOrders,
  updateOrderStatus,
} from '../controllers/orderController.js';
import { protect, branchOwnerOnly } from '../middlewares/auth.js';

const router = express.Router();
router.use(validateIds);

router.post('/', protect, createOrder);
router.get('/me', protect, getMyOrders);
router.get('/my', protect, getMyOrders);
router.get('/branch/:branchId', protect, branchOwnerOnly, getBranchOrders);
router.put('/:id/status', protect, branchOwnerOnly, updateOrderStatus);
router.get('/:id', protect, getOrderById);

export default router;

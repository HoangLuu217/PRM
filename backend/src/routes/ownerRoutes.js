import { validateIds } from '../utils/operations.js';
import express from 'express';
import { getBranchBookings, updateBookingStatus } from '../controllers/bookingController.js';
import { getBranchOrders, updateOrderStatus } from '../controllers/orderController.js';
import { branchOwnerOnly, businessOwnerAccountOnly, protect } from '../middlewares/auth.js';

const router = express.Router();
router.use(validateIds);

router.get('/bookings', protect, businessOwnerAccountOnly, getBranchBookings);
router.put('/bookings/:id', protect, branchOwnerOnly, updateBookingStatus);
router.get('/orders', protect, businessOwnerAccountOnly, getBranchOrders);
router.put('/orders/:id/status', protect, branchOwnerOnly, updateOrderStatus);

export default router;

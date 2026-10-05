import { validateIds } from '../utils/operations.js';
import express from 'express';
import {
  createBooking,
  getMyBookings,
  getBookingById,
  getBranchBookings,
  updateBookingStatus,
  checkInBooking,
} from '../controllers/bookingController.js';
import { protect, branchOwnerOnly } from '../middlewares/auth.js';

const router = express.Router();
router.use(validateIds);

router.post('/', protect, createBooking);
router.get('/me', protect, getMyBookings);
router.get('/my', protect, getMyBookings);
router.get('/branch/:branchId', protect, branchOwnerOnly, getBranchBookings);
router.put('/:id', protect, updateBookingStatus);
router.put('/:id/status', protect, updateBookingStatus);
router.post('/:id/checkin', protect, branchOwnerOnly, checkInBooking);
router.get('/:id', protect, getBookingById);

export default router;

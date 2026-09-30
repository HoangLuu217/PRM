import express from 'express';
import {
  createBooking,
  getMyBookings,
  getBranchBookings,
  updateBookingStatus,
  checkInBooking,
} from '../controllers/bookingController.js';
import { protect, staffOnly } from '../middlewares/auth.js';

const router = express.Router();

router.post('/', protect, createBooking);
router.get('/my', protect, getMyBookings);
router.get('/branch/:branchId', protect, staffOnly, getBranchBookings);
router.put('/:id/status', protect, updateBookingStatus);
router.post('/:id/checkin', protect, staffOnly, checkInBooking);

export default router;

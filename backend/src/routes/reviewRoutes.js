import express from 'express';
import {
  createReview,
  getBusinessReviews,
  updateReviewStatus,
} from '../controllers/reviewController.js';
import { protect, adminOnly } from '../middlewares/auth.js';

const router = express.Router();

router.post('/', protect, createReview);
router.get('/business/:businessId', getBusinessReviews);
router.put('/:id/status', protect, adminOnly, updateReviewStatus);

export default router;

import express from 'express';
import {
  getBusinesses,
  getBusinessById,
  createBusiness,
  updateBusiness,
  onboardBusiness,
  syncGoogleReviews,
} from '../controllers/businessController.js';
import { protect, optionalProtect, businessOwnerOnly } from '../middlewares/auth.js';

const router = express.Router();

router.route('/')
  .get(optionalProtect, getBusinesses)
  .post(protect, createBusiness);

router.post('/onboard', protect, onboardBusiness);

router.route('/:id')
  .get(getBusinessById)
  .put(protect, businessOwnerOnly, updateBusiness);

router.post('/:id/sync-google-reviews', protect, businessOwnerOnly, syncGoogleReviews);

export default router;


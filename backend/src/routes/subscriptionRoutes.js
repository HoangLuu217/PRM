import express from 'express';
import {
  getPlansController,
  getBusinessSubscriptionController,
  createSubscriptionPaymentController,
  checkSubscriptionStatusController,
} from '../controllers/subscriptionController.js';
import { protect, merchantOnly } from '../middlewares/auth.js';

const router = express.Router();

// 1. Get available subscription tiers
router.get('/plans', getPlansController);

// 2. Get current subscription info for a business
router.get('/current/:businessId', protect, getBusinessSubscriptionController);

// 3. Create PayOS payment link for subscription upgrade
router.post('/create-payment', protect, createSubscriptionPaymentController);

// 4. Check payment status for subscription
router.get('/status/:orderCode', checkSubscriptionStatusController);

export default router;

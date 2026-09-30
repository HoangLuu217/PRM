import express from 'express';
import {
  createDepositPaymentController,
  handlePayOSWebhookController,
  checkPaymentStatusController,
  getMerchantWalletController,
  requestMerchantPayoutController,
  getAdminCommissionStatsController,
} from '../controllers/paymentController.js';
import { protect, adminOnly, merchantOnly } from '../middlewares/auth.js';

const router = express.Router();

// 1. Customer: Create PayOS deposit link & check status
router.post('/create-deposit-link', protect, createDepositPaymentController);
router.get('/status/:orderCode', checkPaymentStatusController);

// 2. PayOS Webhook (Called automatically by PayOS Server when customer completes transfer)
router.post('/payos-webhook', handlePayOSWebhookController);

// 3. Merchant: Wallet & Payout
router.get('/merchant-wallet', protect, merchantOnly, getMerchantWalletController);
router.post('/merchant-payout', protect, merchantOnly, requestMerchantPayoutController);

// 5. Admin: Commission & Platform stats
router.get('/admin-stats', protect, adminOnly, getAdminCommissionStatsController);

export default router;

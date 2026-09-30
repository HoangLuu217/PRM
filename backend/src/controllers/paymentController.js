import {
  createDepositPayment,
  completePaymentSuccess,
  checkDepositPaymentStatus,
  getMerchantWalletInfo,
  requestMerchantPayout,
} from '../services/paymentService.js';
import { verifyPayOSWebhook } from '../services/payosService.js';
import { Transaction, Wallet, Business } from '../models/index.js';

// @desc    Create PayOS Deposit Payment Link
// @route   POST /api/payments/create-deposit-link
// @access  Private (User)
export const createDepositPaymentController = async (req, res) => {
  try {
    const { bookingId, returnUrl, cancelUrl } = req.body;
    const userId = req.user?._id;

    if (!bookingId) {
      return res.status(400).json({ success: false, message: 'Vui lòng cung cấp bookingId' });
    }

    const result = await createDepositPayment({
      bookingId,
      userId,
      returnUrl,
      cancelUrl,
    });

    res.json({
      success: true,
      message: 'Tạo link thanh toán cọc thành công',
      data: result,
    });
  } catch (error) {
    console.error('Create deposit payment error:', error);
    res.status(500).json({ success: false, message: error.message || 'Lỗi tạo link thanh toán cọc' });
  }
};

// @desc    PayOS Webhook Handler
// @route   POST /api/payments/payos-webhook
// @access  Public (Called by PayOS Server)
export const handlePayOSWebhookController = async (req, res) => {
  try {
    const webhookBody = req.body;
    console.log('🔔 Received PayOS Webhook:', JSON.stringify(webhookBody));

    let webhookData;
    try {
      webhookData = verifyPayOSWebhook(webhookBody);
    } catch (verifyErr) {
      console.warn('Webhook verification failed:', verifyErr.message);
      return res.status(400).json({ success: false, message: 'Invalid Webhook Signature' });
    }

    const orderCode = webhookData?.orderCode || webhookBody?.data?.orderCode;
    const code = webhookData?.code || webhookBody?.code;

    // "00" indicates success in PayOS response
    if (orderCode && (code === '00' || code === 0 || webhookBody.desc === 'success')) {
      await completePaymentSuccess(orderCode, webhookData);
      console.log(`✅ PayOS payment processed successfully for orderCode: ${orderCode}`);
    }

    // Always respond 200 OK to PayOS
    res.json({ success: true, message: 'Webhook received' });
  } catch (error) {
    console.error('PayOS Webhook error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Check Payment Status
// @route   GET /api/payments/status/:orderCode
// @access  Public / Private
export const checkPaymentStatusController = async (req, res) => {
  try {
    const { orderCode } = req.params;
    const result = await checkDepositPaymentStatus(orderCode);
    res.json({
      success: true,
      data: result,
    });
  } catch (error) {
    console.error('Check payment status error:', error);
    res.status(500).json({ success: false, message: error.message || 'Lỗi kiểm tra thanh toán' });
  }
};

// @desc    Get Merchant Wallet
// @route   GET /api/payments/merchant-wallet
// @access  Private (Merchant)
export const getMerchantWalletController = async (req, res) => {
  try {
    const userId = req.user?._id;
    // Find business owned by user
    const business = await Business.findOne({ ownerId: userId });
    if (!business) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy quán của người dùng này' });
    }

    const data = await getMerchantWalletInfo(business._id);
    res.json({
      success: true,
      data,
    });
  } catch (error) {
    console.error('Get merchant wallet error:', error);
    res.status(500).json({ success: false, message: error.message || 'Lỗi lấy thông tin ví quán' });
  }
};

// @desc    Request Merchant Payout
// @route   POST /api/payments/merchant-payout
// @access  Private (Merchant)
export const requestMerchantPayoutController = async (req, res) => {
  try {
    const userId = req.user?._id;
    const { amount, bankName, bankAccount, bankAccountName, note } = req.body;

    const business = await Business.findOne({ ownerId: userId });
    if (!business) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy quán của người dùng này' });
    }

    const updatedWallet = await requestMerchantPayout(business._id, {
      amount,
      bankName,
      bankAccount,
      bankAccountName,
      note,
    });

    res.json({
      success: true,
      message: 'Yêu cầu rút tiền đã được gửi thành công!',
      data: updatedWallet,
    });
  } catch (error) {
    console.error('Request payout error:', error);
    res.status(400).json({ success: false, message: error.message || 'Lỗi gửi yêu cầu rút tiền' });
  }
};

// @desc    Get Admin Commission Overview
// @route   GET /api/payments/admin-stats
// @access  Private (Admin)
export const getAdminCommissionStatsController = async (req, res) => {
  try {
    const paidTransactions = await Transaction.find({ status: 'PAID' }).populate('businessId', 'name logoUrl');

    const totalVolume = paidTransactions.reduce((sum, t) => sum + (t.amount || 0), 0);
    const totalAdminCommission = paidTransactions.reduce((sum, t) => sum + (t.commissionAmount || 0), 0);
    const totalMerchantDisbursed = paidTransactions.reduce((sum, t) => sum + (t.merchantAmount || 0), 0);

    const totalWallets = await Wallet.find().populate('businessId', 'name logoUrl');
    const totalMerchantHoldings = totalWallets.reduce((sum, w) => sum + (w.balance || 0), 0);

    res.json({
      success: true,
      data: {
        totalTransactions: paidTransactions.length,
        totalVolume,
        totalAdminCommission,
        totalMerchantDisbursed,
        totalMerchantHoldings,
        recentTransactions: paidTransactions.slice(-15).reverse(),
      },
    });
  } catch (error) {
    console.error('Get admin stats error:', error);
    res.status(500).json({ success: false, message: error.message || 'Lỗi lấy thống kê hoa hồng admin' });
  }
};

import {
  getPlans,
  getBusinessSubscription,
  createSubscriptionPayment,
  checkSubscriptionStatus,
} from '../services/subscriptionService.js';
import { Business } from '../models/index.js';

// @desc    Get all available subscription plans
// @route   GET /api/subscriptions/plans
// @access  Public
export const getPlansController = async (req, res) => {
  try {
    const plans = getPlans();
    res.json({
      success: true,
      data: plans,
    });
  } catch (error) {
    console.error('Get subscription plans error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get current subscription details for a business
// @route   GET /api/subscriptions/current/:businessId
// @access  Private (Merchant/Admin)
export const getBusinessSubscriptionController = async (req, res) => {
  try {
    let { businessId } = req.params;

    // If businessId is 'me', find the business belonging to the authenticated user
    if (businessId === 'me') {
      const business = await Business.findOne({ ownerId: req.user?._id });
      if (!business) {
        return res.status(404).json({ success: false, message: 'Không tìm thấy nhà hàng của bạn' });
      }
      businessId = business._id;
    }

    const data = await getBusinessSubscription(businessId);
    res.json({
      success: true,
      data,
    });
  } catch (error) {
    console.error('Get business subscription error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Create PayOS VietQR payment link for subscription upgrade
// @route   POST /api/subscriptions/create-payment
// @access  Private (Merchant)
export const createSubscriptionPaymentController = async (req, res) => {
  try {
    const { businessId, plan, billingCycle, returnUrl, cancelUrl } = req.body;
    const userId = req.user?._id;

    let targetBusinessId = businessId;
    if (!targetBusinessId) {
      const b = await Business.findOne({ ownerId: userId });
      if (!b) {
        return res.status(404).json({ success: false, message: 'Không tìm thấy thông tin nhà hàng của bạn' });
      }
      targetBusinessId = b._id;
    }

    const result = await createSubscriptionPayment({
      businessId: targetBusinessId,
      userId,
      plan,
      billingCycle,
      returnUrl,
      cancelUrl,
    });

    res.json({
      success: true,
      message: result.isFree ? 'Đã kích hoạt gói Miễn phí' : 'Tạo link thanh toán gói thành công',
      data: result,
    });
  } catch (error) {
    console.error('Create subscription payment error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Check subscription payment status
// @route   GET /api/subscriptions/status/:orderCode
// @access  Public / Private
export const checkSubscriptionStatusController = async (req, res) => {
  try {
    const { orderCode } = req.params;
    const result = await checkSubscriptionStatus(orderCode);
    res.json({
      success: true,
      data: result,
    });
  } catch (error) {
    console.error('Check subscription payment status error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

export default {
  getPlansController,
  getBusinessSubscriptionController,
  createSubscriptionPaymentController,
  checkSubscriptionStatusController,
};

import { Business, Transaction, User, Notification } from '../models/index.js';
import { createPayOSPaymentLink, getPayOSPaymentInfo } from './payosService.js';
import { generateOrderCode } from './paymentService.js';

export const SUBSCRIPTION_PLANS = {
  STARTER: {
    id: 'STARTER',
    name: 'Gói Khởi Đầu (Starter)',
    tagline: 'Dành cho quán mới mở, trải nghiệm nền tảng số hóa thực đơn và đặt bàn',
    pricing: {
      MONTHLY: { price: 0, label: '0đ / tháng' },
      YEARLY: { price: 0, label: '0đ / năm' },
    },
    badge: 'Miễn Phí',
    badgeColor: '#64748b',
    features: {
      maxMenuItems: 15,
      maxBookingsPerMonth: 30,
      isVerifiedBadge: false,
      hasPrioritySearch: false,
      hasAiMealPlannerPriority: false,
      hasAdvancedAnalytics: false,
      maxArticlesPerMonth: 1,
    },
    highlights: [
      'Tối đa 15 món ăn trong thực đơn số',
      'Tối đa 30 lượt khách đặt bàn mỗi tháng',
      'Hiển thị định vị vị trí trên bản đồ FConnect',
      'Nhận thông báo đặt bàn theo thời gian thực',
    ],
  },
  PRO: {
    id: 'PRO',
    name: 'Gói Tăng Trưởng (Pro VIP)',
    tagline: 'Giải pháp tiếp thị & chuyển đổi số toàn diện, bứt phá doanh thu cho nhà hàng',
    pricing: {
      MONTHLY: { price: 299000, label: '299.000đ / tháng' },
      YEARLY: { price: 2990000, label: '2.990.000đ / năm (Tiết kiệm 2 tháng)' },
    },
    badge: 'Khuyên Dùng Nhất',
    badgeColor: '#0066FF',
    features: {
      maxMenuItems: 9999,
      maxBookingsPerMonth: 9999,
      isVerifiedBadge: true,
      hasPrioritySearch: true,
      hasAiMealPlannerPriority: true,
      hasAdvancedAnalytics: true,
      maxArticlesPerMonth: 999,
    },
    highlights: [
      'Không giới hạn số lượng món ăn trong thực đơn',
      'Không giới hạn số lượt khách đặt bàn online',
      'Huy hiệu Tích Xanh "Quán Uy Tín (Verified)" nổi bật',
      'Ưu tiên TOP 1 gợi ý trong AI Meal Planner & Food Tinder',
      'Đứng TOP đầu tìm kiếm danh mục ẩm thực khu vực',
      'Báo cáo phân tích chuyên sâu: Giờ cao điểm, tỷ lệ lấp đầy bàn',
      'Đăng bài viết PR & Marketing không giới hạn',
    ],
  },
};

/**
 * Get all available subscription plans
 */
export const getPlans = () => {
  return Object.values(SUBSCRIPTION_PLANS);
};

/**
 * Get current business subscription details
 */
export const getBusinessSubscription = async (businessId) => {
  const business = await Business.findById(businessId).populate('ownerId', 'fullName email phone');
  if (!business) {
    throw new Error('Không tìm thấy thông tin nhà hàng');
  }

  // Ensure subscription schema structure exists
  if (!business.subscription || !business.subscription.plan) {
    business.subscription = {
      plan: 'STARTER',
      status: 'ACTIVE',
      billingCycle: 'LIFETIME',
      startDate: new Date(),
      expiresAt: null,
      pricePaid: 0,
      features: SUBSCRIPTION_PLANS.STARTER.features,
    };
    await business.save();
  }

  // Check if expired
  const now = new Date();
  if (
    business.subscription.expiresAt &&
    new Date(business.subscription.expiresAt) < now &&
    business.subscription.status === 'ACTIVE'
  ) {
    business.subscription.status = 'EXPIRED';
    await business.save();
  }

  // Get recent subscription transactions
  const transactions = await Transaction.find({
    businessId: business._id,
    type: 'SUBSCRIPTION',
  })
    .sort({ createdAt: -1 })
    .limit(10);

  const planConfig = SUBSCRIPTION_PLANS[business.subscription.plan] || SUBSCRIPTION_PLANS.STARTER;

  return {
    subscription: business.subscription,
    planDetails: planConfig,
    businessName: business.name,
    transactions,
    isExpired: business.subscription.status === 'EXPIRED',
  };
};

/**
 * Create PayOS VietQR Payment link for Subscription Upgrade / Renewal
 */
export const createSubscriptionPayment = async ({
  businessId,
  userId,
  plan,
  billingCycle = 'MONTHLY',
  returnUrl,
  cancelUrl,
}) => {
  const business = await Business.findById(businessId);
  if (!business) {
    throw new Error('Nhà hàng không tồn tại');
  }

  const selectedPlan = SUBSCRIPTION_PLANS[plan];
  if (!selectedPlan) {
    throw new Error('Gói dịch vụ không hợp lệ');
  }

  if (plan === 'STARTER') {
    // Free plan, activate directly
    business.subscription = {
      plan: 'STARTER',
      status: 'ACTIVE',
      billingCycle: 'LIFETIME',
      startDate: new Date(),
      expiresAt: null,
      pricePaid: 0,
      features: selectedPlan.features,
    };
    await business.save();

    return {
      isFree: true,
      plan: 'STARTER',
      message: 'Đã kích hoạt gói Miễn phí Khởi đầu thành công!',
    };
  }

  // Test Configuration: UI displays 299.000đ / 799.000đ, actual PayOS VietQR amount is fixed to 10.000đ (10k) for real transfer testing
  const amount = 10000;

  const orderCode = generateOrderCode();
  const cycleLabel = billingCycle === 'YEARLY' ? '1 Nam' : '1 Thang';
  const description = `GOI ${plan} ${cycleLabel}`.slice(0, 25);

  const user = await User.findById(userId);

  // Call PayOS Gateway
  const paymentResult = await createPayOSPaymentLink({
    orderCode,
    amount,
    description,
    returnUrl,
    cancelUrl,
    items: [
      {
        name: `${selectedPlan.name} (${billingCycle === 'YEARLY' ? '1 Năm' : '1 Tháng'})`,
        quantity: 1,
        price: amount,
      },
    ],
    buyerName: user?.fullName || business.name,
    buyerEmail: user?.email || '',
    buyerPhone: user?.phone || '',
  });

  // Create Transaction Record
  await Transaction.create({
    orderCode,
    type: 'SUBSCRIPTION',
    subscriptionPlan: plan,
    billingCycle,
    userId: user?._id || business.ownerId,
    businessId: business._id,
    amount,
    commissionRate: 0,
    commissionAmount: 0,
    merchantAmount: amount,
    paymentMethod: 'PAYOS_VIETQR',
    status: 'PENDING',
    description: `Nâng cấp ${selectedPlan.name} (${billingCycle === 'YEARLY' ? 'Gói Năm' : 'Gói Tháng'})`,
    payosPaymentLinkId: paymentResult.paymentLinkId,
    payosCheckoutUrl: paymentResult.checkoutUrl,
    payosQrCode: paymentResult.qrCode,
  });

  return {
    isFree: false,
    orderCode,
    plan,
    planName: selectedPlan.name,
    billingCycle,
    amount,
    qrCode: paymentResult.qrCode,
    checkoutUrl: paymentResult.checkoutUrl,
    accountNumber: paymentResult.accountNumber,
    accountName: paymentResult.accountName,
    bin: paymentResult.bin,
    description: paymentResult.description,
    isDemo: paymentResult.isDemo,
  };
};

/**
 * Complete Subscription Payment (called by Webhook or status verification)
 */
export const completeSubscriptionSuccess = async (orderCode, webhookData = {}) => {
  const transaction = await Transaction.findOne({ orderCode: Number(orderCode) });
  if (!transaction) {
    throw new Error(`Không tìm thấy giao dịch subscription với mã: ${orderCode}`);
  }

  if (transaction.status === 'PAID') {
    return { success: true, message: 'Gói dịch vụ đã được kích hoạt trước đó', transaction };
  }

  // 1. Mark transaction as PAID
  transaction.status = 'PAID';
  transaction.paidAt = new Date();
  transaction.webhookData = webhookData;
  await transaction.save();

  // 2. Activate Business Subscription
  const business = await Business.findById(transaction.businessId);
  if (business) {
    const plan = transaction.subscriptionPlan || 'PRO';
    const cycle = transaction.billingCycle || 'MONTHLY';
    const planConfig = SUBSCRIPTION_PLANS[plan] || SUBSCRIPTION_PLANS.PRO;

    const startDate = new Date();
    // Calculate new expiration date
    let expiresAt = new Date();
    if (business.subscription?.expiresAt && new Date(business.subscription.expiresAt) > startDate) {
      // Extend from current expiration
      expiresAt = new Date(business.subscription.expiresAt);
    }

    if (cycle === 'YEARLY') {
      expiresAt.setFullYear(expiresAt.getFullYear() + 1);
    } else {
      expiresAt.setDate(expiresAt.getDate() + 30);
    }

    business.subscription = {
      plan,
      status: 'ACTIVE',
      billingCycle: cycle,
      startDate: business.subscription?.startDate || startDate,
      expiresAt,
      pricePaid: transaction.amount,
      autoRenew: true,
      features: planConfig.features,
    };
    await business.save();

    // 3. Send Notification to Merchant
    try {
      await Notification.create({
        userId: business.ownerId,
        title: `Kích hoạt thành công ${planConfig.name} 👑`,
        message: `Chúc mừng bạn đã nâng cấp thành công gói ${planConfig.name} (${cycle === 'YEARLY' ? '1 Năm' : '1 Tháng'}) cho nhà hàng ${business.name}. Hạn sử dụng đến ngày ${expiresAt.toLocaleDateString('vi-VN')}!`,
        type: 'MERCHANT_ORDER',
        data: { businessId: business._id, orderCode, plan },
      });
    } catch (notifErr) {
      console.warn('Subscription notification error:', notifErr.message);
    }
  }

  return {
    success: true,
    message: 'Kích hoạt gói dịch vụ VIP thành công!',
    businessId: transaction.businessId,
    orderCode: transaction.orderCode,
    plan: transaction.subscriptionPlan,
    amount: transaction.amount,
  };
};

/**
 * Check Subscription Payment Status
 */
export const checkSubscriptionStatus = async (orderCode) => {
  const transaction = await Transaction.findOne({ orderCode: Number(orderCode) });
  if (!transaction) {
    return { status: 'NOT_FOUND', isPaid: false };
  }

  if (transaction.status === 'PENDING') {
    try {
      const payosInfo = await getPayOSPaymentInfo(orderCode);
      if (payosInfo && (payosInfo.status === 'PAID' || payosInfo.status === 'COMPLETED')) {
        await completeSubscriptionSuccess(orderCode, payosInfo);
        transaction.status = 'PAID';
      }
    } catch (err) {
      console.warn('Query PayOS subscription payment info error:', err.message);
    }
  }

  return {
    orderCode: transaction.orderCode,
    status: transaction.status,
    isPaid: transaction.status === 'PAID',
    amount: transaction.amount,
    plan: transaction.subscriptionPlan,
    billingCycle: transaction.billingCycle,
    paidAt: transaction.paidAt,
  };
};

export default {
  SUBSCRIPTION_PLANS,
  getPlans,
  getBusinessSubscription,
  createSubscriptionPayment,
  completeSubscriptionSuccess,
  checkSubscriptionStatus,
};

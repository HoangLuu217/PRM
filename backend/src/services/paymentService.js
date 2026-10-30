import { Booking, Branch, Business, Transaction, Wallet, Notification, User, Order } from '../models/index.js';
import { createPayOSPaymentLink, verifyPayOSWebhook, getPayOSPaymentInfo } from './payosService.js';

// Default system platform commission rate (10%)
const DEFAULT_COMMISSION_RATE = 10;

/**
 * Generate a unique integer orderCode for PayOS (max 53-bit integer)
 */
export const generateOrderCode = () => {
  // Generates unique 6-8 digit integer e.g. 1727501234
  const timestampPart = Math.floor(Date.now() / 1000) % 1000000;
  const randomPart = Math.floor(1000 + Math.random() * 9000);
  return Number(`${timestampPart}${randomPart}`);
};

/**
 * Create a PayOS VietQR deposit payment link for a booking
 */
export const createDepositPayment = async ({
  bookingId,
  userId,
  returnUrl,
  cancelUrl,
}) => {
  const booking = await Booking.findById(bookingId).populate('businessId branchId');
  if (!booking) {
    throw new Error('Đơn đặt bàn không tồn tại');
  }

  if (booking.depositStatus === 'PAID') {
    throw new Error('Đơn đặt bàn này đã được thanh toán cọc');
  }

  const branch = booking.branchId;
  const depositSettings = branch?.depositSettings || {};
  let depositAmount = booking.depositAmount || 0;

  // Calculate deposit if not yet set
  if (depositAmount <= 0) {
    if (depositSettings.depositType === 'PER_GUEST') {
      depositAmount = (depositSettings.depositAmount || 30000) * (booking.guestCount || 1);
    } else {
      depositAmount = depositSettings.depositAmount || 100000;
    }
  }

  // Calculate platform commission (10%) and merchant share (90%)
  const commissionRate = DEFAULT_COMMISSION_RATE;
  const commissionAmount = Math.round((depositAmount * commissionRate) / 100);
  const merchantAmount = depositAmount - commissionAmount;

  const orderCode = generateOrderCode();
  const description = `COC BAN ${booking.bookingCode}`.slice(0, 25);

  const user = await User.findById(userId);

  // Call PayOS Gateway Service
  const paymentResult = await createPayOSPaymentLink({
    orderCode,
    amount: depositAmount,
    description,
    returnUrl,
    cancelUrl,
    items: [
      {
        name: `Cọc bàn ${booking.guestCount} khách (${booking.bookingCode})`,
        quantity: 1,
        price: depositAmount,
      },
    ],
    buyerName: user?.fullName || 'Khách hàng',
    buyerEmail: user?.email || '',
    buyerPhone: user?.phone || '',
  });

  // Create or update Transaction record
  await Transaction.create({
    orderCode,
    type: 'DEPOSIT',
    bookingId: booking._id,
    userId: booking.userId,
    businessId: booking.businessId._id,
    branchId: booking.branchId._id,
    amount: depositAmount,
    commissionRate,
    commissionAmount,
    merchantAmount,
    paymentMethod: 'PAYOS_VIETQR',
    status: 'PENDING',
    description,
    payosPaymentLinkId: paymentResult.paymentLinkId,
    payosCheckoutUrl: paymentResult.checkoutUrl,
    payosQrCode: paymentResult.qrCode,
  });

  // Update Booking with deposit info
  booking.depositRequired = true;
  booking.depositAmount = depositAmount;
  booking.depositStatus = 'PENDING';
  booking.paymentOrderCode = orderCode;
  booking.payosPaymentLinkId = paymentResult.paymentLinkId;
  booking.commissionRate = commissionRate;
  booking.commissionAmount = commissionAmount;
  booking.merchantAmount = merchantAmount;
  await booking.save();

  return {
    orderCode,
    depositAmount,
    commissionRate,
    commissionAmount,
    merchantAmount,
    qrCode: paymentResult.qrCode,
    checkoutUrl: paymentResult.checkoutUrl,
    accountNumber: paymentResult.accountNumber,
    accountName: paymentResult.accountName,
    bin: paymentResult.bin,
    description: paymentResult.description,
    isDemo: paymentResult.isDemo,
    bookingCode: booking.bookingCode,
    guestCount: booking.guestCount,
    bookingDate: booking.bookingDate,
    startTime: booking.startTime,
  };
};

/**
 * Handle Successful Payment Execution (Webhook or verified PayOS payment)
 */
export const completePaymentSuccess = async (orderCode, webhookData = {}) => {
  const numericCode = Number(String(orderCode).replace(/\D/g, '')) || Number(orderCode);

  let transaction = await Transaction.findOne({ orderCode: numericCode });
  let foodOrder = await Order.findOne({ orderCode: String(orderCode) });
  if (!foodOrder && numericCode > 0) {
    foodOrder = await Order.findOne({ orderCode: String(numericCode) });
  }

  if (!transaction && !foodOrder) {
    throw new Error(`Không tìm thấy đơn hàng hoặc giao dịch với mã orderCode: ${orderCode}`);
  }

  if (transaction) {
    if (transaction.type === 'SUBSCRIPTION' && transaction.subscriptionPlan) {
      const { completeSubscriptionSuccess } = await import('./subscriptionService.js');
      return completeSubscriptionSuccess(orderCode, webhookData);
    }
    transaction.status = 'PAID';
    transaction.paidAt = new Date();
    transaction.webhookData = webhookData;
    await transaction.save();
  }

  if (foodOrder) {
    foodOrder.paymentStatus = 'PAID';
    foodOrder.status = 'CONFIRMED';
    await foodOrder.save();
    if (foodOrder.bookingId) {
      await Booking.findByIdAndUpdate(foodOrder.bookingId, { status: 'CONFIRMED', depositStatus: 'PAID' });
    }
  }

  const bookingId = transaction?.bookingId || foodOrder?.bookingId;
  if (bookingId) {
    const booking = await Booking.findById(bookingId).populate('businessId branchId');
    if (booking) {
      booking.depositStatus = 'PAID';
      booking.status = 'CONFIRMED';
      booking.paidAt = new Date();
      await booking.save();

      let wallet = await Wallet.findOne({ businessId: booking.businessId?._id || booking.businessId });
      if (wallet && transaction?.merchantAmount) {
        wallet.balance += transaction.merchantAmount;
        wallet.totalDepositsEarned += transaction.merchantAmount;
        await wallet.save();
      }
    }
  }

  return {
    success: true,
    message: 'Xác nhận thanh toán thành công!',
    orderCode,
  };
};

/**
 * Check payment status by orderCode (supports both Booking deposits and Food Orders)
 * Strictly verifies with PayOS Gateway that payment status is PAID before confirming!
 */
export const checkDepositPaymentStatus = async (orderCode) => {
  const numericCode = Number(String(orderCode).replace(/\D/g, '')) || Number(orderCode);

  let transaction = await Transaction.findOne({ orderCode: numericCode });
  let order = await Order.findOne({ orderCode: String(orderCode) });
  if (!order && numericCode > 0) {
    order = await Order.findOne({ orderCode: String(numericCode) });
  }

  // Query PayOS Gateway directly for real payment status
  let isPayOSPaid = false;
  let payosInfo = null;
  if (numericCode > 0) {
    try {
      payosInfo = await getPayOSPaymentInfo(numericCode);
      const status = String(payosInfo?.status || '').toUpperCase();
      const amountPaid = Number(payosInfo?.amountPaid || 0);
      const hasTransactions = Array.isArray(payosInfo?.transactions) && payosInfo.transactions.length > 0;
      isPayOSPaid = status === 'PAID' || amountPaid > 0 || hasTransactions;
    } catch (err) {
      console.warn('Query PayOS payment info warning:', err.message);
    }
  }

  if (isPayOSPaid) {
    await completePaymentSuccess(numericCode, payosInfo || {});
    return {
      orderCode,
      status: 'PAID',
      isPaid: true,
      paidAt: new Date(),
    };
  }

  const isAlreadyPaidInDb =
    (transaction?.status === 'PAID' && !transaction?.webhookData?.manual) ||
    (order?.paymentStatus === 'PAID' && !transaction?.webhookData?.manual);

  return {
    orderCode,
    status: isAlreadyPaidInDb ? 'PAID' : 'PENDING',
    isPaid: Boolean(isAlreadyPaidInDb),
    paidAt: isAlreadyPaidInDb ? (transaction?.paidAt || order?.updatedAt) : null,
  };
};

/**
 * Get Merchant Wallet details
 */
export const getMerchantWalletInfo = async (businessId) => {
  let wallet = await Wallet.findOne({ businessId });
  if (!wallet) {
    wallet = await Wallet.create({
      businessId,
      balance: 0,
      totalDepositsEarned: 0,
      totalCommissionPaid: 0,
      totalWithdrawn: 0,
    });
  }

  const recentTransactions = await Transaction.find({ businessId, status: 'PAID' })
    .sort({ createdAt: -1 })
    .limit(20)
    .populate('userId', 'fullName email phone')
    .populate('bookingId', 'bookingCode guestCount bookingDate startTime');

  return {
    wallet,
    recentTransactions,
  };
};

/**
 * Request Merchant Payout
 */
export const requestMerchantPayout = async (businessId, { amount, bankName, bankAccount, bankAccountName, note }) => {
  const wallet = await Wallet.findOne({ businessId });
  if (!wallet) {
    throw new Error('Ví quán không tồn tại');
  }

  const withdrawAmount = Number(amount);
  if (isNaN(withdrawAmount) || withdrawAmount < 50000) {
    throw new Error('Số tiền rút tối thiểu là 50.000đ');
  }

  if (wallet.balance < withdrawAmount) {
    throw new Error(`Số dư khả dụng (${wallet.balance.toLocaleString()}đ) không đủ để rút ${withdrawAmount.toLocaleString()}đ`);
  }

  wallet.balance -= withdrawAmount;
  wallet.totalWithdrawn += withdrawAmount;
  wallet.payoutRequests.push({
    amount: withdrawAmount,
    bankName,
    bankAccount,
    bankAccountName,
    note: note || 'Yêu cầu rút tiền từ Fconnect',
    status: 'PENDING',
  });

  // Save bank account info for future
  wallet.bankAccount = { bankName, bankAccount, bankAccountName };
  await wallet.save();

  return wallet;
};

export default {
  createDepositPayment,
  completePaymentSuccess,
  checkDepositPaymentStatus,
  getMerchantWalletInfo,
  requestMerchantPayout,
};

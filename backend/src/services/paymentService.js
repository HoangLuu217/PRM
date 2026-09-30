import { Booking, Branch, Business, Transaction, Wallet, Notification, User } from '../models/index.js';
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
 * Handle Successful Payment Execution (Webhook or Simulator)
 */
export const completePaymentSuccess = async (orderCode, webhookData = {}) => {
  const transaction = await Transaction.findOne({ orderCode: Number(orderCode) });
  if (!transaction) {
    throw new Error(`Không tìm thấy giao dịch với mã orderCode: ${orderCode}`);
  }

  if (transaction.status === 'PAID') {
    return { success: true, message: 'Giao dịch đã được xử lý trước đó', transaction };
  }

  // Handle Subscription Payment
  if (transaction.type === 'SUBSCRIPTION') {
    const { completeSubscriptionSuccess } = await import('./subscriptionService.js');
    return completeSubscriptionSuccess(orderCode, webhookData);
  }

  // 1. Update Transaction (for deposit)
  transaction.status = 'PAID';
  transaction.paidAt = new Date();
  transaction.webhookData = webhookData;
  await transaction.save();

  // 2. Update Booking
  const booking = await Booking.findById(transaction.bookingId).populate('businessId branchId');
  if (booking) {
    booking.depositStatus = 'PAID';
    booking.status = 'CONFIRMED';
    booking.paidAt = new Date();
    await booking.save();

    // 3. Credit Merchant Wallet (90% after 10% platform commission)
    let wallet = await Wallet.findOne({ businessId: transaction.businessId });
    if (!wallet) {
      wallet = new Wallet({ businessId: transaction.businessId, balance: 0 });
    }

    wallet.balance += transaction.merchantAmount;
    wallet.totalDepositsEarned += transaction.merchantAmount;
    wallet.totalCommissionPaid += transaction.commissionAmount;
    await wallet.save();

    // 4. Send Notifications
    try {
      await Notification.create({
        userId: booking.userId,
        title: 'Thanh toán cọc bàn thành công 🎉',
        message: `Bạn đã đặt cọc thành công ${transaction.amount.toLocaleString()}đ cho bàn tiệc tại ${booking.businessId?.name || 'nhà hàng'}. Bàn của bạn đã được xác nhận giữ chỗ!`,
        type: 'BOOKING',
        data: { bookingId: booking._id, orderCode },
      });

      if (booking.businessId?.ownerId) {
        await Notification.create({
          userId: booking.businessId.ownerId,
          title: 'Khách đã cọc bàn thành công 💵',
          message: `Khách hàng đã đặt cọc ${transaction.amount.toLocaleString()}đ cho đơn đặt bàn ${booking.bookingCode} (${booking.guestCount} người). Số dư ví của quán được cộng +${transaction.merchantAmount.toLocaleString()}đ!`,
          type: 'MERCHANT_ORDER',
          data: { bookingId: booking._id, orderCode },
        });
      }
    } catch (notifErr) {
      console.warn('Send notification error:', notifErr.message);
    }
  }

  return {
    success: true,
    message: 'Thanh toán cọc thành công và đã xác nhận đặt bàn',
    bookingId: transaction.bookingId,
    orderCode: transaction.orderCode,
    amount: transaction.amount,
  };
};

/**
 * Check payment status by orderCode
 */
export const checkDepositPaymentStatus = async (orderCode) => {
  const transaction = await Transaction.findOne({ orderCode: Number(orderCode) });
  if (!transaction) {
    return { status: 'NOT_FOUND', isPaid: false };
  }

  // If status in DB is PENDING, actively query PayOS Gateway API
  if (transaction.status === 'PENDING') {
    try {
      const payosInfo = await getPayOSPaymentInfo(orderCode);
      if (payosInfo && (payosInfo.status === 'PAID' || payosInfo.status === 'COMPLETED')) {
        await completePaymentSuccess(orderCode, payosInfo);
        transaction.status = 'PAID';
      }
    } catch (err) {
      console.warn('Query PayOS payment info error:', err.message);
    }
  }

  return {
    orderCode: transaction.orderCode,
    status: transaction.status,
    isPaid: transaction.status === 'PAID',
    amount: transaction.amount,
    bookingId: transaction.bookingId,
    paidAt: transaction.paidAt,
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

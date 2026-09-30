import mongoose from 'mongoose';

const transactionSchema = new mongoose.Schema(
  {
    orderCode: {
      type: Number,
      required: true,
      unique: true,
    },
    type: {
      type: String,
      enum: ['DEPOSIT', 'SUBSCRIPTION', 'PAYOUT', 'OTHER'],
      default: 'SUBSCRIPTION',
    },
    bookingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Booking',
      required: false,
    },
    subscriptionPlan: {
      type: String,
      enum: ['STARTER', 'PRO'],
      default: null,
    },
    billingCycle: {
      type: String,
      enum: ['MONTHLY', 'YEARLY', 'LIFETIME'],
      default: 'MONTHLY',
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
    },
    branchId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Branch',
      required: false,
    },
    amount: {
      type: Number,
      required: true,
      min: 0,
    },
    commissionRate: {
      type: Number,
      default: 10,
    },
    commissionAmount: {
      type: Number,
      default: 0,
    },
    merchantAmount: {
      type: Number,
      default: 0,
    },
    paymentMethod: {
      type: String,
      default: 'PAYOS_VIETQR',
    },
    status: {
      type: String,
      enum: ['PENDING', 'PAID', 'CANCELLED', 'FAILED', 'REFUNDED'],
      default: 'PENDING',
    },
    description: {
      type: String,
      default: '',
    },
    payosPaymentLinkId: {
      type: String,
      default: '',
    },
    payosCheckoutUrl: {
      type: String,
      default: '',
    },
    payosQrCode: {
      type: String,
      default: '',
    },
    webhookData: {
      type: mongoose.Schema.Types.Mixed,
      default: null,
    },
    paidAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

export const Transaction = mongoose.model('Transaction', transactionSchema);
export default Transaction;

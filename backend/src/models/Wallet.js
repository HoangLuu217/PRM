import mongoose from 'mongoose';

const payoutRequestSchema = new mongoose.Schema(
  {
    amount: {
      type: Number,
      required: true,
      min: 50000,
    },
    bankName: {
      type: String,
      required: true,
    },
    bankAccount: {
      type: String,
      required: true,
    },
    bankAccountName: {
      type: String,
      required: true,
    },
    status: {
      type: String,
      enum: ['PENDING', 'APPROVED', 'REJECTED'],
      default: 'PENDING',
    },
    note: {
      type: String,
      default: '',
    },
    processedAt: {
      type: Date,
      default: null,
    },
  },
  { timestamps: true }
);

const walletSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      unique: true,
    },
    balance: {
      type: Number,
      default: 0,
      min: 0,
    },
    totalDepositsEarned: {
      type: Number,
      default: 0,
    },
    totalCommissionPaid: {
      type: Number,
      default: 0,
    },
    totalWithdrawn: {
      type: Number,
      default: 0,
    },
    bankAccount: {
      bankName: { type: String, default: '' },
      bankAccount: { type: String, default: '' },
      bankAccountName: { type: String, default: '' },
    },
    payoutRequests: [payoutRequestSchema],
  },
  {
    timestamps: true,
  }
);

export const Wallet = mongoose.model('Wallet', walletSchema);
export default Wallet;

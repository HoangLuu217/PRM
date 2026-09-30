import mongoose from 'mongoose';

const bookingSchema = new mongoose.Schema(
  {
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
      required: true,
    },
    tableId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Table',
    },
    bookingCode: {
      type: String,
      required: true,
      unique: true,
    },
    bookingDate: {
      type: String, // e.g. "2026-09-15"
      required: true,
    },
    startTime: {
      type: String, // e.g. "19:00"
      required: true,
    },
    endTime: {
      type: String, // e.g. "21:00"
    },
    guestCount: {
      type: Number,
      required: true,
      min: 1,
    },
    status: {
      type: String,
      enum: ['PENDING', 'CONFIRMED', 'REJECTED', 'CANCELLED', 'CHECKED_IN', 'COMPLETED'],
      default: 'PENDING',
    },
    note: {
      type: String,
      default: '',
    },
    depositRequired: {
      type: Boolean,
      default: false,
    },
    depositAmount: {
      type: Number,
      default: 0,
    },
    depositStatus: {
      type: String,
      enum: ['NONE', 'PENDING', 'PAID', 'REFUNDED'],
      default: 'NONE',
    },
    paymentOrderCode: {
      type: Number,
      default: null,
    },
    payosPaymentLinkId: {
      type: String,
      default: null,
    },
    commissionRate: {
      type: Number,
      default: 10, // 10%
    },
    commissionAmount: {
      type: Number,
      default: 0,
    },
    merchantAmount: {
      type: Number,
      default: 0,
    },
    paidAt: {
      type: Date,
      default: null,
    },
    preOrderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Order',
    },
    checkedInAt: {
      type: Date,
      default: null,
    },
    completedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

export const Booking = mongoose.model('Booking', bookingSchema);
export default Booking;

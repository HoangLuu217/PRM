import mongoose from 'mongoose';

const notificationSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    type: {
      type: String,
      enum: [
        'BOOKING_CONFIRMED',
        'BOOKING_CANCELLED',
        'BOOKING_REJECTED',
        'BOOKING_CHECKED_IN',
        'BOOKING_COMPLETED',
        'ORDER_CONFIRMED',
        'ORDER_PREPARING',
        'ORDER_READY',
        'ORDER_SERVED',
        'ORDER_COMPLETED',
        'ORDER_CANCELLED',
        'REVIEW_REPLY',
        'SYSTEM',
      ],
      default: 'SYSTEM',
    },
    title: {
      type: String,
      required: true,
    },
    message: {
      type: String,
      required: true,
    },
    referenceId: {
      type: mongoose.Schema.Types.ObjectId,
    },
    isRead: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

export const Notification = mongoose.model('Notification', notificationSchema);
export default Notification;

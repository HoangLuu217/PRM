import mongoose from 'mongoose';

const userInteractionSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: false,
    },
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
    },
    branchId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Branch',
    },
    type: {
      type: String,
      enum: [
        'SEARCH',
        'VIEW',
        'CLICK',
        'FAVORITE',
        'BOOKING',
        'ORDER',
        'REVIEW',
        'RATING',
      ],
      required: true,
    },
    metadata: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
    timestamp: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: true,
  }
);

export const UserInteraction = mongoose.model('UserInteraction', userInteractionSchema);
export default UserInteraction;

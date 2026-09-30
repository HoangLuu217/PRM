import mongoose from 'mongoose';

const branchSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
    },
    name: {
      type: String,
      required: [true, 'Please provide a branch name'],
      trim: true,
    },
    address: {
      street: { type: String, default: '' },
      ward: { type: String, default: '' },
      district: { type: String, default: '' },
      city: { type: String, default: '' },
    },
    location: {
      type: {
        type: String,
        enum: ['Point'],
        default: 'Point',
      },
      coordinates: {
        type: [Number], // [longitude, latitude]
        required: true,
      },
    },
    phone: {
      type: String,
      trim: true,
    },
    googleMapsUrl: {
      type: String,
      default: '',
    },
    openingHours: [
      {
        day: { type: Number, min: 0, max: 6 }, // 0: Sunday, 1: Monday, etc.
        open: { type: String }, // e.g. "07:00"
        close: { type: String }, // e.g. "22:00"
      },
    ],
    amenities: [
      {
        type: String,
      },
    ],
    depositSettings: {
      isDepositRequired: { type: Boolean, default: false },
      minGuestsForDeposit: { type: Number, default: 4 },
      depositAmount: { type: Number, default: 100000 },
      depositType: {
        type: String,
        enum: ['FIXED_PER_BOOKING', 'PER_GUEST'],
        default: 'FIXED_PER_BOOKING',
      },
    },
    status: {
      type: String,
      enum: ['ACTIVE', 'INACTIVE', 'CLOSED'],
      default: 'ACTIVE',
    },
  },
  {
    timestamps: true,
  }
);

branchSchema.index({ location: '2dsphere' });

export const Branch = mongoose.model('Branch', branchSchema);
export default Branch;

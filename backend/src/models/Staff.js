import mongoose from 'mongoose';

const staffSchema = new mongoose.Schema(
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
    position: {
      type: String,
      enum: ['RECEPTIONIST', 'MANAGER', 'WAITER', 'KITCHEN', 'CASHIER'],
      default: 'RECEPTIONIST',
    },
    permissions: [
      {
        type: String,
      },
    ],
    status: {
      type: String,
      enum: ['ACTIVE', 'INACTIVE'],
      default: 'ACTIVE',
    },
  },
  {
    timestamps: true,
  }
);

export const Staff = mongoose.model('Staff', staffSchema);
export default Staff;

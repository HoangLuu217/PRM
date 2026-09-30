import mongoose from 'mongoose';

const selectedOptionSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    value: { type: String, required: true },
    additionalPrice: { type: Number, default: 0 },
  },
  { _id: false }
);

const cartItemSchema = new mongoose.Schema(
  {
    productId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Product',
      required: true,
    },
    quantity: {
      type: Number,
      required: true,
      min: 1,
      default: 1,
    },
    selectedOptions: [selectedOptionSchema],
  },
  { _id: false }
);

const cartSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    branchId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Branch',
      required: true,
    },
    items: [cartItemSchema],
  },
  {
    timestamps: true,
  }
);

// One user can have only one cart per branch
cartSchema.index({ userId: 1, branchId: 1 }, { unique: true });

export const Cart = mongoose.model('Cart', cartSchema);
export default Cart;

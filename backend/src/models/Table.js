import mongoose from 'mongoose';

const tableSchema = new mongoose.Schema(
  {
    branchId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Branch',
      required: true,
    },
    name: {
      type: String,
      required: [true, 'Please provide a table name/number'],
      trim: true,
    },
    capacity: {
      type: Number,
      required: [true, 'Please provide table capacity'],
      min: 1,
    },
    location: {
      type: String,
      default: 'Floor 1',
    },
    status: {
      type: String,
      enum: ['AVAILABLE', 'RESERVED', 'UNAVAILABLE', 'MAINTENANCE'],
      default: 'AVAILABLE',
    },
  },
  {
    timestamps: true,
  }
);

export const Table = mongoose.model('Table', tableSchema);
export default Table;

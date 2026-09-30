import mongoose from 'mongoose';

const otpSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    lowercase: true,
    trim: true,
  },
  otp: {
    type: String,
    required: true,
  },
  type: {
    type: String,
    enum: ['REGISTER', 'RESET_PASSWORD', 'VERIFY_EMAIL', 'MERCHANT_SECURITY'],
    default: 'REGISTER',
  },
  createdAt: {
    type: Date,
    default: Date.now,
    expires: 300, // Document automatically removed after 5 minutes (300 seconds)
  },
});

export const Otp = mongoose.model('Otp', otpSchema);
export default Otp;

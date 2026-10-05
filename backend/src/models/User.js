import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';

const userSchema = new mongoose.Schema(
  {
    fullName: {
      type: String,
      required: [true, 'Please provide a full name'],
      trim: true,
    },
    email: {
      type: String,
      required: [true, 'Please provide an email'],
      unique: true,
      lowercase: true,
      trim: true,
      match: [/^\S+@\S+\.\S+$/, 'Please provide a valid email'],
    },
    password: {
      type: String,
      required: function () {
        return this.authProvider === 'LOCAL';
      },
      minlength: 6,
      select: false,
    },
    authProvider: {
      type: String,
      enum: ['LOCAL', 'GOOGLE'],
      default: 'LOCAL',
    },
    googleId: {
      type: String,
      sparse: true,
    },
    phone: {
      type: String,
      trim: true,
    },
    isPhoneVerified: {
      type: Boolean,
      default: false,
    },
    isEmailVerified: {
      type: Boolean,
      default: false,
    },
    avatarUrl: {
      type: String,
      default: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
    },
    role: {
      type: String,
      enum: ['USER', 'CUSTOMER', 'MERCHANT', 'BUSINESS_OWNER', 'STAFF', 'ADMIN'],
      default: 'USER',
    },
    status: {
      type: String,
      enum: ['ACTIVE', 'INACTIVE', 'SUSPENDED'],
      default: 'ACTIVE',
    },
    preferences: {
      favoriteCategories: [
        {
          type: String,
          enum: [
            'RESTAURANT',
            'CAFE',
            'MILK_TEA',
            'BAKERY',
            'FAST_FOOD',
            'BBQ',
            'BUFFET',
            'DESSERT',
            'BAR',
            'OTHER',
          ],
        },
      ],
      priceRange: {
        min: { type: Number, default: 0 },
        max: { type: Number, default: 1000000 },
      },
      preferredAreas: [{ type: String }],
      vibes: [{ type: String, trim: true }],
      hasCompletedSurvey: { type: Boolean, default: false },
    },
    likedArticles: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Article',
      },
    ],
    favoriteDishes: [
      {
        dishId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: 'Product',
        },
        name: { type: String, required: true },
        price: { type: Number, default: 0 },
        imageUrl: { type: String },
        category: { type: String },
        aiMatchScore: { type: Number },
        matchReason: { type: String },
        business: {
          _id: { type: mongoose.Schema.Types.ObjectId, ref: 'Business' },
          name: { type: String },
          logoUrl: { type: String },
          rating: { type: Number },
        },
        likedAt: { type: Date, default: Date.now },
      },
    ],
  },
  {
    timestamps: true,
  }
);

userSchema.index({ likedArticles: 1 });

// Encrypt password before saving
userSchema.pre('save', async function (next) {
  if (!this.password || !this.isModified('password')) {
    return next();
  }
  const salt = await bcrypt.genSalt(10);
  this.password = await bcrypt.hash(this.password, salt);
});

// Compare password method
userSchema.methods.matchPassword = async function (enteredPassword) {
  if (!this.password) return false;
  return await bcrypt.compare(enteredPassword, this.password);
};

export const User = mongoose.model('User', userSchema);
export default User;

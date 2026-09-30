import mongoose from 'mongoose';

const businessSchema = new mongoose.Schema(
  {
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    name: {
      type: String,
      required: [true, 'Please provide a business name'],
      trim: true,
    },
    slug: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    description: {
      type: String,
      default: '',
    },
    categories: [
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
    logoUrl: {
      type: String,
      default: '',
    },
    coverImageUrl: {
      type: String,
      default: '',
    },
    priceRange: {
      min: { type: Number, default: 0 },
      max: { type: Number, default: 0 },
    },
    vibes: [
      {
        type: String,
        trim: true,
      },
    ],
    purposes: [
      {
        type: String,
        trim: true,
      },
    ],
    features: [
      {
        type: String,
        trim: true,
      },
    ],
    spaceTags: [
      {
        type: String,
        trim: true,
      },
    ],
    status: {
      type: String,
      enum: ['PENDING', 'APPROVED', 'REJECTED', 'SUSPENDED'],
      default: 'PENDING',
    },
    ratingSummary: {
      average: { type: Number, default: 0 },
      totalReviews: { type: Number, default: 0 },
    },
    googleMapsUrl: {
      type: String,
      default: '',
    },
    googlePlaceId: {
      type: String,
      default: '',
    },
    googleRating: {
      rating: { type: Number, default: 0 },
      userRatingsTotal: { type: Number, default: 0 },
    },
    googleReviews: [
      {
        authorName: { type: String, default: 'Khách hàng Google' },
        authorPhotoUrl: { type: String, default: '' },
        rating: { type: Number, default: 5 },
        text: { type: String, default: '' },
        relativeTime: { type: String, default: '' },
        time: { type: Number, default: Date.now },
        images: [{ type: String }],
      },
    ],
    googleReviewsLastSyncedAt: {
      type: Date,
      default: null,
    },
    openTime: {
      type: String,
      default: '07:00',
    },
    closeTime: {
      type: String,
      default: '22:00',
    },
    operatingDays: {
      type: String,
      default: 'Thứ 2 - Chủ Nhật',
    },
    weeklySchedule: [
      {
        day: { type: Number, required: true }, // 1 = T2, 2 = T3, 3 = T4, 4 = T5, 5 = T6, 6 = T7, 0 = CN
        dayLabel: { type: String, required: true }, // 'Thứ 2', 'Thứ 3', ..., 'Chủ Nhật'
        isOpen: { type: Boolean, default: true },
        openTime: { type: String, default: '07:00' },
        closeTime: { type: String, default: '22:00' },
      },
    ],
    category: {
      type: String,
      default: 'Nhà hàng / Quán ăn',
      trim: true,
    },
    isBookingEnabled: {
      type: Boolean,
      default: true,
    },
    isOpenOverride: {
      type: Boolean,
      default: null, // null = theo giờ hoạt động tự động, true = mở cửa thủ công, false = đóng cửa thủ công
    },
    subscription: {
      plan: {
        type: String,
        enum: ['STARTER', 'PRO'],
        default: 'STARTER',
      },
      status: {
        type: String,
        enum: ['ACTIVE', 'EXPIRED', 'PENDING_PAYMENT'],
        default: 'ACTIVE',
      },
      billingCycle: {
        type: String,
        enum: ['MONTHLY', 'YEARLY', 'LIFETIME'],
        default: 'MONTHLY',
      },
      startDate: {
        type: Date,
        default: Date.now,
      },
      expiresAt: {
        type: Date,
        default: null,
      },
      pricePaid: {
        type: Number,
        default: 0,
      },
      autoRenew: {
        type: Boolean,
        default: false,
      },
      features: {
        maxMenuItems: { type: Number, default: 15 },
        maxBookingsPerMonth: { type: Number, default: 30 },
        isVerifiedBadge: { type: Boolean, default: false },
        hasPrioritySearch: { type: Boolean, default: false },
        hasAiMealPlannerPriority: { type: Boolean, default: false },
        hasAdvancedAnalytics: { type: Boolean, default: false },
        maxArticlesPerMonth: { type: Number, default: 999 },
      },
    },
  },
  {
    timestamps: true,
  }
);

export const Business = mongoose.model('Business', businessSchema);
export default Business;

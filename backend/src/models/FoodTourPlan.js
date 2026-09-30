import mongoose from 'mongoose';

const foodTourStopSchema = new mongoose.Schema(
  {
    timeSlot: {
      type: String,
      required: true,
    },
    mealType: {
      type: String,
      enum: ['Breakfast', 'Lunch', 'Cafe', 'Dinner', 'LateNight'],
      required: true,
    },
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      default: null,
    },
    branchId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Branch',
      default: null,
    },
    placeName: {
      type: String,
      required: true,
    },
    address: {
      type: String,
      default: '',
    },
    phone: {
      type: String,
      default: '',
    },
    rating: {
      type: Number,
      default: 4.5,
    },
    imageUrl: {
      type: String,
      default: '',
    },
    suggestedDishes: [
      {
        productId: { type: mongoose.Schema.Types.ObjectId, ref: 'Product' },
        name: { type: String, required: true },
        price: { type: Number, default: 0 },
        imageUrl: { type: String, default: '' },
      },
    ],
    estimatedCostVND: {
      type: Number,
      required: true,
    },
    reasonForSuggestion: {
      type: String,
      default: '',
    },
    coordinates: {
      type: [Number], // [lng, lat]
      default: [108.2208, 16.0678],
    },
  },
  { _id: true }
);

const foodTourDaySchema = new mongoose.Schema(
  {
    dayNumber: {
      type: Number,
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
    stops: [foodTourStopSchema],
    dayTotalEstimatedCost: {
      type: Number,
      required: true,
    },
  },
  { _id: true }
);

const foodTourPlanSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    title: {
      type: String,
      required: true,
    },
    planType: {
      type: String,
      default: 'food_tour',
    },
    locationCity: {
      type: String,
      required: true,
      default: 'Đà Nẵng',
    },
    durationDays: {
      type: Number,
      required: true,
      default: 1,
    },
    targetBudgetVND: {
      type: Number,
      required: true,
    },
    partySize: {
      type: Number,
      default: 2,
    },
    vibeTag: {
      type: String,
      default: 'F&B Discovery',
    },
    days: [foodTourDaySchema],
    totalEstimatedCost: {
      type: Number,
      required: true,
    },
    aiExplanationSummary: {
      type: String,
      default: '',
    },
    status: {
      type: String,
      enum: ['DRAFT', 'SAVED'],
      default: 'DRAFT',
    },
  },
  {
    timestamps: true,
  }
);

export const FoodTourPlan = mongoose.model('FoodTourPlan', foodTourPlanSchema);
export default FoodTourPlan;

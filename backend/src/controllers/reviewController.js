import { Review, Business, Booking, Order, UserInteraction } from '../models/index.js';

// Helper to recalculate business average rating
const recalculateBusinessRating = async (businessId) => {
  const reviews = await Review.find({ businessId, status: 'PUBLISHED' });
  if (reviews.length === 0) {
    await Business.findByIdAndUpdate(businessId, { ratingSummary: { average: 0, totalReviews: 0 } });
    return;
  }

  const sum = reviews.reduce((acc, item) => acc + item.rating, 0);
  const average = Math.round((sum / reviews.length) * 10) / 10;

  await Business.findByIdAndUpdate(businessId, {
    ratingSummary: { average, totalReviews: reviews.length },
  });
};

// @desc    Create new review (Verified review if booking/order provided)
// @route   POST /api/reviews
// @access  Private (Customer)
export const createReview = async (req, res) => {
  try {
    const { businessId, branchId, bookingId, orderId, rating, content, images } = req.body;

    let isVerified = false;
    if (bookingId) {
      const booking = await Booking.findOne({ _id: bookingId, userId: req.user._id, status: { $in: ['CHECKED_IN', 'COMPLETED'] } });
      if (booking) isVerified = true;
    }
    if (!isVerified && orderId) {
      const order = await Order.findOne({ _id: orderId, userId: req.user._id, status: 'COMPLETED' });
      if (order) isVerified = true;
    }

    const review = await Review.create({
      userId: req.user._id,
      businessId,
      branchId,
      bookingId,
      orderId,
      rating,
      content,
      images: images || [],
      isVerified,
      status: 'PUBLISHED',
    });

    await recalculateBusinessRating(businessId);

    // Automatically record interaction for personalized recommendations
    UserInteraction.create({
      userId: req.user._id,
      businessId,
      branchId,
      type: 'REVIEW',
      metadata: { rating, isVerified },
    }).catch(() => {});

    res.status(201).json({
      success: true,
      data: review,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get reviews for a business
// @route   GET /api/reviews/business/:businessId
// @access  Public
export const getBusinessReviews = async (req, res) => {
  try {
    const reviews = await Review.find({ businessId: req.params.businessId, status: 'PUBLISHED' })
      .populate('userId', 'fullName avatarUrl')
      .populate('branchId', 'name')
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      count: reviews.length,
      data: reviews,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Moderate review status (Admin/Owner)
// @route   PUT /api/reviews/:id/status
// @access  Private (Admin/Owner)
export const updateReviewStatus = async (req, res) => {
  try {
    const { status } = req.body;
    const review = await Review.findByIdAndUpdate(req.params.id, { status }, { new: true });

    if (!review) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy đánh giá' });
    }

    await recalculateBusinessRating(review.businessId);

    res.json({
      success: true,
      data: review,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

import {
  User,
  Business,
  Review,
  Booking,
  Order,
  UserInteraction,
  Article,
  Branch,
  Product,
  Menu,
  Table,
  Cart,
  Favorite,
  Staff,
} from '../models/index.js';
import { emitBusinessUpdate, emitBusinessDelete } from '../socket.js';

// @desc    Get system dashboard statistics & chart metrics
// @route   GET /api/admin/stats
// @access  Private (Admin)
export const getAdminStats = async (req, res) => {
  try {
    const totalUsers = await User.countDocuments();
    const totalBusinesses = await Business.countDocuments();
    const pendingBusinesses = await Business.countDocuments({ status: 'PENDING' });
    const approvedBusinesses = await Business.countDocuments({ status: 'APPROVED' });
    const suspendedBusinesses = await Business.countDocuments({ status: 'SUSPENDED' });
    const totalBookings = await Booking.countDocuments();
    const totalOrders = await Order.countDocuments();
    const totalReviews = await Review.countDocuments();
    const totalInteractions = await UserInteraction.countDocuments();
    const totalArticles = await Article.countDocuments();

    // Booking status breakdown
    const bookingsByStatus = await Booking.aggregate([
      { $group: { _id: '$status', count: { $sum: 1 } } },
    ]);

    // Business category breakdown (unwind categories array field)
    const categoryBreakdown = await Business.aggregate([
      { $unwind: '$categories' },
      { $group: { _id: '$categories', count: { $sum: 1 } } },
      { $project: { category: '$_id', count: 1, _id: 0 } },
    ]);

    // AI interaction type breakdown
    const interactionBreakdown = await UserInteraction.aggregate([
      { $group: { _id: '$type', count: { $sum: 1 } } },
    ]);

    // Calculate 6-month cumulative growth trend directly from MongoDB database
    const growthTrendData = [];
    const now = new Date();

    for (let i = 5; i >= 0; i--) {
      const targetDate = new Date(now.getFullYear(), now.getMonth() - i + 1, 0, 23, 59, 59, 999);
      const monthNum = targetDate.getMonth() + 1;
      const monthLabel = `T${monthNum}`;
      const queryDate = i === 0 ? now : targetDate;

      const [users, businesses, bookings] = await Promise.all([
        User.countDocuments({ createdAt: { $lte: queryDate } }),
        Business.countDocuments({ createdAt: { $lte: queryDate } }),
        Booking.countDocuments({ createdAt: { $lte: queryDate } }),
      ]);

      growthTrendData.push({
        month: monthLabel,
        users,
        businesses,
        bookings,
      });
    }

    // Calculate user growth rate comparing current month to previous month
    const startOfCurrentMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const startOfLastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const endOfLastMonth = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59, 999);

    const [currentMonthUsers, lastMonthUsers] = await Promise.all([
      User.countDocuments({ createdAt: { $gte: startOfCurrentMonth } }),
      User.countDocuments({ createdAt: { $gte: startOfLastMonth, $lte: endOfLastMonth } }),
    ]);

    let userGrowthPercent = 0;
    if (lastMonthUsers > 0) {
      userGrowthPercent = Math.round(((currentMonthUsers - lastMonthUsers) / lastMonthUsers) * 100);
    } else if (currentMonthUsers > 0) {
      userGrowthPercent = 100;
    }

    res.json({
      success: true,
      data: {
        totalUsers,
        totalBusinesses,
        pendingBusinesses,
        approvedBusinesses,
        suspendedBusinesses,
        totalBookings,
        totalOrders,
        totalReviews,
        totalInteractions,
        totalArticles,
        growthTrendData,
        userGrowthPercent,
        bookingsByStatus: bookingsByStatus.reduce((acc, curr) => {
          acc[curr._id] = curr.count;
          return acc;
        }, {}),
        categoryBreakdown,
        interactionBreakdown: interactionBreakdown.reduce((acc, curr) => {
          acc[curr._id] = curr.count;
          return acc;
        }, {}),
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get all businesses with status filter
// @route   GET /api/admin/businesses
// @access  Private (Admin)
export const getAllBusinessesAdmin = async (req, res) => {
  try {
    const { status } = req.query;
    const query = {};
    if (status && status !== 'ALL') {
      query.status = status;
    }

    const businesses = await Business.find(query)
      .populate('ownerId', 'fullName email phone avatarUrl')
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      count: businesses.length,
      data: businesses,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get pending business applications
// @route   GET /api/admin/businesses/pending
// @access  Private (Admin)
export const getPendingBusinesses = async (req, res) => {
  try {
    const businesses = await Business.find({ status: 'PENDING' })
      .populate('ownerId', 'fullName email phone avatarUrl')
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      count: businesses.length,
      data: businesses,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Approve or Reject business application
// @route   PUT /api/admin/businesses/:id/status
// @access  Private (Admin)
export const approveBusinessStatus = async (req, res) => {
  try {
    const { status, rejectionReason } = req.body;

    if (!['APPROVED', 'REJECTED', 'SUSPENDED', 'PENDING'].includes(status)) {
      return res.status(400).json({ success: false, message: 'Trạng thái không hợp lệ' });
    }

    const updateData = { status };
    if (status === 'REJECTED' && rejectionReason) {
      updateData.rejectionReason = rejectionReason;
    }

    const business = await Business.findByIdAndUpdate(req.params.id, updateData, { new: true });

    if (!business) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy doanh nghiệp' });
    }

    res.json({
      success: true,
      message: `Đã cập nhật trạng thái doanh nghiệp thành: ${status}`,
      data: business,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update business details by Admin (including vibes, purposes, price, status, etc.)
// @route   PUT /api/admin/businesses/:id
// @access  Private (Admin)
export const updateBusinessAdmin = async (req, res) => {
  try {
    const business = await Business.findById(req.params.id);
    if (!business) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy doanh nghiệp' });
    }

    const payload = { ...req.body };

    if (payload.priceRange) {
      payload.priceRange = {
        min: Math.max(0, Number(payload.priceRange.min) || 0),
        max: Math.max(0, Number(payload.priceRange.max) || 0),
      };
    }

    if (payload.vibes && Array.isArray(payload.vibes)) {
      payload.vibes = payload.vibes.map((v) => String(v).trim()).filter(Boolean);
    }

    if (payload.purposes && Array.isArray(payload.purposes)) {
      payload.purposes = payload.purposes.map((p) => String(p).trim()).filter(Boolean);
    }

    if (payload.features && Array.isArray(payload.features)) {
      payload.features = payload.features.map((f) => String(f).trim()).filter(Boolean);
    }

    if (payload.categories && Array.isArray(payload.categories)) {
      payload.categories = payload.categories.filter(Boolean);
    }

    const updated = await Business.findByIdAndUpdate(req.params.id, payload, { new: true })
      .populate('ownerId', 'fullName email phone avatarUrl');

    emitBusinessUpdate(updated);

    res.json({
      success: true,
      data: updated,
      message: 'Cập nhật thông tin quán & vibe thành công',
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Delete business and all associated resources by Admin
// @route   DELETE /api/admin/businesses/:id
// @access  Private (Admin)
export const deleteBusinessAdmin = async (req, res) => {
  try {
    const { id } = req.params;
    const business = await Business.findById(id);
    if (!business) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy doanh nghiệp' });
    }

    const businessName = business.name;

    // Cascade delete all associated entities
    await Promise.all([
      Branch.deleteMany({ businessId: id }),
      Product.deleteMany({ businessId: id }),
      Menu.deleteMany({ businessId: id }),
      Table.deleteMany({ businessId: id }),
      Booking.deleteMany({ businessId: id }),
      Review.deleteMany({ businessId: id }),
      Favorite.deleteMany({ businessId: id }),
      Cart.deleteMany({ businessId: id }),
      Order.deleteMany({ businessId: id }),
      Staff.deleteMany({ businessId: id }),
    ]);

    await Business.findByIdAndDelete(id);

    // Notify connected clients realtime
    emitBusinessDelete(id);

    res.json({
      success: true,
      message: `Đã xóa quán "${businessName}" và toàn bộ dữ liệu liên quan thành công`,
      data: { _id: id, name: businessName },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get all users list
// @route   GET /api/admin/users
// @access  Private (Admin)
export const getUsersList = async (req, res) => {
  try {
    const { role } = req.query;
    const query = {};
    if (role && role !== 'ALL') {
      query.role = role;
    }

    const users = await User.find(query).select('-password').sort({ createdAt: -1 });

    res.json({
      success: true,
      count: users.length,
      data: users,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update user status (ACTIVE / SUSPENDED)
// @route   PUT /api/admin/users/:id/status
// @access  Private (Admin)
export const updateUserStatus = async (req, res) => {
  try {
    const { status } = req.body;

    if (!['ACTIVE', 'SUSPENDED'].includes(status)) {
      return res.status(400).json({ success: false, message: 'Trạng thái không hợp lệ' });
    }

    const user = await User.findByIdAndUpdate(req.params.id, { status }, { new: true }).select('-password');

    if (!user) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy người dùng' });
    }

    res.json({
      success: true,
      message: `Đã cập nhật trạng thái tài khoản thành: ${status}`,
      data: user,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get all reviews for moderation
// @route   GET /api/admin/reviews
// @access  Private (Admin)
export const getAllReviewsAdmin = async (req, res) => {
  try {
    const { status } = req.query;
    const query = {};
    if (status && status !== 'ALL') {
      query.status = status;
    }

    const reviews = await Review.find(query)
      .populate('userId', 'fullName avatarUrl role')
      .populate('businessId', 'name logoUrl')
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

// @desc    Update review status (PUBLISHED / HIDDEN / REPORTED)
// @route   PUT /api/admin/reviews/:id/status
// @access  Private (Admin)
export const updateReviewStatusAdmin = async (req, res) => {
  try {
    const { status } = req.body;

    const review = await Review.findByIdAndUpdate(req.params.id, { status }, { new: true });

    if (!review) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy đánh giá' });
    }

    res.json({
      success: true,
      message: `Đã chuyển trạng thái review thành: ${status}`,
      data: review,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get AI Interaction Telemetry Logs
// @route   GET /api/admin/interactions
// @access  Private (Admin)
export const getAIInteractionsAdmin = async (req, res) => {
  try {
    const interactions = await UserInteraction.find()
      .populate('userId', 'fullName email avatarUrl')
      .populate('businessId', 'name')
      .sort({ timestamp: -1 })
      .limit(100);

    res.json({
      success: true,
      count: interactions.length,
      data: interactions,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get all articles for Admin moderation
// @route   GET /api/admin/articles
// @access  Private (Admin)
export const getArticlesAdmin = async (req, res) => {
  try {
    const { status } = req.query;
    const query = {};
    if (status && status !== 'ALL') {
      query.status = status;
    }

    const articles = await Article.find(query)
      .populate('authorId', 'fullName email avatarUrl role')
      .populate('businessId', 'name logoUrl')
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      count: articles.length,
      data: articles,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update article status (PUBLISHED / DRAFT / ARCHIVED)
// @route   PUT /api/admin/articles/:id/status
// @access  Private (Admin)
export const updateArticleStatusAdmin = async (req, res) => {
  try {
    const { status } = req.body;

    const article = await Article.findByIdAndUpdate(req.params.id, { status }, { new: true });

    if (!article) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy bài viết' });
    }

    res.json({
      success: true,
      message: `Đã chuyển trạng thái bài viết thành: ${status}`,
      data: article,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Delete article
// @route   DELETE /api/admin/articles/:id
// @access  Private (Admin)
export const deleteArticleAdmin = async (req, res) => {
  try {
    const article = await Article.findByIdAndDelete(req.params.id);
    if (!article) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy bài viết' });
    }

    res.json({
      success: true,
      message: 'Đã xóa bài viết thành công',
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

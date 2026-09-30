import { Article, Business, Branch, User } from '../models/index.js';

// @desc    Get all articles with search & filter
// @route   GET /api/articles
// @access  Public
export const getArticles = async (req, res) => {
  try {
    const { keyword, category, businessId, authorId, status = 'PUBLISHED' } = req.query;
    const query = {};

    if (status && status !== 'ALL') {
      query.status = status;
    }

    if (category && category !== 'Tất cả') {
      query.category = category;
    }

    if (businessId) {
      query.businessId = businessId;
    }

    if (authorId) {
      query.authorId = authorId;
    }

    if (keyword) {
      query.$or = [
        { title: { $regex: keyword, $options: 'i' } },
        { summary: { $regex: keyword, $options: 'i' } },
        { tags: { $in: [new RegExp(keyword, 'i')] } },
      ];
    }

    const articles = await Article.find(query)
      .populate('businessId', 'name slug logoUrl coverImageUrl categories priceRange ratingSummary')
      .populate('branchId', 'name address phone')
      .populate('authorId', 'fullName avatarUrl email')
      .sort({ createdAt: -1 });

    const currentUserId = req.user?._id ? req.user._id.toString() : null;
    const mappedArticles = articles.map((art) => {
      const artObj = art.toObject();
      return {
        ...artObj,
        isLiked: Boolean(
          currentUserId &&
          Array.isArray(art.likedBy) &&
          art.likedBy.some((id) => id && id.toString() === currentUserId)
        ),
      };
    });

    res.json({
      success: true,
      count: mappedArticles.length,
      data: mappedArticles,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get single article by ID or slug
// @route   GET /api/articles/:id
// @access  Public
export const getArticleById = async (req, res) => {
  try {
    const isObjectId = req.params.id.match(/^[0-9a-fA-F]{24}$/);
    const query = isObjectId ? { _id: req.params.id } : { slug: req.params.id };

    const article = await Article.findOneAndUpdate(
      query,
      { $inc: { views: 1 } },
      { new: true }
    )
      .populate(
        'businessId',
        'name slug logoUrl coverImageUrl categories priceRange ratingSummary description'
      )
      .populate('branchId', 'name address phone')
      .populate('authorId', 'fullName avatarUrl email');

    if (!article) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy bài viết' });
    }

    // Also find related branches if businessId exists
    let branches = [];
    if (article.businessId) {
      branches = await Branch.find({ businessId: article.businessId._id, status: 'ACTIVE' });
    }

    const currentUserId = req.user?._id ? req.user._id.toString() : null;
    const isLiked = Boolean(
      currentUserId &&
      Array.isArray(article.likedBy) &&
      article.likedBy.some((id) => id && id.toString() === currentUserId)
    );

    res.json({
      success: true,
      data: {
        ...article.toObject(),
        linkedBranches: branches,
        isLiked,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Create new article
// @route   POST /api/articles
// @access  Private (Owner / Admin / User)
export const createArticle = async (req, res) => {
  try {
    const {
      title,
      summary,
      content,
      category,
      coverImage,
      businessId,
      branchId,
      tags,
      readTime,
      status,
    } = req.body;

    if (!title || !summary || !content) {
      return res.status(400).json({ success: false, message: 'Vui lòng điền đầy đủ tiêu đề, tóm tắt và nội dung' });
    }

    // Check Business Subscription Article Limit
    if (businessId) {
      const business = await Business.findById(businessId);
      if (business) {
        const maxArticles = business.subscription?.features?.maxArticlesPerMonth || 1;
        const startOfMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
        const articlesThisMonth = await Article.countDocuments({
          businessId,
          createdAt: { $gte: startOfMonth },
        });

        if (articlesThisMonth >= maxArticles) {
          return res.status(403).json({
            success: false,
            message: `Quán của bạn đang ở gói ${business.subscription?.plan || 'STARTER'} (chỉ được đăng tối đa ${maxArticles} bài viết/tháng). Vui lòng nâng cấp gói PRO VIP để đăng bài PR Marketing không giới hạn!`,
            requiresUpgrade: true,
          });
        }
      }
    }

    const slug = title
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/đ/g, 'd')
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '') + '-' + Date.now();

    const article = await Article.create({
      title,
      slug,
      summary,
      content,
      category: category || 'Review Quán Hot',
      coverImage: coverImage || 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=800&q=80',
      authorId: req.user._id,
      authorName: req.user.fullName || 'Chủ quán FConnect',
      authorRole: req.user.role === 'ADMIN' ? 'Quản trị viên FConnect' : 'Chủ nhà hàng / Đối tác F&B',
      authorAvatar: req.user.avatarUrl || 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
      businessId: businessId || undefined,
      branchId: branchId || undefined,
      tags: Array.isArray(tags) ? tags : typeof tags === 'string' ? tags.split(',').map((t) => t.trim()).filter(Boolean) : [],
      readTime: readTime || '5 phút đọc',
      status: status || 'PUBLISHED',
    });

    const populatedArticle = await Article.findById(article._id)
      .populate('businessId', 'name slug logoUrl coverImageUrl categories priceRange')
      .populate('branchId', 'name address phone');

    res.status(201).json({
      success: true,
      data: populatedArticle,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update article
// @route   PUT /api/articles/:id
// @access  Private
export const updateArticle = async (req, res) => {
  try {
    let article = await Article.findById(req.params.id);
    if (!article) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy bài viết' });
    }

    if (req.user.role !== 'ADMIN' && article.authorId.toString() !== req.user._id.toString()) {
      return res.status(403).json({ success: false, message: 'Bạn không có quyền chỉnh sửa bài viết này' });
    }

    article = await Article.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true,
    })
      .populate('businessId', 'name slug logoUrl coverImageUrl categories priceRange')
      .populate('branchId', 'name address phone');

    res.json({
      success: true,
      data: article,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Delete article
// @route   DELETE /api/articles/:id
// @access  Private
export const deleteArticle = async (req, res) => {
  try {
    const article = await Article.findById(req.params.id);
    if (!article) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy bài viết' });
    }

    if (req.user.role !== 'ADMIN' && article.authorId.toString() !== req.user._id.toString()) {
      return res.status(403).json({ success: false, message: 'Bạn không có quyền xóa bài viết này' });
    }

    await article.deleteOne();

    res.json({
      success: true,
      message: 'Đã xóa bài viết thành công',
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Like or Unlike an article (toggle)
// @route   POST /api/articles/:id/like
// @access  Private
export const likeArticle = async (req, res) => {
  try {
    const isObjectId = req.params.id.match(/^[0-9a-fA-F]{24}$/);
    const query = isObjectId ? { _id: req.params.id } : { slug: req.params.id };

    const article = await Article.findOne(query);

    if (!article) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy bài viết' });
    }

    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Vui lòng đăng nhập để thích bài viết' });
    }

    const userIdStr = req.user._id.toString();
    if (!Array.isArray(article.likedBy)) {
      article.likedBy = [];
    }

    const existingIndex = article.likedBy.findIndex((id) => id && id.toString() === userIdStr);
    let isLiked = false;

    if (existingIndex > -1) {
      // Hủy tim (Unlike)
      article.likedBy.splice(existingIndex, 1);
      article.likes = Math.max(0, (article.likes || 1) - 1);
      isLiked = false;

      // Đồng bộ gỡ khỏi User.likedArticles
      await User.findByIdAndUpdate(req.user._id, {
        $pull: { likedArticles: article._id },
      });
    } else {
      // Tim (Like)
      article.likedBy.push(req.user._id);
      article.likes = (article.likes || 0) + 1;
      isLiked = true;

      // Đồng bộ lưu vào User.likedArticles
      await User.findByIdAndUpdate(req.user._id, {
        $addToSet: { likedArticles: article._id },
      });
    }

    // Đảm bảo số lượng likes tối thiểu bằng số lượng người dùng đã tim
    if (article.likedBy.length > article.likes) {
      article.likes = article.likedBy.length;
    }

    await article.save();

    res.json({
      success: true,
      likes: article.likes,
      isLiked,
      articleId: article._id,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Increment article view count
// @route   POST /api/articles/:id/view
// @access  Public
export const incrementArticleView = async (req, res) => {
  try {
    const isObjectId = req.params.id.match(/^[0-9a-fA-F]{24}$/);
    const query = isObjectId ? { _id: req.params.id } : { slug: req.params.id };

    const article = await Article.findOneAndUpdate(
      query,
      { $inc: { views: 1 } },
      { new: true }
    );

    if (!article) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy bài viết' });
    }

    res.json({
      success: true,
      views: article.views,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};


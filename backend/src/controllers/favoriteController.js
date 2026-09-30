import { Favorite, UserInteraction, User } from '../models/index.js';

// @desc    Add business to favorites
// @route   POST /api/favorites
// @access  Private (Customer)
export const addFavorite = async (req, res) => {
  try {
    const { businessId } = req.body;

    const favorite = await Favorite.create({
      userId: req.user._id,
      businessId,
    });

    // Automatically record interaction for personalized recommendations
    UserInteraction.create({
      userId: req.user._id,
      businessId,
      type: 'FAVORITE',
      metadata: { source: 'favorite_toggle' },
    }).catch(() => {});

    res.status(201).json({
      success: true,
      data: favorite,
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({ success: false, message: 'Đã thêm doanh nghiệp này vào danh sách yêu thích' });
    }
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Remove business from favorites
// @route   DELETE /api/favorites/:businessId
// @access  Private (Customer)
export const removeFavorite = async (req, res) => {
  try {
    await Favorite.findOneAndDelete({
      userId: req.user._id,
      businessId: req.params.businessId,
    });

    res.json({
      success: true,
      message: 'Đã xóa khỏi danh sách yêu thích',
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get current user's favorites
// @route   GET /api/favorites
// @access  Private (Customer)
export const getMyFavorites = async (req, res) => {
  try {
    const favorites = await Favorite.find({ userId: req.user._id })
      .populate('businessId', 'name logoUrl coverImageUrl categories priceRange ratingSummary')
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      count: favorites.length,
      data: favorites,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get current user's favorite dishes
// @route   GET /api/favorites/dishes
// @access  Private (Customer)
export const getMyFavoriteDishes = async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select('favoriteDishes');
    let dishes = user?.favoriteDishes || [];
    dishes = dishes.map((d) => (d.toObject ? d.toObject() : { ...d }));

    // Enrich dishes with fresh business cover image and logo
    const bizIds = dishes.map((d) => d.business?._id).filter(Boolean);
    if (bizIds.length > 0) {
      const bizList = await Business.find({ _id: { $in: bizIds } })
        .select('name logoUrl coverImageUrl address ratingSummary googleRating')
        .lean();
      const bizMap = new Map();
      bizList.forEach((b) => bizMap.set(b._id.toString(), b));

      dishes.forEach((d) => {
        if (d.business?._id) {
          const freshBiz = bizMap.get(d.business._id.toString());
          if (freshBiz) {
            d.business = {
              ...d.business,
              ...freshBiz,
              coverImageUrl: freshBiz.coverImageUrl || d.business.coverImageUrl,
              logoUrl: freshBiz.logoUrl || d.business.logoUrl,
            };
          }
        }
      });
    }

    res.json({
      success: true,
      count: dishes.length,
      data: dishes,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Add dish to user's favorite dishes
// @route   POST /api/favorites/dishes
// @access  Private (Customer)
export const addFavoriteDish = async (req, res) => {
  try {
    const { dishId, name, price, imageUrl, category, aiMatchScore, matchReason, business } = req.body;
    const user = await User.findById(req.user._id);
    if (!user) {
      return res.status(404).json({ success: false, message: 'Người dùng không tồn tại' });
    }

    if (!user.favoriteDishes) {
      user.favoriteDishes = [];
    }

    // Enrich business with coverImageUrl if missing
    let enrichedBusiness = business || {};
    if (business?._id && !enrichedBusiness.coverImageUrl) {
      const foundBiz = await Business.findById(business._id).select('coverImageUrl logoUrl name address').lean();
      if (foundBiz) {
        enrichedBusiness = { ...enrichedBusiness, ...foundBiz };
      }
    }

    const existingIndex = user.favoriteDishes.findIndex(
      (d) =>
        (dishId && d.dishId?.toString() === dishId.toString()) ||
        (d.name === name && d.business?._id?.toString() === business?._id?.toString())
    );

    if (existingIndex === -1) {
      user.favoriteDishes.unshift({
        dishId: dishId || undefined,
        name: name || 'Món ngon FConnect',
        price: Number(price) || 0,
        imageUrl: imageUrl || '',
        category: category || 'Món đặc sắc',
        aiMatchScore: Number(aiMatchScore) || 95,
        matchReason: matchReason || 'Món yêu thích từ gợi ý AI',
        business: enrichedBusiness,
        likedAt: new Date(),
      });
      await user.save();
    }

    // Automatically record FAVORITE interaction
    if (business?._id) {
      UserInteraction.create({
        userId: req.user._id,
        businessId: business._id,
        type: 'FAVORITE',
        metadata: {
          dishId,
          dishName: name,
          source: 'tinder_swipe_like',
          aiMatchScore,
        },
      }).catch(() => {});

      // Optionally auto-favorite the business so it also appears in favorite places
      try {
        const hasBizFav = await Favorite.findOne({ userId: req.user._id, businessId: business._id });
        if (!hasBizFav) {
          await Favorite.create({ userId: req.user._id, businessId: business._id });
        }
      } catch (err) {}
    }

    res.status(201).json({
      success: true,
      message: 'Đã lưu món ăn vào danh sách yêu thích',
      data: user.favoriteDishes,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Remove dish from favorite dishes
// @route   DELETE /api/favorites/dishes/:dishId
// @access  Private (Customer)
export const removeFavoriteDish = async (req, res) => {
  try {
    const user = await User.findById(req.user._id);
    if (!user) {
      return res.status(404).json({ success: false, message: 'Người dùng không tồn tại' });
    }

    user.favoriteDishes = (user.favoriteDishes || []).filter(
      (d) => d._id?.toString() !== req.params.dishId && d.dishId?.toString() !== req.params.dishId
    );
    await user.save();

    res.json({
      success: true,
      message: 'Đã xóa món ăn khỏi danh sách yêu thích',
      data: user.favoriteDishes,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};


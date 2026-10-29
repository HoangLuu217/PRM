import { Favorite, UserInteraction, User, Business, Branch } from '../models/index.js';

// @desc    Add business to favorites
// @route   POST /api/favorites
// @access  Private (Customer)
export const addFavorite = async (req, res) => {
  try {
    const { businessId } = req.body;
    if (!businessId) {
      return res.status(400).json({ success: false, message: 'businessId là bắt buộc' });
    }

    let favorite = await Favorite.findOne({
      userId: req.user._id,
      businessId,
    });

    if (!favorite) {
      favorite = await Favorite.create({
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
    }

    res.status(201).json({
      success: true,
      message: 'Đã thêm vào danh sách yêu thích',
      data: favorite,
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(200).json({
        success: true,
        message: 'Đã thêm doanh nghiệp này vào danh sách yêu thích',
      });
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
      .populate({
        path: 'businessId',
        select:
          'name slug description logoUrl coverImageUrl categories priceRange ratingSummary googleRating openTime closeTime vibes purposes features addressText status phone',
      })
      .sort({ createdAt: -1 });

    // Filter out favorites whose business might have been removed
    const validFavorites = favorites.filter((f) => f.businessId);

    // Fetch active branches to populate address, phone and GPS coords
    const businessIds = validFavorites.map((f) => f.businessId._id);
    const branches = await Branch.find({
      businessId: { $in: businessIds },
      status: 'ACTIVE',
    }).lean();

    const branchMap = {};
    branches.forEach((br) => {
      const bId = br.businessId.toString();
      if (!branchMap[bId]) branchMap[bId] = [];
      branchMap[bId].push(br);
    });

    const enriched = validFavorites.map((f) => {
      const bObj = f.businessId.toObject ? f.businessId.toObject() : { ...f.businessId };
      const bId = bObj._id.toString();
      const bBranches = branchMap[bId] || [];
      bObj.branches = bBranches;
      bObj.primaryBranch = bBranches[0] || null;
      if (!bObj.addressText && bObj.primaryBranch?.address) {
        const street = bObj.primaryBranch.address.street || '';
        const district = bObj.primaryBranch.address.district || '';
        bObj.addressText = [street, district].filter(Boolean).join(', ');
      }
      return {
        _id: f._id,
        userId: f.userId,
        business: bObj,
        businessId: bObj,
        createdAt: f.createdAt,
      };
    });

    res.json({
      success: true,
      count: enriched.length,
      data: enriched,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get list of favorite business IDs for current user
// @route   GET /api/favorites/ids
// @access  Private (Customer)
export const getFavoriteIds = async (req, res) => {
  try {
    const favorites = await Favorite.find({ userId: req.user._id }).select('businessId');
    const ids = favorites.map((f) => f.businessId?.toString()).filter(Boolean);
    res.json({
      success: true,
      data: ids,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Check if a business is favorited by current user
// @route   GET /api/favorites/check/:businessId
// @access  Private (Customer)
export const checkFavorite = async (req, res) => {
  try {
    const favorite = await Favorite.findOne({
      userId: req.user._id,
      businessId: req.params.businessId,
    });
    res.json({
      success: true,
      isFavorite: !!favorite,
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


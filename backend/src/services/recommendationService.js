import { UserInteraction, Branch, Business } from '../models/index.js';

/**
 * Get current time of day context in Vietnam timezone (UTC+7)
 */
export const getTimeOfDayContext = () => {
  const now = new Date();
  const utcHours = now.getUTCHours();
  const vnHour = (utcHours + 7) % 24;

  if (vnHour >= 5 && vnHour < 10.5) {
    return {
      period: 'MORNING',
      label: 'Bữa sáng & Cafe nạp năng lượng',
      categories: ['CAFE', 'BAKERY', 'RESTAURANT'],
      keywords: ['bánh mì', 'phở', 'bún', 'cà phê', 'sáng', 'coffee'],
      boostCategories: ['CAFE', 'BAKERY'],
    };
  }

  if (vnHour >= 10.5 && vnHour < 14) {
    return {
      period: 'LUNCH',
      label: 'Bữa trưa ngon & Nhanh gọn',
      categories: ['RESTAURANT', 'FAST_FOOD'],
      keywords: ['cơm', 'bún', 'mì', 'trưa', 'cơm tấm', 'cơm văn phòng'],
      boostCategories: ['RESTAURANT', 'FAST_FOOD'],
    };
  }

  if (vnHour >= 14 && vnHour < 17.5) {
    return {
      period: 'AFTERNOON',
      label: 'Trà chiều, Trà sữa & Ăn vặt chill',
      categories: ['MILK_TEA', 'CAFE', 'DESSERT', 'BAKERY'],
      keywords: ['trà sữa', 'bánh ngọt', 'chè', 'ăn vặt', 'chill', 'trà'],
      boostCategories: ['MILK_TEA', 'CAFE', 'DESSERT'],
    };
  }

  return {
    period: 'DINNER_NIGHT',
    label: 'Bữa tối, Lẩu nướng & Tụ họp bạn bè',
    categories: ['RESTAURANT', 'BBQ', 'BUFFET', 'BAR'],
    keywords: ['lẩu', 'nướng', 'nhậu', 'hải sản', 'tối', 'bia', 'steak'],
    boostCategories: ['RESTAURANT', 'BBQ', 'BUFFET', 'BAR'],
  };
};

/**
 * Build dynamic user taste & preference profile from interaction history and explicit profile settings
 */
export const buildUserTasteProfile = async (user) => {
  if (!user || !user._id) {
    return null;
  }

  const categoryScores = {};
  const vibeScores = {};
  const interactedBusinesses = {};
  let totalInteractions = 0;

  // 1. Explicit preferences from profile (highest base weight)
  if (user.preferences?.favoriteCategories?.length) {
    user.preferences.favoriteCategories.forEach((cat, index) => {
      // Priority bonus: first preference gets highest weight
      const bonus = index === 0 ? 50 : 35;
      categoryScores[cat] = (categoryScores[cat] || 0) + bonus;
    });
  }

  if (user.preferences?.vibes?.length) {
    user.preferences.vibes.forEach((v, index) => {
      const bonus = index === 0 ? 30 : 20;
      vibeScores[v] = (vibeScores[v] || 0) + bonus;
    });
  }

  // 2. Fetch interactions for this specific user
  const interactions = await UserInteraction.find({ userId: user._id })
    .populate('businessId', 'categories vibes priceRange name')
    .sort({ createdAt: -1 })
    .limit(150)
    .lean();

  totalInteractions = interactions.length;

  const ACTION_WEIGHTS = {
    ORDER: 16,
    BOOKING: 14,
    FAVORITE: 12,
    REVIEW: 10,
    CLICK: 4,
    SEARCH: 3,
    VIEW: 2,
    RATING: 8,
  };

  const interactionBreakdown = {
    VIEW: 0,
    CLICK: 0,
    FAVORITE: 0,
    BOOKING: 0,
    ORDER: 0,
    REVIEW: 0,
    SEARCH: 0,
  };

  interactions.forEach((item) => {
    if (interactionBreakdown[item.type] !== undefined) {
      interactionBreakdown[item.type] += 1;
    }
    const weight = ACTION_WEIGHTS[item.type] || 2;
    const biz = item.businessId;

    if (biz && biz._id) {
      const bizIdStr = biz._id.toString();
      if (!interactedBusinesses[bizIdStr]) {
        interactedBusinesses[bizIdStr] = {
          count: 0,
          types: new Set(),
          lastInteractedAt: item.createdAt,
        };
      }
      interactedBusinesses[bizIdStr].count += 1;
      interactedBusinesses[bizIdStr].types.add(item.type);

      // Category affinities
      if (Array.isArray(biz.categories)) {
        biz.categories.forEach((cat) => {
          categoryScores[cat] = (categoryScores[cat] || 0) + weight;
        });
      }

      // Vibe affinities
      if (Array.isArray(biz.vibes)) {
        biz.vibes.forEach((v) => {
          const cleanVibe = v.trim();
          if (cleanVibe) {
            vibeScores[cleanVibe] = (vibeScores[cleanVibe] || 0) + weight;
          }
        });
      }
    }

    // Keyword affinities from search
    if (item.type === 'SEARCH' && item.metadata?.keyword) {
      const kw = item.metadata.keyword.toLowerCase();
      if (kw.includes('cà phê') || kw.includes('cafe')) categoryScores['CAFE'] = (categoryScores['CAFE'] || 0) + 8;
      if (kw.includes('trà sữa') || kw.includes('chè')) categoryScores['MILK_TEA'] = (categoryScores['MILK_TEA'] || 0) + 8;
      if (kw.includes('lẩu') || kw.includes('nướng') || kw.includes('bbq')) categoryScores['BBQ'] = (categoryScores['BBQ'] || 0) + 8;
      if (kw.includes('cơm') || kw.includes('phở') || kw.includes('hải sản') || kw.includes('bún')) categoryScores['RESTAURANT'] = (categoryScores['RESTAURANT'] || 0) + 8;
      if (kw.includes('bánh mì') || kw.includes('bánh')) categoryScores['BAKERY'] = (categoryScores['BAKERY'] || 0) + 8;
    }
  });

  // Sort top categories
  const sortedCategories = Object.entries(categoryScores)
    .sort(([, a], [, b]) => b - a)
    .map(([cat]) => cat);

  // Sort top vibes
  const sortedVibes = Object.entries(vibeScores)
    .sort(([, a], [, b]) => b - a)
    .map(([v]) => v);

  return {
    userId: user._id,
    hasInteractions: totalInteractions > 0 || (user.preferences?.favoriteCategories?.length || 0) > 0,
    totalInteractions,
    interactionBreakdown,
    categoryScores,
    sortedCategories,
    topCategories: sortedCategories.slice(0, 5),
    vibeScores,
    sortedVibes,
    topVibes: sortedVibes.slice(0, 5),
    interactedBusinesses,
    explicitPreferences: user.preferences || {},
  };
};

/**
 * Generate human-friendly personalized reason for recommendation
 */
const generateRecommendationReason = (bus, userProfile, timeContext) => {
  const bizIdStr = bus._id ? bus._id.toString() : '';
  const interactions = userProfile?.interactedBusinesses?.[bizIdStr];

  // 1. If user previously interacted intensely
  if (interactions) {
    if (interactions.types.has('FAVORITE')) {
      return '❤️ Quán trong danh sách Yêu thích của bạn';
    }
    if (interactions.types.has('ORDER') || interactions.types.has('BOOKING')) {
      return '⭐ Quán bạn đã từng đặt món & hài lòng';
    }
    if (interactions.count >= 2) {
      return '🔥 Quán bạn thường xuyên quan tâm';
    }
  }

  // 2. Matching user favorite categories
  if (userProfile?.topCategories?.length && bus.categories?.length) {
    const matchedCat = bus.categories.find((c) => userProfile.topCategories.includes(c));
    if (matchedCat) {
      const catNames = {
        CAFE: 'Cà phê & Chill',
        RESTAURANT: 'Ẩm thực & Nhà hàng',
        MILK_TEA: 'Trà sữa & Đồ ngọt',
        BBQ: 'Lẩu & Nướng',
        BUFFET: 'Buffet',
        BAKERY: 'Bánh ngọt & Bánh mì',
        DESSERT: 'Ăn vặt & Tráng miệng',
        BAR: 'Bar & Cocktail Pub',
        FAST_FOOD: 'Đồ ăn nhanh',
      };
      const catLabel = catNames[matchedCat] || matchedCat;
      if (userProfile.topVibes?.length && bus.vibes?.length) {
        const matchedVibe = bus.vibes.find((v) => userProfile.topVibes.includes(v));
        if (matchedVibe) {
          return `✨ Chuẩn gu ${catLabel} & phong cách "${matchedVibe}" của bạn`;
        }
      }
      return `⚡ Rất phù hợp với sở thích ${catLabel} của bạn`;
    }
  }

  // 3. Time of day contextual fit
  if (timeContext?.boostCategories?.length && bus.categories?.length) {
    const timeMatch = bus.categories.some((c) => timeContext.boostCategories.includes(c));
    if (timeMatch) {
      return `☀️ Gợi ý ${timeContext.label} đang rất được chuộng`;
    }
  }

  // 4. High ratings
  if (bus.googleRating?.rating && bus.googleRating.rating >= 4.6) {
    return `⭐ Đánh giá ${bus.googleRating.rating}★ xuất sắc trên Google Maps`;
  }
  if (bus.ratingSummary?.average && bus.ratingSummary.average >= 4.5) {
    return `🏆 Đạt ${bus.ratingSummary.average}★ được yêu thích trên FConnect`;
  }

  return '🌟 Địa điểm F&B nổi bật được cộng đồng đánh giá cao';
};

/**
 * Score and personalize a list of businesses (0 - 100 points scale)
 */
export const personalizeBusinesses = async (businesses, user, options = {}) => {
  if (!businesses || businesses.length === 0) {
    return [];
  }

  const timeContext = getTimeOfDayContext();
  const userProfile = await buildUserTasteProfile(user);

  // Aggregate general interactions for baseline signals
  const bizIds = businesses.map((b) => b._id);
  const interactionAgg = await UserInteraction.aggregate([
    {
      $match: {
        businessId: { $in: bizIds },
      },
    },
    {
      $group: {
        _id: '$businessId',
        clicks: {
          $sum: {
            $cond: [
              { $in: ['$type', ['CLICK', 'VIEW', 'BOOKING', 'ORDER', 'FAVORITE']] },
              1,
              0,
            ],
          },
        },
        searches: {
          $sum: {
            $cond: [{ $eq: ['$type', 'SEARCH'] }, 1, 0],
          },
        },
      },
    },
  ]);

  const interactionMap = {};
  interactionAgg.forEach((item) => {
    if (item._id) interactionMap[item._id.toString()] = item;
  });

  return businesses.map((b) => {
    const bObj = typeof b.toObject === 'function' ? b.toObject() : { ...b };
    const bId = b._id.toString();
    const clicks = interactionMap[bId]?.clicks || 0;
    const searches = interactionMap[bId]?.searches || 0;
    const ggRating = b.googleRating?.rating || 4.0;
    const ggReviews = b.googleRating?.userRatingsTotal || 50;
    const internalRating = b.ratingSummary?.average || 0;
    const internalReviews = b.ratingSummary?.totalReviews || 0;

    // --- 1. Base Quality / Reputation (Max 30 pts) ---
    // Google Maps rating (max 18)
    const googleRatingScore = Math.min((ggRating / 5) * 18, 18);
    // Review volume log curve (max 6)
    const reviewVolumeScore = Math.min(Math.log10(Math.max(1, ggReviews)) * 1.8, 6);
    // Platform community rating (max 6)
    const internalRatingScore = Math.min((internalRating / 5) * 6, 6);
    const baseReputation = Math.round((googleRatingScore + reviewVolumeScore + internalRatingScore) * 10) / 10;

    // --- 2. Personal Taste & Affinity Points (Max 50 pts) ---
    let tastePoints = 0;
    let isPersonalized = false;

    if (userProfile && userProfile.hasInteractions) {
      isPersonalized = true;

      // Category matching:
      if (b.categories && Array.isArray(b.categories)) {
        b.categories.forEach((cat) => {
          const rank = userProfile.topCategories.indexOf(cat);
          if (rank === 0) tastePoints += 32;       // #1 Favorite Category
          else if (rank === 1) tastePoints += 22;  // #2 Category
          else if (rank === 2) tastePoints += 14;  // #3 Category
          else if (userProfile.categoryScores[cat] > 0) tastePoints += 8;
        });
      }

      // Vibe matching (Max 10 pts):
      if (b.vibes && Array.isArray(b.vibes) && userProfile.topVibes?.length) {
        b.vibes.forEach((v) => {
          if (userProfile.topVibes.includes(v.trim())) {
            tastePoints += 5;
          }
        });
      }

      // Past interactions with this specific business (Max 15 pts):
      const userBizHistory = userProfile.interactedBusinesses[bId];
      if (userBizHistory) {
        if (userBizHistory.types.has('FAVORITE')) tastePoints += 12;
        if (userBizHistory.types.has('ORDER') || userBizHistory.types.has('BOOKING')) tastePoints += 10;
        if (userBizHistory.count > 0) tastePoints += Math.min(userBizHistory.count * 2, 6);
      }

      // Budget fit (Max 5 pts):
      const userMaxBudget = userProfile.explicitPreferences?.priceRange?.max;
      if (userMaxBudget && b.priceRange?.max) {
        if (b.priceRange.max <= userMaxBudget) {
          tastePoints += 5;
        } else if (b.priceRange.min > userMaxBudget * 1.4) {
          tastePoints -= 8;
        }
      }
    }

    // --- 3. Contextual Time of Day Boost (Max 12 pts) ---
    let timeBoost = 0;
    if (b.categories && Array.isArray(b.categories) && timeContext.boostCategories) {
      const match = b.categories.some((c) => timeContext.boostCategories.includes(c));
      if (match) {
        timeBoost = 12;
      }
    }

    // Final composite score (0 - 100)
    let finalScore;
    if (isPersonalized) {
      // 30 base + up to 50 taste + 12 time boost + 8 bonus
      finalScore = Math.min(
        Math.round(baseReputation + Math.min(tastePoints, 50) + timeBoost),
        99
      );
    } else {
      // Cold-start / Guest user: Scale base reputation + time boost + slight hash variance
      const hashBonus = (bId.charCodeAt(bId.length - 1) % 6);
      finalScore = Math.min(
        Math.round((baseReputation * 2.2) + (timeBoost * 1.5) + hashBonus),
        95
      );
    }

    const recommendationReason = generateRecommendationReason(b, userProfile, timeContext);

    return {
      ...bObj,
      interactionStats: { clicks, searches },
      popularityScore: baseReputation,
      personalizedScore: finalScore,
      matchPercentage: Math.max(finalScore, 50),
      isPersonalized,
      recommendationReason,
      timeContextLabel: timeContext.label,
    };
  });
};

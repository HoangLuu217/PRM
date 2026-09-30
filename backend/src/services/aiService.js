import { Business, Branch, Product, Menu, UserInteraction } from '../models/index.js';
import { personalizeBusinesses } from './recommendationService.js';
import { generateAINearMeSommelierInsight } from './geminiService.js';



/**
 * Haversine formula to calculate distance in kilometers between two geo points
 */
const calculateHaversineDistanceKm = (coord1, coord2) => {
  if (!coord1 || !coord2 || coord1.length < 2 || coord2.length < 2) return 0;
  const [lng1, lat1] = coord1;
  const [lng2, lat2] = coord2;

  const R = 6371; // Earth radius in km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c * 10) / 10;
};

/**
 * Helper to build Google Maps route URL for stops
 */
const buildGoogleMapsRouteUrl = (stops) => {
  if (!stops || stops.length === 0) return '';
  const validStops = stops.filter((s) => s.coordinates && s.coordinates.length >= 2);
  if (validStops.length === 0) return '';

  const origin = `${validStops[0].coordinates[1]},${validStops[0].coordinates[0]}`;
  const destination = `${validStops[validStops.length - 1].coordinates[1]},${validStops[validStops.length - 1].coordinates[0]}`;

  if (validStops.length <= 2) {
    return `https://www.google.com/maps/dir/?api=1&origin=${origin}&destination=${destination}`;
  }

  const waypoints = validStops
    .slice(1, -1)
    .map((s) => `${s.coordinates[1]},${s.coordinates[0]}`)
    .join('|');

  return `https://www.google.com/maps/dir/?api=1&origin=${origin}&destination=${destination}&waypoints=${encodeURIComponent(waypoints)}`;
};

/**
 * Helper to extract search keywords from city/province input (handles aliases like 'Kiên Giang (Phú Quốc)')
 */
const extractCitySearchKeywords = (city) => {
  const rawCity = (city || '').trim();
  const parenMatch = rawCity.match(/\((.*?)\)/);
  const aliasName = parenMatch ? parenMatch[1].trim() : null;
  const cleanCity = rawCity
    .replace(/^(Thành phố|Tỉnh|TP\.?)\s+/i, '')
    .replace(/\s*\(.*?\)\s*/g, '')
    .trim();

  const keywords = [cleanCity];
  if (aliasName && aliasName.toLowerCase() !== cleanCity.toLowerCase()) {
    keywords.push(aliasName);
  }
  return keywords.filter(Boolean);
};

const buildBranchCityFilter = (city) => {
  const keywords = extractCitySearchKeywords(city);
  return {
    status: 'ACTIVE',
    $or: keywords.flatMap((kw) => [
      { 'address.city': { $regex: kw, $options: 'i' } },
      { 'address.district': { $regex: kw, $options: 'i' } },
      { 'address.street': { $regex: kw, $options: 'i' } },
      { 'address.ward': { $regex: kw, $options: 'i' } },
    ]),
  };
};

/**
 * Helper to match Categories based on Meal Type & Vibe
 */
const getCategoriesForMealType = (mealType, vibeTag = '') => {
  const tagUpper = vibeTag.toUpperCase();

  if (mealType === 'Breakfast') {
    if (tagUpper.includes('CAFE') || tagUpper.includes('PHỐ CỔ')) {
      return ['CAFE', 'BAKERY', 'RESTAURANT'];
    }
    return ['CAFE', 'BAKERY', 'FAST_FOOD', 'RESTAURANT'];
  }

  if (mealType === 'Lunch') {
    if (tagUpper.includes('HẢI SẢN') || tagUpper.includes('BIỂN')) {
      return ['RESTAURANT', 'BBQ'];
    }
    if (tagUpper.includes('ĂN VẶT')) {
      return ['FAST_FOOD', 'RESTAURANT', 'OTHER'];
    }
    return ['RESTAURANT', 'BBQ', 'BUFFET', 'FAST_FOOD'];
  }

  if (mealType === 'Cafe') {
    return ['CAFE', 'MILK_TEA', 'DESSERT', 'BAKERY'];
  }

  if (mealType === 'Dinner') {
    if (tagUpper.includes('HẢI SẢN') || tagUpper.includes('BIỂN')) {
      return ['RESTAURANT', 'BBQ', 'BUFFET'];
    }
    if (tagUpper.includes('CHECK-IN') || tagUpper.includes('FINE DINING')) {
      return ['RESTAURANT', 'BAR', 'BUFFET'];
    }
    return ['RESTAURANT', 'BBQ', 'BUFFET', 'BAR'];
  }

  return ['RESTAURANT', 'CAFE', 'MILK_TEA', 'BBQ', 'BUFFET', 'BAKERY', 'DESSERT', 'BAR'];
};

/**
 * AI Recommendation Engine
 */
export const getAIRecommendations = async (user, filters = {}) => {
  const { city = 'Đà Nẵng', vibe, maxBudget, category } = filters;

  const branchFilter = buildBranchCityFilter(city);
  const branchBizIds = await Branch.distinct('businessId', branchFilter);

  const query = {
    status: 'APPROVED',
    _id: { $in: branchBizIds },
  };

  if (category && category !== 'Tất cả' && category !== 'ALL') {
    query.categories = category;
  }

  if (vibe) {
    query.vibes = { $regex: vibe, $options: 'i' };
  }

  if (maxBudget && !isNaN(Number(maxBudget))) {
    query['priceRange.min'] = { $lte: Number(maxBudget) };
  }

  const candidateBusinesses = await Business.find(query);
  const personalized = await personalizeBusinesses(candidateBusinesses, user);

  let scored = personalized.map((bus) => {
    let vipBoost = 0;
    if (bus.subscription?.status === 'ACTIVE' && bus.subscription?.plan === 'PRO') {
      vipBoost = 15;
    }
    const baseScore = bus.personalizedScore || bus.matchPercentage || 85;
    const finalScore = Math.min(99, baseScore + vipBoost);

    return {
      business: bus,
      aiMatchScore: finalScore,
      matchReason: generateMatchReason(bus, user, vibe),
      isPersonalized: bus.isPersonalized,
      timeContextLabel: bus.timeContextLabel,
      isVipRecommended: vipBoost > 0,
    };
  });

  scored.sort((a, b) => b.aiMatchScore - a.aiMatchScore);

  // If cold-start (unpersonalized), diversify across top culinary categories
  const isUserPersonalized = scored.some((s) => s.isPersonalized);
  if (!isUserPersonalized && (!category || category === 'ALL')) {
    const diversified = [];
    const seenCategories = new Set();
    const remaining = [];

    scored.forEach((item) => {
      const primaryCat = item.business.categories?.[0] || 'OTHER';
      if (!seenCategories.has(primaryCat) && diversified.length < 8) {
        seenCategories.add(primaryCat);
        diversified.push(item);
      } else {
        remaining.push(item);
      }
    });

    scored = [...diversified, ...remaining];
  }

  return scored.slice(0, 10);
};

const generateMatchReason = (bus, user, vibe) => {
  const reasons = [];
  if (bus.subscription?.status === 'ACTIVE' && bus.subscription?.plan === 'PRO') {
    reasons.push('⭐ Đối tác Uy Tín VIP được FConnect & AI thẩm định chất lượng');
  }
  if (bus.ratingSummary?.average >= 4.5) {
    reasons.push(`⭐ Đánh giá nổi bật ${bus.ratingSummary.average}/5 sao trên hệ thống`);
  }
  if (bus.categories?.length) {
    reasons.push(`🍲 Chuyên ẩm thực ${bus.categories.slice(0, 2).join(', ')}`);
  }
  if (vibe) {
    reasons.push(`✨ Chuẩn gu phong cách "${vibe}"`);
  }
  if (reasons.length === 0) {
    reasons.push('💡 Không gian & chất lượng dịch vụ xuất sắc trên FConnect');
  }
  return reasons.join(' • ');
};

/**
 * Get AI Recommended Dishes for User (Tinder Swipe)
 * Sources dishes from active menus of restaurants specifically recommended for the user.
 */
export const getAIRecommendedDishes = async (user, filters = {}) => {
  const { city = 'Đà Nẵng', category, vibe, limit = 30 } = filters;

  // 1. Get AI recommended businesses for the user
  const bizRecs = await getAIRecommendations(user, { city, category, vibe });
  if (!bizRecs || bizRecs.length === 0) return [];

  // Map of businessId -> recommendation metadata
  const bizRecMap = new Map();
  bizRecs.forEach((r) => {
    if (r.business?._id) {
      bizRecMap.set(r.business._id.toString(), r);
    }
  });

  // Take top recommended business IDs (up to 20 businesses)
  const topBizIds = bizRecs.slice(0, 20).map((r) => r.business._id);

  // 2. Find active menus belonging to these recommended businesses
  const menus = await Menu.find({
    businessId: { $in: topBizIds },
    status: 'ACTIVE',
  }).lean();

  const menuIds = menus.map((m) => m._id);

  // 3. Find available products in those menus
  let products = await Product.find({
    menuId: { $in: menuIds },
    isAvailable: true,
  })
    .populate('menuId')
    .lean();

  // If few products found, also include products from any menu of top businesses
  if (products.length < 5) {
    const allBizMenus = await Menu.find({
      businessId: { $in: topBizIds },
    }).lean();
    const allMenuIds = allBizMenus.map((m) => m._id);
    products = await Product.find({
      menuId: { $in: allMenuIds },
    })
      .populate('menuId')
      .lean();
  }

  // User preferences
  const userFavCategories = user?.preferences?.favoriteCategories || [];
  const userPriceRange = user?.preferences?.priceRange || { min: 0, max: 500000 };

  // 4. Transform and enrich each dish with dish-level personalization score & reason
  const dishes = products
    .map((prod) => {
      const bizId = prod.menuId?.businessId?.toString();
      const rec = bizRecMap.get(bizId);
      if (!rec) return null;

      let dishScore = rec.aiMatchScore || 85;
      let dishReason = '';

      const prodNameLower = (prod.name || '').toLowerCase();
      const prodCatLower = (prod.category || '').toLowerCase();
      const bizCat = rec.business.categories || [];

      // Detect specific culinary characteristics of the dish
      const isBakeryDish = prodNameLower.includes('bánh') || prodCatLower.includes('bánh') || prodCatLower.includes('bakery') || prodCatLower.includes('pastry');
      const isMilkTeaDish = prodNameLower.includes('trà sữa') || prodCatLower.includes('trà sữa') || prodCatLower.includes('milk tea');
      const isTeaDish = !isMilkTeaDish && (prodNameLower.includes('trà') || prodCatLower.includes('trà') || prodCatLower.includes('tea'));
      const isCafeDish = prodNameLower.includes('cà phê') || prodNameLower.includes('cafe') || prodNameLower.includes('phin') || prodNameLower.includes('cold brew') || prodCatLower.includes('cà phê') || prodCatLower.includes('coffee');
      const isBbqDish = prodNameLower.includes('nướng') || prodNameLower.includes('lẩu') || prodNameLower.includes('bbq') || prodCatLower.includes('nướng');
      const isPizzaDish = prodNameLower.includes('pizza') || prodNameLower.includes('pasta') || prodNameLower.includes('mì ý');

      // Check category match against user favorite tastes
      if (isBakeryDish && userFavCategories.includes('BAKERY')) {
        dishScore += 5;
        dishReason = '🥐 Món bánh chuẩn khẩu vị của bạn';
      } else if (isCafeDish && userFavCategories.includes('CAFE')) {
        dishScore += 5;
        dishReason = '☕ Chuẩn khẩu vị Cà phê của bạn';
      } else if (isMilkTeaDish && userFavCategories.includes('MILK_TEA')) {
        dishScore += 5;
        dishReason = '🧋 Trà sữa ngọt ngào đúng khẩu vị';
      } else if (isTeaDish && (userFavCategories.includes('CAFE') || userFavCategories.includes('MILK_TEA'))) {
        dishScore += 4;
        dishReason = '🍵 Món trà thanh mát đúng gu của bạn';
      } else if (isBbqDish && userFavCategories.includes('BBQ')) {
        dishScore += 5;
        dishReason = '🔥 Món nướng/lẩu chuẩn khẩu vị của bạn';
      } else if (isPizzaDish && (userFavCategories.includes('FASTFOOD') || userFavCategories.includes('RESTAURANT'))) {
        dishScore += 4;
        dishReason = '🍕 Món phong cách Âu - Ý chuẩn gu';
      } else if (userFavCategories.some(cat => bizCat.includes(cat))) {
        dishScore += 3;
        dishReason = '✨ Món ngon đúng gu ẩm thực của bạn';
      }

      // Check favorite restaurant
      if (rec.matchReason?.includes('Yêu thích')) {
        dishScore += 3;
        dishReason = dishReason ? `${dishReason} • Quán yêu thích` : '❤️ Món đặc sắc từ quán bạn yêu thích';
      } else if (rec.matchReason?.includes('thường xuyên')) {
        dishScore += 2;
        dishReason = dishReason ? `${dishReason} • Quán quen` : '🔥 Món nổi bật tại quán bạn thường ghé';
      }

      // Check budget match
      if (prod.price >= userPriceRange.min && prod.price <= userPriceRange.max) {
        dishScore += 2;
      }

      if (!dishReason) {
        dishReason = rec.matchReason || 'Món ngon nổi bật theo gu của bạn';
      }

      // Cap at 98%
      dishScore = Math.min(98, dishScore);

      return {
        _id: prod._id,
        name: prod.name,
        description: prod.description || '',
        price: prod.price,
        imageUrl:
          prod.imageUrl ||
          'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=600&q=80',
        category: prod.category || 'Món đặc sắc',
        sizes: prod.sizes || [],
        options: prod.options || [],
        business: {
          _id: rec.business._id,
          name: rec.business.name,
          slug: rec.business.slug,
          logoUrl: rec.business.logoUrl,
          coverUrl: rec.business.coverUrl || rec.business.coverImageUrl,
          coverImageUrl: rec.business.coverImageUrl || rec.business.coverUrl,
          rating: rec.business.rating,
          reviewCount: rec.business.reviewCount,
          categories: rec.business.categories,
          vibes: rec.business.vibes,
          priceRange: rec.business.priceRange,
          address: rec.business.address,
          description: rec.business.description,
          phone: rec.business.phone,
          googleMapsUrl: rec.business.googleMapsUrl,
        },
        aiMatchScore: dishScore,
        matchReason: dishReason,
        isPersonalized: true,
      };
    })
    .filter(Boolean);

  // 5. Sort dishes: higher AI Match Score first, prioritize items with real images
  dishes.sort((a, b) => {
    const scoreDiff = b.aiMatchScore - a.aiMatchScore;
    if (Math.abs(scoreDiff) > 2) return scoreDiff;

    const aHasImg = a.imageUrl && !a.imageUrl.includes('photo-1546069901') ? 1 : 0;
    const bHasImg = b.imageUrl && !b.imageUrl.includes('photo-1546069901') ? 1 : 0;
    return bHasImg - aHasImg;
  });

  return dishes.slice(0, limit);
};

/**
 * Check if a branch is open right now based on openingHours array (VN time UTC+7)
 */
export const checkBranchIsOpenNow = (openingHours) => {
  if (!openingHours || openingHours.length === 0) {
    return { isOpen: true, hoursText: '07:00 - 22:30' };
  }

  const now = new Date();
  const utc = now.getTime() + now.getTimezoneOffset() * 60000;
  const vnDate = new Date(utc + 3600000 * 7);
  const currentDay = vnDate.getDay(); // 0 = Sun, 1 = Mon ...
  const currentMinutes = vnDate.getHours() * 60 + vnDate.getMinutes();

  const todaySchedule = openingHours.find((h) => h.day === currentDay) || openingHours[0];
  if (!todaySchedule || !todaySchedule.open || !todaySchedule.close) {
    return { isOpen: true, hoursText: '07:00 - 22:30' };
  }

  const parseMins = (str) => {
    if (!str) return 0;
    const parts = str.split(':').map(Number);
    return (parts[0] || 0) * 60 + (parts[1] || 0);
  };

  const openMins = parseMins(todaySchedule.open);
  const closeMins = parseMins(todaySchedule.close);

  let isOpen = false;
  if (closeMins > openMins) {
    isOpen = currentMinutes >= openMins && currentMinutes <= closeMins;
  } else {
    // Overnight operation (e.g. 18:00 - 02:00)
    isOpen = currentMinutes >= openMins || currentMinutes <= closeMins;
  }

  return {
    isOpen,
    hoursText: `${todaySchedule.open} - ${todaySchedule.close}`,
  };
};

/**
 * Check if a business matches a specific user mood or culinary vibe
 */
const checkMoodRelevance = (bus, branchProducts = [], mood = '', vibe = '') => {
  if (!mood || mood === 'ALL' || mood === 'TẤT CẢ') {
    return { isMatch: true, bonus: 0, badge: null };
  }

  const moodUpper = (mood || '').toUpperCase();
  const vibeLower = (vibe || '').toLowerCase();
  const busCats = (bus.categories || []).map((c) => c.toUpperCase());
  const busVibes = (bus.vibes || []).map((v) => v.toLowerCase());
  const busNameLower = (bus.name || '').toLowerCase();
  const busDescLower = (bus.description || '').toLowerCase();
  const prodNamesLower = branchProducts.map((p) => (p.name || '').toLowerCase());

  let isMatch = false;
  let label = '';

  if (moodUpper === 'CAFE' || vibeLower.includes('cafe') || vibeLower.includes('cà phê')) {
    label = 'Cafe Chill';
    const hasCat = busCats.includes('CAFE') || busCats.includes('BAKERY');
    const hasVibe = busVibes.some((v) => v.includes('cafe') || v.includes('cà phê') || v.includes('chill') || v.includes('làm việc') || v.includes('trà'));
    const hasName = busNameLower.includes('cafe') || busNameLower.includes('cà phê') || busNameLower.includes('coffee') || busNameLower.includes('tea') || busNameLower.includes('trà');
    const hasProd = prodNamesLower.some((p) => p.includes('cafe') || p.includes('cà phê') || p.includes('latte') || p.includes('cappuccino') || p.includes('espresso') || p.includes('trà'));
    isMatch = hasCat || hasVibe || hasName || hasProd;
  } else if (moodUpper === 'SEAFOOD' || vibeLower.includes('hải sản') || vibeLower.includes('bbq')) {
    label = 'Hải Sản & BBQ';
    const hasCat = busCats.includes('BBQ') || busCats.includes('BUFFET');
    const hasVibe = busVibes.some((v) => v.includes('hải sản') || v.includes('bbq') || v.includes('nướng') || v.includes('lẩu') || v.includes('seafood') || v.includes('biển'));
    const hasName = busNameLower.includes('hải sản') || busNameLower.includes('bbq') || busNameLower.includes('nướng') || busNameLower.includes('lẩu') || busNameLower.includes('seafood') || busNameLower.includes('quán nướng');
    const hasProd = prodNamesLower.some((p) => p.includes('hải sản') || p.includes('tôm') || p.includes('cua') || p.includes('cá') || p.includes('mực') || p.includes('ốc') || p.includes('bò nướng') || p.includes('lẩu'));
    isMatch = hasCat || hasVibe || hasName || hasProd;
  } else if (moodUpper === 'SNACK' || vibeLower.includes('ăn vặt') || vibeLower.includes('trà sữa')) {
    label = 'Ăn Vặt & Trà Sữa';
    const hasCat = busCats.includes('MILK_TEA') || busCats.includes('DESSERT') || busCats.includes('FAST_FOOD') || busCats.includes('BAKERY');
    const hasVibe = busVibes.some((v) => v.includes('ăn vặt') || v.includes('trà sữa') || v.includes('bánh') || v.includes('kem') || v.includes('chè'));
    const hasName = busNameLower.includes('trà sữa') || busNameLower.includes('ăn vặt') || busNameLower.includes('bánh tráng') || busNameLower.includes('chè') || busNameLower.includes('kem') || busNameLower.includes('tea') || busNameLower.includes('boba');
    const hasProd = prodNamesLower.some((p) => p.includes('trà sữa') || p.includes('trà đào') || p.includes('bánh') || p.includes('kem') || p.includes('nem chua') || p.includes('khoai tây'));
    isMatch = hasCat || hasVibe || hasName || hasProd;
  } else if (moodUpper === 'NIGHT' || vibeLower.includes('nhậu') || vibeLower.includes('bar') || vibeLower.includes('pub')) {
    label = 'Nhậu Đêm & Bar Pub';
    const hasCat = busCats.includes('BAR') || busCats.includes('BBQ');
    const hasVibe = busVibes.some((v) => v.includes('nhậu') || v.includes('bar') || v.includes('pub') || v.includes('bia') || v.includes('beer') || v.includes('sôi động') || v.includes('đêm'));
    const hasName = busNameLower.includes('bar') || busNameLower.includes('pub') || busNameLower.includes('bia') || busNameLower.includes('beer') || busNameLower.includes('quán nhậu') || busNameLower.includes('lounge');
    const hasProd = prodNamesLower.some((p) => p.includes('bia') || p.includes('beer') || p.includes('cocktail') || p.includes('mồi') || p.includes('nhắm'));
    isMatch = hasCat || hasVibe || hasName || hasProd;
  } else if (moodUpper === 'VEGAN' || vibeLower.includes('chay') || vibeLower.includes('thanh đạm')) {
    label = 'Món Chay Thanh Tịnh';
    const hasCat = busCats.includes('OTHER');
    const hasVibe = busVibes.some((v) => v.includes('chay') || v.includes('thanh đạm') || v.includes('thanh tịnh') || v.includes('vegan') || v.includes('rau củ'));
    const hasName = busNameLower.includes('chay') || busNameLower.includes('vegan') || busNameLower.includes('thanh tịnh') || busNameLower.includes('thực dưỡng');
    const hasProd = prodNamesLower.some((p) => p.includes('chay') || p.includes('nấm') || p.includes('đậu hũ') || p.includes('rau củ'));
    isMatch = hasCat || hasVibe || hasName || hasProd;
  } else if (moodUpper === 'MEAL' || vibeLower.includes('ăn sáng') || vibeLower.includes('ăn trưa') || vibeLower.includes('bản địa')) {
    label = 'Ăn Sáng / Trưa No';
    const hasCat = busCats.includes('RESTAURANT') || busCats.includes('FAST_FOOD') || busCats.includes('BUFFET');
    const hasVibe = busVibes.some((v) => v.includes('bản địa') || v.includes('truyền thống') || v.includes('cơm') || v.includes('đặc sản'));
    const hasName = busNameLower.includes('cơm') || busNameLower.includes('phở') || busNameLower.includes('bún') || busNameLower.includes('mì') || busNameLower.includes('bánh xèo') || busNameLower.includes('hủ tiếu') || busNameLower.includes('quán ăn') || busNameLower.includes('nhà hàng');
    const hasProd = prodNamesLower.some((p) => p.includes('cơm') || p.includes('phở') || p.includes('bún') || p.includes('mì') || p.includes('hủ tiếu') || p.includes('bánh cuốn') || p.includes('bò kho'));
    isMatch = hasCat || hasVibe || hasName || hasProd;
  }

  return {
    isMatch,
    bonus: isMatch ? 35 : -40,
    badge: isMatch ? `✨ Hợp gu "${label}"` : null,
  };
};

const CITY_COORDINATES = {
  'Đà Nẵng': { lat: 16.0544, lng: 108.2021 },
  'Hà Nội': { lat: 21.0285, lng: 105.8544 },
  'Hồ Chí Minh': { lat: 10.8231, lng: 106.6296 },
  'TP. Hồ Chí Minh': { lat: 10.8231, lng: 106.6296 },
  'Hải Phòng': { lat: 20.8449, lng: 106.6880 },
  'Cần Thơ': { lat: 10.0451, lng: 105.7468 },
  'Huế': { lat: 16.4637, lng: 107.5908 },
  'Thừa Thiên Huế': { lat: 16.4637, lng: 107.5908 },
  'Khánh Hòa': { lat: 12.2387, lng: 109.1967 },
  'Lâm Đồng': { lat: 11.9404, lng: 108.4583 },
  'Quảng Nam': { lat: 15.5994, lng: 108.4754 },
  'Quảng Ngãi': { lat: 15.1205, lng: 108.7923 },
};

/**
 * AI Instant Near-Me Recommendation Engine
 * Real-time discovery for users already in location: finds closest restaurants,
 * filters by craving/vibe/keyword, checks open hours, and fetches signature dishes.
 */
export const getAINearMeRecommendations = async (user, {
  latitude,
  longitude,
  city = 'Đà Nẵng',
  maxDistanceKm = 10,
  mood = '',
  vibe = '',
  category = '',
  query = '',
  openNowOnly = false,
  limit = 20,
}) => {
  const hasCoordinates = typeof latitude === 'number' && typeof longitude === 'number' && !isNaN(latitude) && !isNaN(longitude);

  let branchQuery = { status: 'ACTIVE' };
  if (!hasCoordinates && city && city !== 'ALL' && city !== 'Tất cả') {
    branchQuery = buildBranchCityFilter(city);
  }

  // Find all active branches
  let branches = await Branch.find(branchQuery).lean();

  if (!branches || branches.length === 0) {
    branches = await Branch.find({ status: 'ACTIVE' }).lean();
  }

  if (!branches || branches.length === 0) {
    return {
      totalFound: 0,
      userLocation: hasCoordinates ? { latitude, longitude } : null,
      recommendations: [],
      aiTip: 'Hiện chưa có đối tác quán ăn nào hoạt động trong khu vực này.',
      geminiInsight: 'Hiện chưa có đối tác quán ăn nào hoạt động trong khu vực này.',
    };
  }

  // Calculate precise distance for each branch from user's GPS
  const branchesWithDistance = branches.map((br) => {
    let distanceKm = 0;
    const coords = br.location?.coordinates;
    if (hasCoordinates && Array.isArray(coords) && coords.length >= 2) {
      distanceKm = calculateHaversineDistanceKm([longitude, latitude], coords);
    }

    const { isOpen, hoursText } = checkBranchIsOpenNow(br.openingHours);

    const walkingMinutes = Math.max(1, Math.round((distanceKm / 4.5) * 60));
    const drivingMinutes = Math.max(1, Math.round((distanceKm / 30) * 60));

    return {
      ...br,
      distanceKm,
      distanceMeters: Math.round(distanceKm * 1000),
      walkingMinutes,
      drivingMinutes,
      isOpenNow: isOpen,
      todayOpeningHours: hoursText,
    };
  });

  // Filter branches by radius if GPS provided
  let filteredBranches = branchesWithDistance;
  if (hasCoordinates) {
    const withinRadius = branchesWithDistance.filter((b) => b.distanceKm <= Number(maxDistanceKm));
    filteredBranches = withinRadius.length > 0 ? withinRadius : branchesWithDistance.sort((a, b) => a.distanceKm - b.distanceKm).slice(0, 20);
  }

  if (openNowOnly) {
    const openBranches = filteredBranches.filter((b) => b.isOpenNow);
    if (openBranches.length > 0) {
      filteredBranches = openBranches;
    }
  }

  // Fetch all associated Approved Businesses
  const busIds = [...new Set(filteredBranches.map((b) => b.businessId.toString()))];
  const businesses = await Business.find({
    _id: { $in: busIds },
    status: 'APPROVED',
  }).lean();

  const businessMap = new Map();
  businesses.forEach((b) => {
    businessMap.set(b._id.toString(), b);
  });

  // Fetch signature available products for these branches
  const branchIds = filteredBranches.map((b) => b._id);
  const products = await Product.find({
    branchId: { $in: branchIds },
    isAvailable: true,
  }).lean();

  const productMapByBranch = new Map();
  products.forEach((p) => {
    const key = p.branchId ? p.branchId.toString() : 'general';
    if (!productMapByBranch.has(key)) {
      productMapByBranch.set(key, []);
    }
    productMapByBranch.get(key).push(p);
  });

  // Prepare normalized search tokens
  const cleanVibe = (vibe || '').toLowerCase().trim();
  const cleanQuery = (query || '').toLowerCase().trim();
  const cleanCat = (category || '').toUpperCase().trim();
  const cleanMood = (mood || '').toUpperCase().trim();

  // Combine Branch + Business + Products and Score
  const candidates = [];

  for (const br of filteredBranches) {
    const bus = businessMap.get(br.businessId.toString());
    if (!bus) continue;

    const branchProds = productMapByBranch.get(br._id.toString()) || [];
    const busCategories = bus.categories || [];
    const busVibes = bus.vibes || [];

    // Check category match
    if (cleanCat && cleanCat !== 'ALL' && cleanCat !== 'TẤT CẢ') {
      if (!busCategories.includes(cleanCat)) {
        continue;
      }
    }

    // Check Mood / Vibe Match
    const moodCheck = checkMoodRelevance(bus, branchProds, cleanMood, cleanVibe);

    // Keyword & Vibe relevance calculation
    let relevanceScore = 80 + moodCheck.bonus;
    const matchBadges = [];

    if (moodCheck.badge) {
      matchBadges.push(moodCheck.badge);
    }

    if (br.isOpenNow) {
      relevanceScore += 5;
    }

    // Distance bonus (closer = higher score)
    if (hasCoordinates) {
      if (br.distanceKm <= 1.0) {
        relevanceScore += 12;
        matchBadges.push(`🚶 ${br.walkingMinutes}p đi bộ (${br.distanceMeters}m)`);
      } else if (br.distanceKm <= 3.0) {
        relevanceScore += 8;
        matchBadges.push(`🛵 ${br.drivingMinutes}p xe máy (${br.distanceKm}km)`);
      } else {
        matchBadges.push(`📍 ${br.distanceKm}km`);
      }
    }

    // Rating bonus
    const avgRating = (bus.ratingSummary?.totalReviews > 0) ? bus.ratingSummary.average : (bus.googleRating?.rating || 0);
    if (avgRating >= 4.7) {
      relevanceScore += 6;
      matchBadges.push(`⭐ ${avgRating}/5 đỉnh cao`);
    }

    // Search query matching (matches business name, description, vibes, or dish names)
    let isQueryMatch = true;
    if (cleanQuery) {
      const nameMatch = (bus.name || '').toLowerCase().includes(cleanQuery);
      const descMatch = (bus.description || '').toLowerCase().includes(cleanQuery);
      const vibeMatch = busVibes.some((v) => v.toLowerCase().includes(cleanQuery));
      const dishMatch = branchProds.some((p) => (p.name || '').toLowerCase().includes(cleanQuery));

      isQueryMatch = nameMatch || dishMatch || vibeMatch || descMatch;

      if (isQueryMatch) {
        relevanceScore += 40;
        if (dishMatch) {
          const matchedDish = branchProds.find((p) => (p.name || '').toLowerCase().includes(cleanQuery));
          matchBadges.unshift(`🍲 Có món "${matchedDish.name}"`);
        } else if (nameMatch) {
          matchBadges.unshift(`🔍 Khớp tên quán "${bus.name}"`);
        }
      } else {
        relevanceScore -= 50;
      }
    }

    // Select top 2-3 signature dishes
    const signatureDishes = branchProds
      .slice(0, 3)
      .map((p) => ({
        _id: p._id,
        name: p.name,
        price: p.price,
        imageUrl: p.imageUrl || bus.logoUrl,
        category: p.category || 'Món đặc sắc',
      }));

    const mapCoords = br.location?.coordinates || [108.2208, 16.0678];
    const googleMapsUrl = br.googleMapsUrl || `https://www.google.com/maps/dir/?api=1&destination=${mapCoords[1]},${mapCoords[0]}`;

    candidates.push({
      businessId: bus._id,
      branchId: br._id,
      name: bus.name,
      slug: bus.slug,
      logoUrl: bus.logoUrl,
      coverImageUrl: bus.coverImageUrl || bus.logoUrl,
      description: bus.description,
      categories: bus.categories,
      vibes: bus.vibes,
      rating: avgRating,
      reviewCount: bus.ratingSummary?.totalReviews || 0,
      priceRange: bus.priceRange || { min: 30000, max: 200000 },
      address: {
        street: br.address?.street || '',
        ward: br.address?.ward || '',
        district: br.address?.district || '',
        city: br.address?.city || city,
        fullAddress: [br.address?.street, br.address?.district, br.address?.city].filter(Boolean).join(', ') || bus.name,
      },
      phone: br.phone || '0901234567',
      coordinates: mapCoords,
      googleMapsUrl,
      distanceKm: br.distanceKm,
      distanceMeters: br.distanceMeters,
      walkingMinutes: br.walkingMinutes,
      drivingMinutes: br.drivingMinutes,
      isOpenNow: br.isOpenNow,
      todayOpeningHours: br.todayOpeningHours,
      signatureDishes,
      isMoodMatch: moodCheck.isMatch,
      isQueryMatch,
      aiScore: Math.min(99, Math.max(60, relevanceScore)),
      matchBadges,
    });
  }

  // Sort candidates: Strictly prioritize query dish match, then mood/vibe, then highest AI score & distance
  candidates.sort((a, b) => {
    // 1. If specific craving/dish query exists, strictly rank matching dishes to TOP
    if (cleanQuery) {
      if (a.isQueryMatch !== b.isQueryMatch) {
        return a.isQueryMatch ? -1 : 1;
      }
    }

    // 2. Prioritize mood match if chosen
    if (cleanMood && cleanMood !== 'ALL') {
      if (a.isMoodMatch !== b.isMoodMatch) {
        return a.isMoodMatch ? -1 : 1;
      }
    }

    // 3. Higher AI score
    const scoreDiff = b.aiScore - a.aiScore;
    if (Math.abs(scoreDiff) > 5) return scoreDiff;

    // 4. Closest distance
    if (hasCoordinates) {
      return a.distanceKm - b.distanceKm;
    }
    return scoreDiff;
  });

  // Filter out non-matching candidates if matching candidates exist
  let finalCandidates = candidates;
  if (cleanQuery) {
    const matchingQueryOnly = candidates.filter((c) => c.isQueryMatch);
    if (matchingQueryOnly.length > 0) {
      finalCandidates = matchingQueryOnly;
    }
  } else if (cleanMood && cleanMood !== 'ALL') {
    const matchingMoodOnly = candidates.filter((c) => c.isMoodMatch);
    if (matchingMoodOnly.length > 0) {
      finalCandidates = matchingMoodOnly;
    }
  }

  const finalResults = finalCandidates.slice(0, limit);


  // Determine current time of day in VN (UTC+7)
  const now = new Date();
  const utc = now.getTime() + now.getTimezoneOffset() * 60000;
  const vnHours = new Date(utc + 3600000 * 7).getHours();
  let timeOfDay = 'Trưa';
  if (vnHours >= 5 && vnHours < 11) timeOfDay = 'Sáng';
  else if (vnHours >= 11 && vnHours < 14) timeOfDay = 'Trưa';
  else if (vnHours >= 14 && vnHours < 18) timeOfDay = 'Chiều';
  else if (vnHours >= 18 && vnHours < 22) timeOfDay = 'Tối';
  else timeOfDay = 'Đêm';

  // Generate Google Gemini Sommelier Expert Insight
  let geminiInsight = '';
  try {
    geminiInsight = await generateAINearMeSommelierInsight({
      city,
      vibe,
      query,
      radius: maxDistanceKm,
      timeOfDay,
      topPlaces: finalResults,
    });
  } catch (err) {
    console.warn('Gemini insight generation skipped:', err.message);
  }

  // Generate dynamic AI Tip
  let aiTip = '';
  if (finalResults.length > 0) {
    const topPlace = finalResults[0];
    if (hasCoordinates && topPlace.distanceMeters <= 800) {
      aiTip = `💡 AI phát hiện "${topPlace.name}" chỉ cách bạn ${topPlace.distanceMeters}m (${topPlace.walkingMinutes} phút đi bộ), đang mở cửa với đánh giá ${topPlace.rating}⭐.`;
    } else {
      aiTip = `💡 AI đã tìm thấy ${finalResults.length} quán ngon phù hợp nhất quanh khu vực của bạn, sẵn sàng đón khách ngay lúc này!`;
    }
  } else {
    aiTip = 'Không tìm thấy quán nào khớp với tiêu chí tìm kiếm. Hãy thử mở rộng bán kính hoặc chọn phong cách khác.';
  }

  return {
    totalFound: finalResults.length,
    userLocation: hasCoordinates ? { latitude, longitude } : null,
    recommendations: finalResults,
    aiTip,
    geminiInsight: geminiInsight || aiTip,
  };
};




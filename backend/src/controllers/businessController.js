import { Business, Branch, Review, UserInteraction } from '../models/index.js';
import { emitBusinessUpdate } from '../socket.js';
import googleMapsService from '../services/googleMapsService.js';
import { personalizeBusinesses } from '../services/recommendationService.js';

// @desc    Get all businesses with search & filtering
// @route   GET /api/businesses
// @access  Public
export const getBusinesses = async (req, res) => {
  try {
    const {
      keyword,
      category,
      status = 'APPROVED',
      ownerId,
      city,
      minPrice,
      maxPrice,
      vibe,
      vibes,
      purpose,
      purposes,
      feature,
      features,
      sortBy,
      minRating,
      minGoogleRating,
      lat,
      lng,
      userLat,
      userLng,
    } = req.query;
    const query = {};

    if (status && status !== 'ALL') {
      query.status = status;
    }

    if (ownerId) {
      query.ownerId = ownerId;
    }

    if (category && category !== 'ALL') {
      query.categories = category;
    }

    if (city && city !== 'ALL' && city !== 'Tất cả') {
      const cleanCity = city.replace(/^(Thành phố|Tỉnh|TP\.?)\s+/i, '').trim();
      const branchBizIds = await Branch.distinct('businessId', {
        status: 'ACTIVE',
        $or: [
          { 'address.city': { $regex: cleanCity, $options: 'i' } },
          { 'address.street': { $regex: cleanCity, $options: 'i' } },
          { 'address.district': { $regex: cleanCity, $options: 'i' } },
        ],
      });
      query._id = { $in: branchBizIds };
    }

    const escapeRegex = (s) => (s ? String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&') : '');

    if (keyword) {
      const kwRegex = new RegExp(escapeRegex(keyword), 'i');
      query.$and = query.$and || [];
      query.$and.push({
        $or: [
          { name: { $regex: kwRegex } },
          { description: { $regex: kwRegex } },
        ],
      });
    }

    // Filter by Vibes (Ambiance / Space - check both vibes and spaceTags)
    const vibeFilter = vibes || vibe;
    if (vibeFilter && vibeFilter !== 'ALL') {
      const vibeList = (Array.isArray(vibeFilter) ? vibeFilter : vibeFilter.split(','))
        .map((v) => v.trim())
        .filter(Boolean);
      if (vibeList.length > 0) {
        const vibeRegexes = vibeList.map((v) => new RegExp(escapeRegex(v), 'i'));
        query.$and = query.$and || [];
        query.$and.push({
          $or: [
            { vibes: { $in: vibeRegexes } },
            { spaceTags: { $in: vibeRegexes } },
          ],
        });
      }
    }

    // Filter by Purposes (Occasion / Goal)
    const purposeFilter = purposes || purpose;
    if (purposeFilter && purposeFilter !== 'ALL') {
      const rawPurposeList = (Array.isArray(purposeFilter) ? purposeFilter : purposeFilter.split(','))
        .map((p) => p.trim())
        .filter(Boolean);
      
      const expandedPurposes = new Set(rawPurposeList);
      rawPurposeList.forEach((p) => {
        if (/bạn bè/i.test(p)) {
          expandedPurposes.add('Gặp gỡ bạn bè');
          expandedPurposes.add('Tụ tập bạn bè');
        }
        if (/tiếp khách/i.test(p)) {
          expandedPurposes.add('Tiếp khách / Đối tác');
          expandedPurposes.add('Tiếp khách / Công việc');
        }
        if (/sinh nhật|tiệc/i.test(p)) {
          expandedPurposes.add('Sinh nhật / Tiệc');
          expandedPurposes.add('Tổ chức sinh nhật / Tiệc');
        }
      });

      if (expandedPurposes.size > 0) {
        const purposeRegexes = Array.from(expandedPurposes).map((p) => new RegExp(escapeRegex(p), 'i'));
        query.$and = query.$and || [];
        query.$and.push({
          purposes: { $in: purposeRegexes },
        });
      }
    }

    // Filter by Features / Amenities (Tiện ích quán)
    const featureFilter = features || feature;
    if (featureFilter && featureFilter !== 'ALL') {
      const featureList = (Array.isArray(featureFilter) ? featureFilter : featureFilter.split(','))
        .map((f) => f.trim())
        .filter(Boolean);
      if (featureList.length > 0) {
        const featureRegexes = featureList.map((f) => new RegExp(escapeRegex(f), 'i'));
        query.$and = query.$and || [];
        query.$and.push({
          features: { $in: featureRegexes },
        });
      }
    }

    // Filter by Price Range
    if (minPrice !== undefined && minPrice !== '' && !isNaN(Number(minPrice))) {
      const minNum = Math.max(0, Number(minPrice));
      query.$and = query.$and || [];
      query.$and.push({
        $or: [
          { 'priceRange.max': { $gte: minNum } },
          { 'priceRange.min': { $gte: minNum } },
        ],
      });
    }

    if (maxPrice !== undefined && maxPrice !== '' && !isNaN(Number(maxPrice))) {
      const maxNum = Number(maxPrice);
      if (maxNum > 0) {
        query.$and = query.$and || [];
        query.$and.push({
          $or: [
            { 'priceRange.min': { $lte: maxNum } },
            { 'priceRange.min': 0 },
            { 'priceRange.min': { $exists: false } },
          ],
        });
      }
    }

    // Filter by Google Maps rating (strictly googleRating.rating >= minRateNum)
    const ratingFilter = minGoogleRating || minRating;
    if (ratingFilter !== undefined && ratingFilter !== '' && ratingFilter !== 'ALL' && !isNaN(Number(ratingFilter))) {
      const minRateNum = Number(ratingFilter);
      if (minRateNum > 0) {
        query.$and = query.$and || [];
        query.$and.push({
          'googleRating.rating': { $gte: minRateNum },
        });
      }
    }

    // Fetch matching businesses
    const businesses = await Business.find(query)
      .populate('ownerId', 'fullName email phone');

    // Compute personalized & popularity scores using recommendation engine
    const businessesWithScore = await personalizeBusinesses(businesses, req.user);

    // Fetch active branches to extract coordinates, distance & primary address
    const businessIds = businessesWithScore.map((b) => b._id);
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

    // Determine target GPS coordinates (default to center of Da Nang if not specified)
    const targetLat = !isNaN(Number(lat || userLat)) ? Number(lat || userLat) : 16.054407;
    const targetLng = !isNaN(Number(lng || userLng)) ? Number(lng || userLng) : 108.202167;

    const haversineDistKm = (lat1, lon1, lat2, lon2) => {
      const R = 6371;
      const dLat = ((lat2 - lat1) * Math.PI) / 180;
      const dLon = ((lon2 - lon1) * Math.PI) / 180;
      const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos((lat1 * Math.PI) / 180) *
          Math.cos((lat2 * Math.PI) / 180) *
          Math.sin(dLon / 2) *
          Math.sin(dLon / 2);
      return R * (2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
    };

    // Attach branches, calculate distance and format address for each business
    businessesWithScore.forEach((b) => {
      const bId = b._id.toString();
      const bBranches = branchMap[bId] || [];
      let minDistance = null;
      let closestBranch = null;

      bBranches.forEach((br) => {
        const coords = br.location?.coordinates;
        if (Array.isArray(coords) && coords.length === 2 && !isNaN(coords[0]) && !isNaN(coords[1])) {
          // coords format: [lng, lat]
          const branchLng = Number(coords[0]);
          const branchLat = Number(coords[1]);
          const d = haversineDistKm(targetLat, targetLng, branchLat, branchLng);
          if (minDistance === null || d < minDistance) {
            minDistance = d;
            closestBranch = br;
          }
        }
      });

      if (minDistance !== null) {
        b.distanceKm = Math.round(minDistance * 10) / 10;
        b.distanceText = minDistance < 1
          ? `${Math.round(minDistance * 1000)} m`
          : `${(Math.round(minDistance * 10) / 10).toFixed(1)} km`;
      } else {
        b.distanceKm = null;
        b.distanceText = null;
      }

      b.branches = bBranches;
      b.primaryBranch = closestBranch || bBranches[0] || null;
      if (b.primaryBranch?.address) {
        const street = b.primaryBranch.address.street || '';
        const district = b.primaryBranch.address.district || '';
        b.addressText = [street, district].filter(Boolean).join(', ');
      } else {
        b.addressText = '';
      }
    });

    // Sort according to sortBy query (Default: 'distance_rating' - Khoảng cách & Rating Google Maps)
    const effectiveSort = sortBy || 'distance_rating';

    // Helper to calculate subscription tier priority weight
    const getSubscriptionWeight = (b) => {
      const plan = b.subscription?.plan || 'STARTER';
      const status = b.subscription?.status || 'ACTIVE';
      if (status !== 'ACTIVE') return 0;
      if (plan === 'PRO') return 1; // Pro VIP Top Search Priority
      return 0;
    };

    if (effectiveSort === 'distance') {
      // Sort strictly by distance (closest first), tie-break with VIP plan and Google Maps rating
      businessesWithScore.sort((a, b) => {
        const vipA = getSubscriptionWeight(a);
        const vipB = getSubscriptionWeight(b);
        const distA = a.distanceKm !== null ? a.distanceKm : 9999;
        const distB = b.distanceKm !== null ? b.distanceKm : 9999;

        // If distance is within 0.5km, VIP plan takes priority
        if (Math.abs(distA - distB) <= 0.5 && vipA !== vipB) {
          return vipB - vipA;
        }

        if (distA !== distB) return distA - distB;
        if (vipA !== vipB) return vipB - vipA;
        const rateA = a.googleRating?.rating || a.ratingSummary?.average || 0;
        const rateB = b.googleRating?.rating || b.ratingSummary?.average || 0;
        return rateB - rateA;
      });
    } else if (effectiveSort === 'distance_rating') {
      // Primary: VIP Tier & Distance, Secondary: Google Maps rating (highest first)
      businessesWithScore.sort((a, b) => {
        const vipA = getSubscriptionWeight(a);
        const vipB = getSubscriptionWeight(b);
        const distA = a.distanceKm !== null ? a.distanceKm : 9999;
        const distB = b.distanceKm !== null ? b.distanceKm : 9999;

        // VIP restaurants get expanded proximity priority (within 1.5km range)
        if (vipA !== vipB && Math.abs(distA - distB) <= 1.5) {
          return vipB - vipA;
        }

        // If distance difference is meaningful (> 0.5 km), rank closer first
        if (Math.abs(distA - distB) > 0.5) {
          return distA - distB;
        }

        // VIP priority
        if (vipA !== vipB) return vipB - vipA;

        // Within the same neighborhood, rank higher Google Maps rating first!
        const rateA = a.googleRating?.rating || a.ratingSummary?.average || 0;
        const rateB = b.googleRating?.rating || b.ratingSummary?.average || 0;
        if (rateB !== rateA) return rateB - rateA;

        // Tie-break with review count
        const totalA = a.googleRating?.userRatingsTotal || 0;
        const totalB = b.googleRating?.userRatingsTotal || 0;
        if (totalB !== totalA) return totalB - totalA;

        return distA - distB;
      });
    } else if (effectiveSort === 'google_rating' || effectiveSort === 'rating') {
      // Prioritize authentic Google Maps rating, tie-break with user ratings count & distance
      businessesWithScore.sort((a, b) => {
        const rateA = a.googleRating?.rating || a.ratingSummary?.average || 0;
        const rateB = b.googleRating?.rating || b.ratingSummary?.average || 0;
        if (rateB !== rateA) return rateB - rateA;
        const totalA = a.googleRating?.userRatingsTotal || 0;
        const totalB = b.googleRating?.userRatingsTotal || 0;
        if (totalB !== totalA) return totalB - totalA;
        const distA = a.distanceKm !== null ? a.distanceKm : 9999;
        const distB = b.distanceKm !== null ? b.distanceKm : 9999;
        return distA - distB;
      });
    } else if (effectiveSort === 'price_asc') {
      businessesWithScore.sort((a, b) => (a.priceRange?.min || 0) - (b.priceRange?.min || 0));
    } else if (effectiveSort === 'price_desc') {
      businessesWithScore.sort((a, b) => (b.priceRange?.max || 0) - (a.priceRange?.max || 0));
    } else if (effectiveSort === 'newest') {
      businessesWithScore.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    } else {
      // 'popular' / 'recommended' -> Sort by personalized score (or base popularity)
      businessesWithScore.sort((a, b) => (b.personalizedScore || b.popularityScore) - (a.personalizedScore || a.popularityScore));
    }

    res.json({
      success: true,
      count: businessesWithScore.length,
      isPersonalized: businessesWithScore.some((b) => b.isPersonalized),
      data: businessesWithScore,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get single business by ID or slug
// @route   GET /api/businesses/:id
// @access  Public
export const getBusinessById = async (req, res) => {
  try {
    const isObjectId = req.params.id.match(/^[0-9a-fA-F]{24}$/);
    const query = isObjectId ? { _id: req.params.id } : { slug: req.params.id };

    let business = await Business.findOne(query).populate('ownerId', 'fullName email phone');

    // If not found and queried by slug, try prefix regex match
    if (!business && !isObjectId) {
      const cleanParam = req.params.id.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      business = await Business.findOne({
        slug: new RegExp('^' + cleanParam, 'i'),
      }).populate('ownerId', 'fullName email phone');
    }

    if (!business) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy doanh nghiệp F&B' });
    }

    const branches = await Branch.find({ businessId: business._id, status: 'ACTIVE' });
    const publishedReviews = await Review.find({ businessId: business._id, status: 'PUBLISHED' })
      .populate('userId', 'fullName avatarUrl')
      .sort({ createdAt: -1 });

    const totalRealReviews = publishedReviews.length;
    let averageRealRating = 0;
    if (totalRealReviews > 0) {
      const sum = publishedReviews.reduce((acc, item) => acc + (Number(item.rating) || 5), 0);
      averageRealRating = Math.round((sum / totalRealReviews) * 10) / 10;
    }

    if (
      business.ratingSummary?.totalReviews !== totalRealReviews ||
      business.ratingSummary?.average !== averageRealRating
    ) {
      business.ratingSummary = { average: averageRealRating, totalReviews: totalRealReviews };
      await Business.findByIdAndUpdate(business._id, { ratingSummary: business.ratingSummary });
    }

    res.json({
      success: true,
      data: {
        ...business.toObject(),
        ratingSummary: { average: averageRealRating, totalReviews: totalRealReviews },
        branches,
        recentReviews: publishedReviews.slice(0, 10),
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Create new business
// @route   POST /api/businesses
// @access  Private (Owner/Admin)
export const createBusiness = async (req, res) => {
  try {
    const { name, slug, description, categories, logoUrl, coverImageUrl, priceRange, vibes, purposes, features } = req.body;

    const slugExists = await Business.findOne({ slug });
    if (slugExists) {
      return res.status(400).json({ success: false, message: 'Slug đã tồn tại, vui lòng chọn tên khác' });
    }

    const business = await Business.create({
      ownerId: req.user._id,
      name,
      slug: slug || name.toLowerCase().replace(/ /g, '-').replace(/[^\w-]+/g, ''),
      description,
      categories,
      logoUrl,
      coverImageUrl,
      priceRange,
      vibes: Array.isArray(vibes) ? vibes.map((v) => String(v).trim()).filter(Boolean) : [],
      purposes: Array.isArray(purposes) ? purposes.map((p) => String(p).trim()).filter(Boolean) : [],
      features: Array.isArray(features) ? features.map((f) => String(f).trim()).filter(Boolean) : [],
      status: req.user.role === 'ADMIN' ? 'APPROVED' : 'PENDING',
    });

    res.status(201).json({
      success: true,
      data: business,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update business
// @route   PUT /api/businesses/:id
// @access  Private (Owner/Admin)
export const updateBusiness = async (req, res) => {
  try {
    const business = await Business.findById(req.params.id);

    if (!business) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy doanh nghiệp' });
    }

    if (req.user.role !== 'ADMIN' && business.ownerId.toString() !== req.user._id.toString()) {
      return res.status(403).json({ success: false, message: 'Bạn không có quyền chỉnh sửa doanh nghiệp này' });
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

    if (payload.category && (!payload.categories || payload.categories.length === 0)) {
      const catMap = {
        'Nhà hàng / Quán ăn': 'RESTAURANT',
        'Quán Cà phê / Specialty Coffee': 'CAFE',
        'Quán Cà phê / Cafe': 'CAFE',
        'Quán Trà sữa & Trà trái cây': 'MILK_TEA',
        'Trà sữa & Ăn vặt': 'MILK_TEA',
        'Lẩu & Nướng BBQ': 'BBQ',
        'Tiệm Bánh & Tráng miệng': 'BAKERY',
        'Đồ ăn nhanh / Fast Food': 'FAST_FOOD',
        'Buffet tự chọn': 'BUFFET',
        'Quán Chay thanh tịnh': 'OTHER',
        'Cocktail Bar & Pub': 'BAR',
      };
      payload.categories = [catMap[payload.category] || 'RESTAURANT'];
    }

    const updated = await Business.findByIdAndUpdate(req.params.id, payload, { new: true });

    // If googleMapsUrl was updated, auto-sync coordinates to branches
    if (payload.googleMapsUrl) {
      try {
        const coords = await googleMapsService.getCoordinatesFromGoogleMapsUrl(payload.googleMapsUrl);
        if (coords?.lat && coords?.lng) {
          await Branch.updateMany(
            { businessId: business._id },
            {
              $set: {
                'location.type': 'Point',
                'location.coordinates': [coords.lng, coords.lat],
                googleMapsUrl: payload.googleMapsUrl.trim(),
              },
            }
          );
        }
      } catch (cErr) {
        console.warn('Failed to extract coords on update business:', cErr.message);
      }
    }

    // Phát tín hiệu Realtime qua Socket.IO tới toàn bộ client & trang quán
    emitBusinessUpdate(updated);

    res.json({
      success: true,
      data: updated,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Onboard/Complete business profile (create business & primary branch)
// @route   POST /api/businesses/onboard
// @access  Private (Merchant/Admin)
export const onboardBusiness = async (req, res) => {
  try {
    const {
      name,
      category,
      categories,
      description,
      businessAddress,
      googleMapsUrl,
      logoUrl,
      coverImageUrl,
      vibes,
      purposes,
      features,
    } = req.body;

    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: 'Vui lòng nhập tên quán / thương hiệu F&B' });
    }

    const businessName = name.trim();
    const rawSlug = businessName
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)/g, '');
    const slug = `${rawSlug || 'quan'}-${Date.now().toString().slice(-4)}`;

    const selectedCategory = category || (categories && categories[0]) || 'RESTAURANT';

    // Create Business
    const business = await Business.create({
      ownerId: req.user._id,
      name: businessName,
      slug,
      description: description?.trim() || `Hệ thống quán ẩm thực ${businessName}`,
      categories: [selectedCategory],
      status: 'APPROVED',
      logoUrl: logoUrl || 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: coverImageUrl || 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=800&q=80',
      googleMapsUrl: googleMapsUrl ? googleMapsUrl.trim() : '',
      priceRange: req.body.priceRange
        ? {
            min: Math.max(0, Number(req.body.priceRange.min) || 0),
            max: Math.max(0, Number(req.body.priceRange.max) || 0),
          }
        : { min: 20000, max: 100000 },
      vibes: Array.isArray(vibes) ? vibes.map((v) => String(v).trim()).filter(Boolean) : [],
      purposes: Array.isArray(purposes) ? purposes.map((p) => String(p).trim()).filter(Boolean) : [],
      features: Array.isArray(features) ? features.map((f) => String(f).trim()).filter(Boolean) : [],
    });

    let branchCoords = [108.2208, 16.0678];
    if (googleMapsUrl) {
      try {
        const coords = await googleMapsService.getCoordinatesFromGoogleMapsUrl(googleMapsUrl);
        if (coords?.lat && coords?.lng) {
          branchCoords = [coords.lng, coords.lat];
        }
      } catch (e) {
        console.warn('Failed to extract coords on onboard:', e.message);
      }
    }

    // Create primary Branch
    const branch = await Branch.create({
      businessId: business._id,
      name: `${businessName} - Chi nhánh chính`,
      address: {
        street: businessAddress?.street?.trim() || 'Trụ sở chính',
        ward: businessAddress?.ward?.trim() || '',
        district: businessAddress?.district?.trim() || 'Hải Châu',
        city: businessAddress?.city?.trim() || 'Thành phố Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: branchCoords,
      },
      phone: req.user.phone || '0908888888',
      googleMapsUrl: googleMapsUrl ? googleMapsUrl.trim() : '',
      status: 'ACTIVE',
    });

    // Ensure user role is updated to MERCHANT if needed
    if (req.user.role !== 'MERCHANT' && req.user.role !== 'ADMIN') {
      req.user.role = 'MERCHANT';
      await req.user.save();
    }

    res.status(201).json({
      success: true,
      message: 'Khởi tạo thông tin quán F&B thành công!',
      data: {
        business,
        branch,
      },
    });
  } catch (error) {
    console.error('Onboard business error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Sync Google Reviews and Rating from Google Maps Link
// @route   POST /api/businesses/:id/sync-google-reviews
// @access  Private (Owner/Admin)
export const syncGoogleReviews = async (req, res) => {
  try {
    const business = await Business.findById(req.params.id);

    if (!business) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy doanh nghiệp' });
    }

    if (req.user.role !== 'ADMIN' && business.ownerId.toString() !== req.user._id.toString()) {
      return res.status(403).json({ success: false, message: 'Bạn không có quyền đồng bộ đánh giá cho quán này' });
    }

    const targetUrl = req.body.googleMapsUrl?.trim() || business.googleMapsUrl?.trim();
    if (!targetUrl) {
      return res.status(400).json({
        success: false,
        message: 'Quán chưa có link Google Maps. Vui lòng dán link Google Maps trước khi đồng bộ.',
      });
    }

    // Get primary branch address if available
    const primaryBranch = await Branch.findOne({ businessId: business._id });
    const addressStr = primaryBranch
      ? `${primaryBranch.address?.street || ''}, ${primaryBranch.address?.district || ''}, ${primaryBranch.address?.city || ''}`
      : '';

    const syncResult = await googleMapsService.fetchGooglePlaceReviews({
      googleMapsUrl: targetUrl,
      businessName: business.name,
      address: addressStr,
    });

    if (!syncResult.success) {
      // Clear out any previous reviews on failure - no mock reviews allowed
      business.googleReviews = [];
      business.googleRating = { rating: 0, userRatingsTotal: 0 };
      await business.save();
      emitBusinessUpdate(business);

      return res.status(400).json({
        success: false,
        message: syncResult.message || 'Không thể đồng bộ đánh giá từ Google Maps.',
        data: {
          googleRating: business.googleRating,
          googleReviews: [],
          business,
        },
      });
    }

    // Update business document with real data from Google Places API
    business.googleMapsUrl = targetUrl;
    if (syncResult.placeId) {
      business.googlePlaceId = syncResult.placeId;
    }
    business.googleRating = {
      rating: syncResult.rating || 0,
      userRatingsTotal: syncResult.userRatingsTotal || 0,
    };
    business.googleReviews = syncResult.reviews || [];
    business.googleReviewsLastSyncedAt = new Date();

    await business.save();

    // If primary branch exists, sync googleMapsUrl and accurate coordinates
    if (primaryBranch) {
      primaryBranch.googleMapsUrl = targetUrl;
      try {
        const coords = await googleMapsService.getCoordinatesFromGoogleMapsUrl(targetUrl);
        if (coords?.lat && coords?.lng) {
          primaryBranch.location = {
            type: 'Point',
            coordinates: [coords.lng, coords.lat],
          };
        }
      } catch (cErr) {
        console.warn('Failed to extract coordinates on review sync:', cErr.message);
      }
      await primaryBranch.save();
    }

    // Emit realtime socket event so both merchant and customers get update instantly
    emitBusinessUpdate(business);

    res.json({
      success: true,
      message: syncResult.message || 'Đồng bộ đánh giá Google Maps thành công!',
      source: syncResult.source,
      data: {
        googleRating: business.googleRating,
        googleReviews: business.googleReviews,
        googleReviewsLastSyncedAt: business.googleReviewsLastSyncedAt,
        googleMapsUrl: business.googleMapsUrl,
        business,
      },
    });
  } catch (error) {
    console.error('Sync Google reviews error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};



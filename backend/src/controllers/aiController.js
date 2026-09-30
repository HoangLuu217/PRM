import {
  getAIRecommendations,
  getAIRecommendedDishes,
  getAINearMeRecommendations,
} from '../services/aiService.js';
import { parseMenuWithAI } from '../services/geminiService.js';
import { buildUserTasteProfile } from '../services/recommendationService.js';

// @desc    Get personalized AI recommendations (Businesses)
// @route   GET /api/ai/recommendations
// @access  Public / Private (optional auth)
export const getAIRecommendationsController = async (req, res) => {
  try {
    if (!req.user) {
      return res.json({
        success: true,
        count: 0,
        data: [],
      });
    }

    const filters = {
      city: req.query.city || 'Đà Nẵng',
      vibe: req.query.vibe,
      maxBudget: req.query.maxBudget ? parseInt(req.query.maxBudget) : null,
      category: req.query.category,
    };

    const recommendations = await getAIRecommendations(req.user, filters);

    res.json({
      success: true,
      count: recommendations.length,
      data: recommendations,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get AI Recommended Dishes for Tinder Swiping
// @route   GET /api/ai/recommended-dishes
// @access  Public / Private (optional auth - returns [] if not logged in)
export const getAIRecommendedDishesController = async (req, res) => {
  try {
    if (!req.user) {
      return res.json({
        success: true,
        count: 0,
        data: [],
      });
    }

    const filters = {
      city: req.query.city || 'Đà Nẵng',
      category: req.query.category,
      vibe: req.query.vibe,
      limit: req.query.limit ? parseInt(req.query.limit) : 30,
    };

    const dishes = await getAIRecommendedDishes(req.user, filters);

    res.json({
      success: true,
      count: dishes.length,
      data: dishes,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};


// @desc    Get user's AI-inferred taste profile and learning stats
// @route   GET /api/ai/taste-profile
// @access  Private
export const getUserTasteProfileController = async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Vui lòng đăng nhập' });
    }

    const profile = await buildUserTasteProfile(req.user);
    if (!profile) {
      return res.status(404).json({ success: false, message: 'Không thể tạo hồ sơ gu ẩm thực' });
    }

    const categoryLabels = {
      CAFE: 'Cà phê & Trà',
      MILK_TEA: 'Trà sữa & Ăn vặt',
      RESTAURANT: 'Nhà hàng ẩm thực',
      BBQ: 'Lẩu & Nướng BBQ',
      BAKERY: 'Tiệm bánh ngọt',
      FAST_FOOD: 'Đồ ăn nhanh',
      OTHER: 'Món chay thanh tịnh',
      BUFFET: 'Buffet tự chọn',
      BAR: 'Cocktail Bar & Pub',
      DESSERT: 'Ăn vặt & Tráng miệng',
    };

    const catScores = profile.categoryScores || {};
    const vibeScores = profile.vibeScores || {};
    const maxCatScore = Math.max(...Object.values(catScores), 1);
    const maxVibeScore = Math.max(...Object.values(vibeScores), 1);

    const inferredCategories = (profile.sortedCategories || []).slice(0, 5).map((catId) => {
      const score = catScores[catId] || 0;
      return {
        id: catId,
        label: categoryLabels[catId] || catId,
        score,
        percentage: Math.min(100, Math.max(20, Math.round((score / maxCatScore) * 100))),
      };
    });

    const inferredVibes = (profile.sortedVibes || []).slice(0, 5).map((vibe) => {
      const score = vibeScores[vibe] || 0;
      return {
        name: vibe,
        score,
        percentage: Math.min(100, Math.max(20, Math.round((score / maxVibeScore) * 100))),
      };
    });

    res.json({
      success: true,
      data: {
        totalInteractions: profile.totalInteractions || 0,
        interactionBreakdown: profile.interactionBreakdown || {},
        inferredCategories,
        inferredVibes,
        explicitPreferences: profile.explicitPreferences || {},
        hasInteractions: profile.hasInteractions,
      },
    });
  } catch (error) {
    console.error('Get taste profile error:', error);
    res.status(500).json({ success: false, message: error.message || 'Lỗi lấy hồ sơ AI' });
  }
};

// @desc    Parse raw text menu (Markdown table, CSV, list) using AI
// @route   POST /api/ai/parse-menu
// @access  Public / Merchant
export const parseMenuWithAIController = async (req, res) => {
  try {
    const { rawText, defaultCategory, businessName, businessCategory, apiKey } = req.body;
    if (!rawText || !rawText.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng cung cấp văn bản thực đơn để phân tích',
      });
    }

    const effectiveApiKey = apiKey || req.headers['x-gemini-key'];
    const products = await parseMenuWithAI(rawText, {
      defaultCategory,
      businessName,
      businessCategory,
      apiKey: effectiveApiKey,
    });

    res.json({
      success: true,
      count: products.length,
      data: products,
    });
  } catch (error) {
    console.error('Parse menu with AI error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Lỗi phân tích thực đơn bằng AI',
    });
  }
};

// @desc    Get AI Instant Near-Me Recommendations
// @route   POST /api/ai/near-me, GET /api/ai/near-me
// @access  Public (supports optional user auth)
export const getAINearMeRecommendationsController = async (req, res) => {
  try {
    const params = req.method === 'POST' ? req.body : req.query;
    const {
      latitude,
      longitude,
      city,
      maxDistanceKm,
      mood,
      vibe,
      category,
      query,
      openNowOnly,
      limit,
    } = params;

    const latNum = latitude !== undefined && latitude !== null && latitude !== '' ? parseFloat(latitude) : undefined;
    const lngNum = longitude !== undefined && longitude !== null && longitude !== '' ? parseFloat(longitude) : undefined;

    const result = await getAINearMeRecommendations(req.user || null, {
      latitude: latNum,
      longitude: lngNum,
      city: city || 'Đà Nẵng',
      maxDistanceKm: maxDistanceKm ? parseFloat(maxDistanceKm) : 10,
      mood: mood || '',
      vibe: vibe || '',
      category: category || '',
      query: query || '',
      openNowOnly: openNowOnly === true || openNowOnly === 'true',
      limit: limit ? parseInt(limit) : 20,
    });

    res.json({
      success: true,
      data: result,
    });
  } catch (error) {
    console.error('Near-me recommendation error:', error);
    res.status(500).json({ success: false, message: error.message || 'Lỗi gợi ý quán gần đây' });
  }
};


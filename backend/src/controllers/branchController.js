import { Branch, Business } from '../models/index.js';
import googleMapsService from '../services/googleMapsService.js';

// @desc    Get branches (by business or geo proximity)
// @route   GET /api/branches
// @access  Public
export const getBranches = async (req, res) => {
  try {
    const { businessId, lng, lat, maxDistance = 5000, city } = req.query;
    const query = { status: 'ACTIVE' };

    if (businessId) {
      query.businessId = businessId;
    }

    if (city && city !== 'ALL' && city !== 'Tất cả') {
      const cleanCity = city.replace(/^(Thành phố|Tỉnh|TP\.?)\s+/i, '').trim();
      query.$or = [
        { 'address.city': { $regex: cleanCity, $options: 'i' } },
        { 'address.street': { $regex: cleanCity, $options: 'i' } },
        { 'address.district': { $regex: cleanCity, $options: 'i' } },
      ];
    }

    if (lng && lat) {
      query.location = {
        $near: {
          $geometry: {
            type: 'Point',
            coordinates: [parseFloat(lng), parseFloat(lat)],
          },
          $maxDistance: parseInt(maxDistance),
        },
      };
    }

    const branches = await Branch.find(query).populate(
      'businessId',
      'name slug logoUrl coverImageUrl categories priceRange isBookingEnabled status ratingSummary googleMapsUrl googleRating googleReviews googleReviewsLastSyncedAt googlePlaceId description'
    );

    res.json({
      success: true,
      count: branches.length,
      data: branches,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get single branch by ID
// @route   GET /api/branches/:id
// @access  Public
export const getBranchById = async (req, res) => {
  try {
    const branch = await Branch.findById(req.params.id).populate('businessId');
    if (!branch) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy chi nhánh' });
    }

    res.json({
      success: true,
      data: branch,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Create new branch
// @route   POST /api/branches
// @access  Private (Owner/Admin)
export const createBranch = async (req, res) => {
  try {
    const { businessId, name, address, location, phone, openingHours, amenities, googleMapsUrl } = req.body;

    const business = await Business.findById(businessId);
    if (!business) {
      return res.status(404).json({ success: false, message: 'Nhà hàng không tồn tại' });
    }


    let branchLocation = location;
    if (!branchLocation || !branchLocation.coordinates || (branchLocation.coordinates[0] === 108.218 && branchLocation.coordinates[1] === 16.047)) {
      if (googleMapsUrl) {
        try {
          const coords = await googleMapsService.getCoordinatesFromGoogleMapsUrl(googleMapsUrl);
          if (coords?.lat && coords?.lng) {
            branchLocation = { type: 'Point', coordinates: [coords.lng, coords.lat] };
          }
        } catch (cErr) {
          console.warn('Branch coords parse failed:', cErr.message);
        }
      }
    }

    const branch = await Branch.create({
      businessId,
      name,
      address,
      location: branchLocation || { type: 'Point', coordinates: [108.218, 16.047] },
      phone,
      openingHours,
      amenities,
      googleMapsUrl: googleMapsUrl ? googleMapsUrl.trim() : '',
    });

    res.status(201).json({
      success: true,
      data: branch,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update branch
// @route   PUT /api/branches/:id
// @access  Private (Owner/Admin)
export const updateBranch = async (req, res) => {
  try {
    const payload = { ...req.body };
    if (payload.googleMapsUrl && (!payload.location || !payload.location.coordinates)) {
      try {
        const coords = await googleMapsService.getCoordinatesFromGoogleMapsUrl(payload.googleMapsUrl);
        if (coords?.lat && coords?.lng) {
          payload.location = { type: 'Point', coordinates: [coords.lng, coords.lat] };
        }
      } catch (cErr) {
        console.warn('Branch update coords parse failed:', cErr.message);
      }
    }

    const branch = await Branch.findByIdAndUpdate(req.params.id, payload, { new: true });
    if (!branch) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy chi nhánh' });
    }

    res.json({
      success: true,
      data: branch,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

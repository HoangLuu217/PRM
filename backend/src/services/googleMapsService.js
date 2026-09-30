/**
 * Google Maps & Places Reviews Service powered by SerpApi (https://serpapi.com/)
 * Queries SerpApi's google_maps and google_maps_reviews engines to fetch
 * real ratings, total reviews count, and customer review comments.
 */

/**
 * Expand shortened Google Maps URL (e.g. maps.app.goo.gl/xxx)
 */
export async function expandGoogleMapsUrl(rawUrl) {
  if (!rawUrl || typeof rawUrl !== 'string') return '';
  const trimmed = rawUrl.trim();

  // If already full google maps URL
  if (!trimmed.includes('goo.gl') && !trimmed.includes('maps.app.goo.gl')) {
    return trimmed;
  }

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 6000);

    const response = await fetch(trimmed, {
      method: 'GET',
      redirect: 'follow',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
      signal: controller.signal,
    });
    clearTimeout(timeout);

    return response.url || trimmed;
  } catch (err) {
    console.warn('[SerpApi-GoogleMaps] Error expanding short URL:', err.message);
    return trimmed;
  }
}

/**
 * Extract place identifiers (data_id, cid, query, coordinates) from URL
 */
export function extractPlaceInfoFromUrl(url) {
  if (!url) return { query: '', dataId: '', cid: '', coordinates: null };

  let dataId = '';
  let cid = '';
  let query = '';
  let coordinates = null;

  try {
    // 1. Check data_id hex format !1s(0x...:0x...)
    const dataIdMatch = url.match(/!1s(0x[0-9a-fA-F]+:0x[0-9a-fA-F]+)/);
    if (dataIdMatch && dataIdMatch[1]) {
      dataId = dataIdMatch[1];
    }

    // 2. Check CID ?cid=123456789
    const cidMatch = url.match(/[?&]cid=(\d+)/i);
    if (cidMatch && cidMatch[1]) {
      cid = cidMatch[1];
    }

    // 3. Check /maps/place/Restaurant+Name/@lat,lng
    const placeNameMatch = url.match(/\/maps\/place\/([^/@?]+)/i);
    if (placeNameMatch && placeNameMatch[1]) {
      query = decodeURIComponent(placeNameMatch[1].replace(/\+/g, ' '));
    }

    // 4. Check pinpoint coordinates !3d(lat)!4d(lng) (highest precision pin location on Google Maps)
    const pinCoordMatch = url.match(/!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)/);
    if (pinCoordMatch) {
      coordinates = {
        lat: parseFloat(pinCoordMatch[1]),
        lng: parseFloat(pinCoordMatch[2]),
      };
    } else {
      // Check query param coordinates ?q=16.039,108.237 or ll=
      const qCoordMatch = url.match(/[?&](?:q|ll)=(-?\d+\.\d+),(-?\d+\.\d+)/);
      if (qCoordMatch) {
        coordinates = {
          lat: parseFloat(qCoordMatch[1]),
          lng: parseFloat(qCoordMatch[2]),
        };
      } else {
        // Fallback to viewport center @16.0544,108.2022
        const coordMatch = url.match(/@(-?\d+\.\d+),(-?\d+\.\d+)/);
        if (coordMatch) {
          coordinates = {
            lat: parseFloat(coordMatch[1]),
            lng: parseFloat(coordMatch[2]),
          };
        }
      }
    }

    // 5. Check search query ?q= or ?query=
    if (!query) {
      const searchMatch = url.match(/[?&](?:q|query)=([^&]+)/i);
      if (searchMatch && searchMatch[1]) {
        query = decodeURIComponent(searchMatch[1].replace(/\+/g, ' '));
      }
    }
  } catch (err) {
    console.warn('[SerpApi-GoogleMaps] Failed to parse URL:', err.message);
  }

  return { query, dataId, cid, coordinates };
}

/**
 * Resolve short Google Maps URL and extract coordinates
 */
export async function getCoordinatesFromGoogleMapsUrl(rawUrl) {
  if (!rawUrl || typeof rawUrl !== 'string') return null;
  try {
    const expanded = await expandGoogleMapsUrl(rawUrl);
    const info = extractPlaceInfoFromUrl(expanded);
    if (info?.coordinates?.lat && info?.coordinates?.lng) {
      return {
        lat: info.coordinates.lat,
        lng: info.coordinates.lng,
        expandedUrl: expanded,
      };
    }
  } catch (err) {
    console.warn('[getCoordinatesFromGoogleMapsUrl] Error:', err.message);
  }
  return null;
}

function extractReviewImages(r) {
  if (!r) return [];
  const rawList = r.images || r.photos || [];
  if (!Array.isArray(rawList)) return [];
  return rawList
    .map((item) => {
      if (typeof item === 'string') return item;
      if (item && typeof item === 'object') {
        return item.image || item.thumbnail || item.url || item.photo || '';
      }
      return '';
    })
    .filter(Boolean);
}

/**
 * Fetch Reviews and Rating using SerpApi
 */
export async function fetchGooglePlaceReviews({ googleMapsUrl, businessName, address }) {
  const apiKey = (process.env.SERPAPI_KEY || process.env.GOOGLE_MAPS_API_KEY || '').trim();

  if (!apiKey) {
    return {
      success: false,
      message: 'Chưa cấu hình SERPAPI_KEY trong file backend/.env. Vui lòng đăng ký tài khoản miễn phí tại https://serpapi.com/ và dán API Key vào .env.',
      rating: 0,
      userRatingsTotal: 0,
      reviews: [],
    };
  }

  // 1. Expand short URL if needed
  const expandedUrl = await expandGoogleMapsUrl(googleMapsUrl);
  const { query, dataId, cid, coordinates } = extractPlaceInfoFromUrl(expandedUrl);

  const searchQuery = query || [businessName, address].filter(Boolean).join(' ');

  console.log('📍 [SerpApi-GoogleMaps] Resolving reviews with SerpApi:', {
    rawUrl: googleMapsUrl,
    expandedUrl,
    extractedDataId: dataId,
    extractedCid: cid,
    searchQuery,
  });

  try {
    // APPROACH 1: If URL has data_id or cid, directly query google_maps_reviews engine (fastest & most accurate)
    if (dataId || cid) {
      const reviewsParams = new URLSearchParams({
        engine: 'google_maps_reviews',
        hl: 'vi',
        gl: 'vn',
        api_key: apiKey,
      });

      if (dataId) reviewsParams.append('data_id', dataId);
      else if (cid) reviewsParams.append('data_cid', cid);

      console.log('🔍 [SerpApi-GoogleMaps] Querying google_maps_reviews engine directly...');
      const revRes = await fetch(`https://serpapi.com/search.json?${reviewsParams.toString()}`);
      const revData = await revRes.json();

      if (revData.error) {
        console.warn('[SerpApi-GoogleMaps] Reviews query returned error:', revData.error);
        // Fallback to text search if data_id didn't work
      } else {
        const placeInfo = revData.place_info || {};
        const rawReviews = revData.reviews || [];

        const reviews = rawReviews.map((r) => ({
          authorName: r.user?.name || 'Khách hàng Google',
          authorPhotoUrl: r.user?.thumbnail || '',
          rating: Number(r.rating) || 5,
          text: r.snippet || r.extracted_snippet?.original || '',
          relativeTime: r.date || 'Gần đây',
          time: Date.now(),
          images: extractReviewImages(r),
        }));

        const rating = Number(placeInfo.rating) || (reviews.length > 0 ? reviews[0].rating : 0);
        const userRatingsTotal = Number(placeInfo.reviews) || reviews.length;

        return {
          success: true,
          placeId: dataId || cid,
          placeName: placeInfo.title || businessName,
          rating,
          userRatingsTotal,
          reviews,
          expandedUrl: expandedUrl || googleMapsUrl,
          source: 'SERPAPI_GOOGLE_MAPS',
          message: `Đồng bộ thành công ${reviews.length} đánh giá từ SerpApi (Google Maps)!`,
        };
      }
    }

    // APPROACH 2: Search by query with google_maps engine
    const searchParams = new URLSearchParams({
      engine: 'google_maps',
      q: searchQuery,
      hl: 'vi',
      gl: 'vn',
      api_key: apiKey,
    });

    if (coordinates) {
      searchParams.append('ll', `@${coordinates.lat},${coordinates.lng},16z`);
    }

    console.log('🔍 [SerpApi-GoogleMaps] Searching place via google_maps engine with query:', searchQuery);
    const searchRes = await fetch(`https://serpapi.com/search.json?${searchParams.toString()}`);
    const searchData = await searchRes.json();

    if (searchData.error) {
      console.warn('[SerpApi-GoogleMaps] Search error:', searchData.error);
      return {
        success: false,
        message: searchData.error || 'SerpApi không tìm thấy địa điểm quán ăn theo link hoặc tên này.',
        rating: 0,
        userRatingsTotal: 0,
        reviews: [],
      };
    }

    // Get place from place_results or local_results
    const place = searchData.place_results || (searchData.local_results && searchData.local_results[0]);
    if (!place) {
      return {
        success: false,
        message: 'Không tìm thấy kết quả quán ăn nào trên Google Maps theo tìm kiếm này.',
        rating: 0,
        userRatingsTotal: 0,
        reviews: [],
      };
    }

    const rating = Number(place.rating) || 0;
    const userRatingsTotal = Number(place.reviews) || 0;
    const placeDataId = place.data_id;

    let reviews = [];

    // If place has data_id, query google_maps_reviews to get the full reviews list
    if (placeDataId) {
      try {
        const reviewsParams = new URLSearchParams({
          engine: 'google_maps_reviews',
          data_id: placeDataId,
          hl: 'vi',
          gl: 'vn',
          api_key: apiKey,
        });

        const revRes = await fetch(`https://serpapi.com/search.json?${reviewsParams.toString()}`);
        const revData = await revRes.json();

        if (revData.reviews && Array.isArray(revData.reviews)) {
          reviews = revData.reviews.map((r) => ({
            authorName: r.user?.name || 'Khách hàng Google',
            authorPhotoUrl: r.user?.thumbnail || '',
            rating: Number(r.rating) || 5,
            text: r.snippet || r.extracted_snippet?.original || '',
            relativeTime: r.date || 'Gần đây',
            time: Date.now(),
            images: extractReviewImages(r),
          }));
        }
      } catch (err) {
        console.warn('[SerpApi-GoogleMaps] Error fetching detailed reviews:', err.message);
      }
    }

    // If reviews still empty, check if place_results had user_reviews
    if (reviews.length === 0 && place.user_reviews?.most_relevant) {
      reviews = place.user_reviews.most_relevant.map((r) => ({
        authorName: r.username || 'Khách hàng Google',
        authorPhotoUrl: r.user_image || '',
        rating: Number(r.rating) || 5,
        text: r.description || '',
        relativeTime: r.date || 'Gần đây',
        time: Date.now(),
        images: extractReviewImages(r),
      }));
    }

    return {
      success: true,
      placeId: placeDataId || place.place_id || '',
      placeName: place.title || businessName,
      rating,
      userRatingsTotal: userRatingsTotal || reviews.length,
      reviews,
      expandedUrl: expandedUrl || googleMapsUrl,
      source: 'SERPAPI_GOOGLE_MAPS',
      message: `Đồng bộ thành công ${reviews.length} đánh giá từ SerpApi (Google Maps)!`,
    };
  } catch (apiErr) {
    console.error('[SerpApi-GoogleMaps] Network error:', apiErr);
    return {
      success: false,
      message: `Lỗi kết nối tới SerpApi: ${apiErr.message}`,
      rating: 0,
      userRatingsTotal: 0,
      reviews: [],
    };
  }
}

export default {
  expandGoogleMapsUrl,
  extractPlaceInfoFromUrl,
  getCoordinatesFromGoogleMapsUrl,
  fetchGooglePlaceReviews,
};


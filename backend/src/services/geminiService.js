import dotenv from 'dotenv';
dotenv.config();

/**
 * Generate AI Sommelier Insight for Near-Me Recommendations
 * Calls Google Gemini REST API (gemini-1.5-flash) to provide natural, expert culinary insights
 * on top discovered restaurants in real time.
 */
export const generateAINearMeSommelierInsight = async ({
  city = 'Đà Nẵng',
  vibe = '',
  query = '',
  radius = 5,
  timeOfDay = 'Trưa',
  topPlaces = [],
}) => {
  if (!topPlaces || topPlaces.length === 0) {
    return 'Hiện tại chưa tìm thấy quán ăn phù hợp với tiêu chí tìm kiếm. Hãy thử mở rộng bán kính hoặc chọn phong cách khác.';
  }

  const apiKey = process.env.GEMINI_API_KEY || process.env.GOOGLE_AI_KEY;

  if (apiKey) {
    try {
      const topPlacesSummary = topPlaces
        .slice(0, 3)
        .map((p, idx) => {
          const distStr = p.distanceMeters <= 1000 ? `${p.distanceMeters}m (${p.walkingMinutes}p đi bộ)` : `${p.distanceKm}km (${p.drivingMinutes}p xe máy)`;
          const dishNames = (p.signatureDishes || []).map((d) => d.name).join(', ');
          return `${idx + 1}. "${p.name}" (Đánh giá ${p.rating}⭐, Cách bạn ${distStr}, ${p.isOpenNow ? 'Đang mở cửa' : 'Đóng cửa'}${dishNames ? `, Món ngon: ${dishNames}` : ''})`;
        })
        .join('\n');

      const prompt = `Bạn là Trợ Lý Ẩm Thực Thông Minh FConnect (AI Sommelier & Food Critic) tại Việt Nam.
Người dùng đang tìm quán ăn gần vị trí hiện tại:
- Thời điểm hiện tại: Buổi ${timeOfDay}
- Bán kính tìm kiếm: ${radius}km ${vibe ? `• Phong cách: "${vibe}"` : ''} ${query ? `• Món thèm: "${query}"` : ''}
- Danh sách top quán ăn thực tế vừa tìm thấy gần nhất:
${topPlacesSummary}

Yêu cầu: Hãy viết 1 nhận xét / lời khuyên chuyên gia thật tự nhiên, súc tích (khoảng 2-3 câu, dưới 45 từ), tư vấn tại sao người dùng nên ghé quán nổi bật nhất lúc này và gợi ý nhanh món nên thử.
Quy tắc: Không dùng dấu markdown hoa mỹ hay bullet point, chỉ trả lời 1 đoạn văn ngắn gọn, thân thiện và hào hứng.`;

      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 3500);

      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: {
              temperature: 0.7,
              maxOutputTokens: 120,
            },
          }),
          signal: controller.signal,
        }
      );

      clearTimeout(timeoutId);

      if (response.ok) {
        const data = await response.json();
        const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
        if (text && text.trim()) {
          return text.trim();
        }
      }
    } catch (err) {
      console.warn('Gemini Sommelier API notice (using fallback):', err.message);
    }
  }

  // Smart Context-Aware Fallback
  const top = topPlaces[0];
  const distText = top.distanceMeters <= 1000 ? `chỉ cách bạn ${top.distanceMeters}m (${top.walkingMinutes} phút đi bộ)` : `cách bạn ${top.distanceKm}km`;
  const signature = top.signatureDishes?.[0]?.name ? `với món đặc sắc "${top.signatureDishes[0].name}"` : 'với thực đơn đa dạng phong phú';
  return `Vào buổi ${timeOfDay.toLowerCase()}, "${top.name}" (${top.rating}⭐) là gợi ý số 1 ${distText}, ${top.isOpenNow ? 'đang mở cửa đón khách' : 'chuẩn bị phục vụ'} ${signature}.`;
};

/**
 * Generate AI Food Critic Summary & Personalized Itinerary Advice
 */
export const generateAIFoodCriticSummary = async ({
  city,
  durationDays,
  budgetVND,
  partySize,
  vibeTag,
  stopsCount,
}) => {
  const apiKey = process.env.GEMINI_API_KEY || process.env.GOOGLE_AI_KEY;

  if (apiKey) {
    try {
      const prompt = `Bạn là một Chuyên Gia Ẩm Thực (AI Food Critic) tại Việt Nam.
Hãy viết một câu nhận xét ngắn gọn (tối đa 1-2 câu, dưới 30 từ), súc tích và hấp dẫn cho lịch trình ẩm thực tại ${city} theo phong cách "${vibeTag}" (${durationDays} ngày, ${stopsCount} điểm dừng).
Không dùng markdown, trả về văn bản thuần túy ngắn gọn.`;

      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
          }),
        }
      );

      if (response.ok) {
        const data = await response.json();
        const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
        if (text && text.trim()) {
          return text.trim();
        }
      }
    } catch (err) {
      console.warn('Gemini API call notice:', err.message);
    }
  }

  // Smart Concise Synthesis Fallback
  return `Lịch trình ${durationDays} ngày tại ${city} chuẩn phong cách "${vibeTag}" với ${stopsCount} điểm ẩm thực được AI tối ưu lộ trình.`;
};

/**
 * Curated high-res food & drink images based on Vietnamese menu keywords
 */
export const getCuratedDishImage = (dishName = '', category = '') => {
  const text = `${dishName} ${category}`.toLowerCase();

  if (text.includes('đen') || text.includes('espresso') || text.includes('americano') || text.includes('phin đen')) {
    return 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=600&q=80';
  }
  if (text.includes('sữa sg') || text.includes('sữa đá') || text.includes('nâu') || text.includes('latte') || text.includes('cappuccino')) {
    return 'https://images.unsplash.com/photo-1541167760496-1628856ab772?auto=format&fit=crop&w=600&q=80';
  }
  if (text.includes('bạc sỉu') || text.includes('bac siu')) {
    return 'https://images.unsplash.com/photo-1572442388796-11668a67e53d?auto=format&fit=crop&w=600&q=80';
  }
  if (text.includes('muối') || text.includes('trứng') || text.includes('macchiato') || text.includes('kem béo') || text.includes('kem cheese')) {
    return 'https://images.unsplash.com/photo-1517701550927-30cf4ba1dba5?auto=format&fit=crop&w=600&q=80';
  }
  if (text.includes('dừa') || text.includes('cốt dừa')) {
    return 'https://images.unsplash.com/photo-1559496417-e7f25cb247f3?auto=format&fit=crop&w=600&q=80';
  }
  if (text.includes('sầu riêng')) {
    return 'https://images.unsplash.com/photo-1497636577773-f1231844b336?auto=format&fit=crop&w=600&q=80';
  }
  if (text.includes('cacao') || text.includes('socola') || text.includes('chocolate')) {
    return 'https://images.unsplash.com/photo-1542990253-0d0f5be5f0ed?auto=format&fit=crop&w=600&q=80';
  }
  if (text.includes('trà sữa') || text.includes('boba') || text.includes('matcha') || text.includes('trân châu')) {
    return 'https://images.unsplash.com/photo-1558857563-b37cf5bc5bb4?auto=format&fit=crop&w=600&q=80';
  }
  if (text.includes('trà') || text.includes('tea') || text.includes('nước ép') || text.includes('sinh tố')) {
    return 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?auto=format&fit=crop&w=600&q=80';
  }
  if (text.includes('bánh') || text.includes('croissant') || text.includes('cake') || text.includes('tiramisu')) {
    return 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=600&q=80';
  }
  if (text.includes('pizza') || text.includes('pasta') || text.includes('mì ý')) {
    return 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=600&q=80';
  }
  if (text.includes('mì') || text.includes('phở') || text.includes('bún') || text.includes('hủ tiếu')) {
    return 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=600&q=80';
  }
  if (text.includes('cơm') || text.includes('gà')) {
    return 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=600&q=80';
  }
  if (text.includes('hải sản') || text.includes('tôm') || text.includes('cua') || text.includes('mực') || text.includes('ốc')) {
    return 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=600&q=80';
  }
  if (text.includes('lẩu') || text.includes('nướng') || text.includes('bbq') || text.includes('bò')) {
    return 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=600&q=80';
  }
  if (text.includes('ăn vặt') || text.includes('chiên') || text.includes('khoai tây')) {
    return 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=600&q=80';
  }

  return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=600&q=80';
};

/**
 * Normalize price strings like "30", "35k", "40.000", "45,000" into numbers (VND)
 */
export const normalizeMenuPrice = (raw) => {
  if (raw === null || raw === undefined) return 30000;
  let str = String(raw).trim().toLowerCase().replace(/[đvnd,\s]/g, '');

  if (str.endsWith('k')) {
    const num = parseFloat(str.replace('k', ''));
    return !isNaN(num) ? Math.round(num * 1000) : 30000;
  }
  if (/^\d{1,3}\.\d{3}$/.test(str)) {
    str = str.replace('.', '');
  }

  const num = parseFloat(str);
  if (isNaN(num)) return 30000;
  if (num > 0 && num < 1000) {
    return Math.round(num * 1000);
  }
  return Math.round(num);
};

/**
 * Try parsing JSON directly (supports arrays, objects with menu/dishes/items/data keys, markdown ```json code blocks, Vietnamese property names)
 */
export const tryParseJSONMenu = (text = '', defaultCategory = 'Đồ Uống') => {
  if (!text || !text.trim()) return null;
  let cleaned = text.trim();
  cleaned = cleaned.replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/i, '').trim();

  const firstBrace = cleaned.indexOf('{');
  const firstBracket = cleaned.indexOf('[');
  if (firstBrace === -1 && firstBracket === -1) return null;

  const startIdx = firstBracket !== -1 && (firstBrace === -1 || firstBracket < firstBrace) ? firstBracket : firstBrace;
  const lastBracket = cleaned.lastIndexOf(']');
  const lastBrace = cleaned.lastIndexOf('}');
  const endIdx = Math.max(lastBracket, lastBrace);
  if (endIdx <= startIdx) return null;

  const jsonSub = cleaned.slice(startIdx, endIdx + 1);
  try {
    const parsed = JSON.parse(jsonSub);
    let arr = Array.isArray(parsed) ? parsed : null;
    if (!arr && typeof parsed === 'object' && parsed !== null) {
      for (const k of ['menu', 'dishes', 'items', 'products', 'thuc_don', 'mon_an', 'data', 'list', 'foods']) {
        if (Array.isArray(parsed[k])) {
          arr = parsed[k];
          break;
        }
      }
      if (!arr) {
        for (const v of Object.values(parsed)) {
          if (Array.isArray(v) && v.length > 0 && typeof v[0] === 'object') {
            arr = v;
            break;
          }
        }
      }
    }

    if (arr && arr.length > 0) {
      const results = arr
        .map((item, idx) => {
          if (!item) return null;
          if (typeof item === 'string') {
            return {
              name: item.trim(),
              price: 30000,
              category: inferCategoryFromName(item, defaultCategory),
              description: 'Món ngon tươi mới',
              isSignature: item.includes('⭐'),
              imageUrl: '',
              isAvailable: true,
            };
          }
          const rawName = String(
            item.name || item.ten || item.ten_mon || item.mon || item.title || item.item || item.dish || item.label || ''
          ).trim();
          if (!rawName) return null;

          const isSignature = Boolean(
            item.isSignature || item.signature || item.hot || item.bestSeller || rawName.includes('⭐')
          );
          const cleanName = rawName.replace(/⭐/g, '').replace(/[\*\#]/g, '').trim();
          const category =
            item.category || item.danh_muc || item.loai || inferCategoryFromName(cleanName, defaultCategory);

          return {
            name: cleanName || `Món ăn ${idx + 1}`,
            price: normalizeMenuPrice(item.price ?? item.gia ?? item.gia_ban ?? item.don_gia ?? item.cost ?? item.amount),
            category,
            description:
              item.description ||
              item.mo_ta ||
              (isSignature
                ? 'Món ngon đặc sắc (Best-seller ⭐) chuẩn vị được thực khách yêu thích nhất.'
                : 'Hương vị thơm ngon, chế biến tươi mới mỗi ngày phục vụ thực khách.'),
            isSignature,
            imageUrl: '',
            isAvailable: true,
          };
        })
        .filter((x) => x && x.name);

      if (results.length > 0) return results;
    }
  } catch (err) {
    // Not valid JSON or parse failed
  }
  return null;
};

/**
 * Intelligent Universal Parser for:
 * 1. JSON (arrays, objects, code blocks)
 * 2. Markdown tables (| STT | Tên | Giá |)
 * 3. Excel / TSV copy-paste (tab separated)
 * 4. CSV & Semicolon lists
 * 5. Free-form text lists with numbers, dashes, colons, or trailing prices
 */
export const fallbackParseMenu = (rawText, defaultCategory = 'Đồ Uống') => {
  if (!rawText || !rawText.trim()) return [];

  // 1. Thử bóc tách JSON trước
  const jsonParsed = tryParseJSONMenu(rawText, defaultCategory);
  if (jsonParsed && jsonParsed.length > 0) {
    return jsonParsed;
  }

  // 2. Bóc tách dạng dòng văn bản (Markdown table, TSV Excel, Text list)
  const lines = rawText.split('\n').map((l) => l.trim()).filter(Boolean);
  const items = [];

  for (const line of lines) {
    // Bỏ qua dòng phân cách bảng markdown
    if (/^[|\-\s:+]+$/.test(line) || line.includes('---') || line.includes('--:') || line.includes(':--')) continue;

    const lower = line.toLowerCase();
    // Bỏ qua dòng tiêu đề bảng
    if (
      (lower.includes('stt') || lower.includes('#') || lower.includes('no.')) &&
      (lower.includes('món') || lower.includes('tên') || lower.includes('đồ uống') || lower.includes('item') || lower.includes('name')) &&
      (lower.includes('giá') || lower.includes('price') || lower.includes('cost'))
    ) {
      continue;
    }

    // 2.1. Markdown Table format: | STT | Tên Món | Giá |
    if (line.includes('|')) {
      const parts = line
        .split('|')
        .map((p) => p.trim())
        .filter((p) => p.length > 0);

      if (parts.length >= 2) {
        let name = '';
        let priceRaw = '';

        if (parts.length === 2) {
          name = parts[0];
          priceRaw = parts[1];
        } else {
          // If first column is numeric (index/STT)
          if (/^\d+$/.test(parts[0])) {
            name = parts[1];
            priceRaw = parts[2];
          } else {
            name = parts[0];
            priceRaw = parts[1];
          }
        }

        if (name && priceRaw) {
          const isSignature = name.includes('⭐') || name.toLowerCase().includes('hot') || name.toLowerCase().includes('món tủ');
          const cleanName = name.replace(/⭐/g, '').replace(/[\*\#]/g, '').trim();
          const price = normalizeMenuPrice(priceRaw);
          const category = inferCategoryFromName(cleanName, defaultCategory);
          const description = isSignature
            ? `Món ngon đặc sắc (Best-seller ⭐) chuẩn vị được thực khách yêu thích nhất.`
            : `Hương vị thơm ngon, chế biến tươi mới mỗi ngày phục vụ thực khách.`;

          items.push({
            name: cleanName,
            price,
            category,
            description,
            isSignature,
            imageUrl: '',
            isAvailable: true,
          });
          continue;
        }
      }
    }

    // 2.2. Tab (Excel copy-paste) or Semicolon separated
    const splitTokens = line.includes('\t')
      ? line.split('\t')
      : line.includes(';')
      ? line.split(';')
      : null;

    if (splitTokens && splitTokens.length >= 2) {
      const parts = splitTokens.map((t) => t.trim()).filter(Boolean);
      let name = parts[0].replace(/^\d+[\.\)\-\/]\s*/, '');
      let priceRaw = parts[parts.length - 1];

      if (/^\d+$/.test(parts[0]) && parts.length >= 3) {
        name = parts[1];
        priceRaw = parts[2];
      }

      if (name && priceRaw) {
        const isSignature = name.includes('⭐') || name.toLowerCase().includes('hot');
        const cleanName = name.replace(/⭐/g, '').trim();
        const price = normalizeMenuPrice(priceRaw);
        const category = inferCategoryFromName(cleanName, defaultCategory);

        items.push({
          name: cleanName,
          price,
          category,
          description: isSignature ? 'Món đặc sắc ⭐ chuẩn vị được ưa chuộng' : 'Món ngon tươi mới',
          isSignature,
          imageUrl: '',
          isAvailable: true,
        });
        continue;
      }
    }

    // 2.3. Regex pattern: "1. Cà phê đen SG - 30k" or "Bạc sỉu: 40" or "- Cà phê muối: 45.000đ"
    const cleanedLine = line.replace(/^[\*\-•\d\.\)\/\s]+/, '').trim();
    const matchSeparator = cleanedLine.match(/^([^:\-–—\t]+?)\s*[:\-–—\t]\s*([0-9kK\.,\sđ]+(?:\s*VNĐ|\s*đồng)?)$/i);
    if (matchSeparator) {
      const rawName = matchSeparator[1].trim();
      const rawPrice = matchSeparator[2].trim();
      const isSignature = rawName.includes('⭐') || rawName.toLowerCase().includes('hot');
      const cleanName = rawName.replace(/⭐/g, '').trim();
      const price = normalizeMenuPrice(rawPrice);
      const category = inferCategoryFromName(cleanName, defaultCategory);

      items.push({
        name: cleanName,
        price,
        category,
        description: isSignature ? 'Món đặc sắc ⭐ thơm ngon chuẩn vị' : 'Món ngon phục vụ trong ngày',
        isSignature,
        imageUrl: '',
        isAvailable: true,
      });
      continue;
    }

    // 2.4. Trailing price without separator: "Cà phê đen SG 30k" or "Bạc sỉu 40000"
    const matchTrailingPrice = cleanedLine.match(/^(.+?)\s+([0-9]{1,3}(?:[\.,][0-9]{3})*k?|[0-9]{1,3}k)\s*(?:đ|vnd|đồng)?$/i);
    if (matchTrailingPrice) {
      const rawName = matchTrailingPrice[1].trim();
      const rawPrice = matchTrailingPrice[2].trim();
      const isSignature = rawName.includes('⭐') || rawName.toLowerCase().includes('hot');
      const cleanName = rawName.replace(/⭐/g, '').trim();
      const price = normalizeMenuPrice(rawPrice);
      const category = inferCategoryFromName(cleanName, defaultCategory);

      items.push({
        name: cleanName,
        price,
        category,
        description: isSignature ? 'Món đặc sắc ⭐ chuẩn vị' : 'Món ngon tươi mới trong ngày',
        isSignature,
        imageUrl: '',
        isAvailable: true,
      });
      continue;
    }
  }

  return items;
};

const inferCategoryFromName = (name = '', fallbackCategory = 'Đồ Uống') => {
  const n = (name || '').toLowerCase();
  if (n.includes('cà phê') || n.includes('cafe') || n.includes('bạc sỉu') || n.includes('phin') || n.includes('espresso') || n.includes('americano') || n.includes('latte')) {
    return 'Đồ Uống';
  }
  if (n.includes('trà sữa') || n.includes('matcha') || n.includes('ô long') || n.includes('boba')) {
    return 'Trà Sữa';
  }
  if (n.includes('trà') || n.includes('nước ép') || n.includes('sinh tố') || n.includes('soda') || n.includes('cacao') || n.includes('chè')) {
    return 'Đồ Uống';
  }
  if (n.includes('bánh') || n.includes('croissant') || n.includes('mousse') || n.includes('tiramisu') || n.includes('kem') || n.includes('flan')) {
    return 'Tráng Miệng';
  }
  if (n.includes('cơm') || n.includes('mì') || n.includes('bún') || n.includes('phở') || n.includes('hủ tiếu') || n.includes('lẩu') || n.includes('nướng') || n.includes('pizza') || n.includes('bò') || n.includes('gà') || n.includes('heo')) {
    return 'Món Chính';
  }
  if (n.includes('khoai tây') || n.includes('nem') || n.includes('chả') || n.includes('gỏi') || n.includes('snack') || n.includes('salad')) {
    return 'Khai Vị';
  }
  return fallbackCategory || 'Đồ Uống';
};

/**
 * Parse any raw menu text with Gemini AI (or resilient multi-format fallback)
 */
export const parseMenuWithAI = async (rawText, options = {}) => {
  const { defaultCategory = 'Đồ Uống', businessName = '', businessCategory = '', apiKey: customApiKey } = options;
  const apiKey = customApiKey || process.env.GEMINI_API_KEY || process.env.GOOGLE_AI_KEY;

  if (apiKey && rawText && rawText.trim().length > 6) {
    const candidateModels = ['gemini-2.5-flash', 'gemini-2.5-flash-lite-preview-06-17'];

    for (const modelName of candidateModels) {
      try {
        const prompt = `Bạn là một Chuyên Gia Chuyển Đổi Dữ Liệu Ẩm Thực (AI Menu Parser).
Hãy phân tích nội dung thực đơn sau đây của quán "${businessName || 'Nhà hàng / Quán nước'}" (loại hình: ${businessCategory || 'Ẩm thực'}):
---
${rawText.trim()}
---
YÊU CẦU:
1. Trích xuất tất cả các món ăn / đồ uống thành danh sách JSON chuẩn. Xử lý được mọi định dạng: JSON, bảng Markdown, bảng Excel, danh sách tự do.
2. Với mỗi món, trả về object gồm các trường:
   - "name": Tên món ngắn gọn, chuẩn tiếng Việt, bỏ số thứ tự ở đầu.
   - "price": Giá bán là số nguyên (VNĐ). LƯU Ý: Nếu ghi 30, 35, 40, 45 thì đó là đơn vị nghìn đồng (30000, 35000, 40000, 45000). Nếu ghi 30k -> 30000. Nếu ghi 35000 -> 35000. Nếu món có nhiều kích cỡ, dùng trường "sizes" thay thế và đặt "price" = 0.
   - "sizes": Mảng các kích cỡ NẾU món có size S/M/L hoặc Nhỏ/Vừa/Lớn. Mỗi phần tử gồm: {"name": "S", "price": 25000, "isDefault": false}. Size Vừa/M thường là mặc định (isDefault: true). Nếu không có sizes, trả về mảng rỗng [].
   - "category": Phân loại danh mục phù hợp (chọn 1 trong các giá trị: "Đồ Uống", "Trà Sữa", "Món Chính", "Khai Vị", "Tráng Miệng", "Combo Tiết Kiệm").
   - "description": 1 câu mô tả ngắn gọn, kích thích vị giác (dưới 20 từ). Nếu món có dấu sao ⭐ hoặc đặc sắc, ghi rõ là món đặc sắc bán chạy nhất của quán.
   - "isSignature": true nếu món có ký hiệu ⭐ hoặc ghi chú đặc biệt/món tủ, false nếu bình thường.
3. CHỈ TRẢ VỀ DUY NHẤT MỘT MẢNG JSON HỢP LỆ (Bắt đầu bằng [ và kết thúc bằng ]). Không viết bất kỳ lời giải thích nào, không bao bọc bởi markdown backticks.`;

        const response = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${apiKey}`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              contents: [{ parts: [{ text: prompt }] }],
              generationConfig: {
                temperature: 0.1,
              },
            }),
          }
        );

        if (response.ok) {
          const data = await response.json();
          let text = data.candidates?.[0]?.content?.parts?.[0]?.text;
          if (text) {
            text = text.trim();
            if (text.startsWith('```json')) {
              text = text.replace(/^```json/, '').replace(/```$/, '').trim();
            } else if (text.startsWith('```')) {
              text = text.replace(/^```/, '').replace(/```$/, '').trim();
            }

            const parsed = JSON.parse(text);
            if (Array.isArray(parsed) && parsed.length > 0) {
              return parsed.map((item) => {
                const cleanName = (item.name || '').trim();
                const category = item.category || inferCategoryFromName(cleanName, defaultCategory);
                const hasSizes = Array.isArray(item.sizes) && item.sizes.length > 0;
                const sizes = hasSizes
                  ? item.sizes.map((sz, si) => ({
                      name: sz.name || `Size ${si + 1}`,
                      price: normalizeMenuPrice(sz.price),
                      isDefault: Boolean(sz.isDefault),
                    }))
                  : [];
                const price = hasSizes
                  ? (sizes.find((s) => s.isDefault)?.price || sizes[0]?.price || 0)
                  : normalizeMenuPrice(item.price);
                return {
                  name: cleanName,
                  price,
                  sizes,
                  category,
                  description: item.description || (item.isSignature ? 'Món đặc sắc ⭐ được yêu thích' : 'Món ngon chế biến tươi mới'),
                  isSignature: Boolean(item.isSignature),
                  imageUrl: '',
                  isAvailable: true,
                };
              });
            }
          }
        } else {
          const errData = await response.json().catch(() => ({}));
          console.warn(`⚠️ Gemini API model ${modelName} returned status ${response.status}:`, errData?.error?.message || response.statusText);
          if (response.status === 403) {
            // Leaked key or permission denied - break model loop to immediately use smart parser
            break;
          }
        }
      } catch (err) {
        console.warn(`⚠️ Gemini AI model ${modelName} parsing error:`, err.message);
      }
    }
  }

  // Universal smart parser (JSON, Markdown tables, TSV Excel, CSV, Text lists)
  return fallbackParseMenu(rawText, defaultCategory);
};

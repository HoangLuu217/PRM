import mongoose from 'mongoose';
import dotenv from 'dotenv';
import bcrypt from 'bcryptjs';
import dns from 'dns';
import {
  User,
  Business,
  Branch,
  Menu,
  Product,
} from '../models/index.js';

dotenv.config();

// Fix Node.js DNS SRV resolution issue on Windows for MongoDB Atlas
try {
  dns.setServers(['8.8.8.8', '1.1.1.1']);
} catch (e) {
  // ignore
}

export const danangRestaurantsData = [
  {
    merchant: {
      fullName: 'Võ Văn Mặn (Chủ Quán Bé Mặn)',
      email: 'owner.beman@fconnect.vn',
      password: 'merchant123',
      phone: '0905207848',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Hải Sản Bé Mặn (Mỹ Khê)',
      slug: 'hai-san-be-man-my-khe',
      description: 'Hải sản tươi sống bắt tại bể uy tín bậc nhất bờ biển Mỹ Khê Đà Nẵng. Không gian rộng rãi, thoáng đãng đón gió biển.',
      categories: ['RESTAURANT', 'BUFFET'],
      logoUrl: 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 150000, max: 600000 },
      vibes: ['Ngoài trời / Sân vườn', 'Rộng rãi / Nhóm đông', 'Ấm cúng / Gia đình'],
      purposes: ['Bữa ăn gia đình', 'Tụ tập bạn bè', 'Tiếp khách / Đối tác'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 312 },
      googleRating: { rating: 4.6, userRatingsTotal: 3450 },
    },
    branch: {
      name: 'Hải Sản Bé Mặn - Lô 11 Võ Nguyên Giáp',
      address: {
        street: 'Lô 11 Võ Nguyên Giáp',
        ward: 'Mân Thái',
        district: 'Sơn Trà',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2435, 16.0712],
      },
      phone: '0905 207 848',
      amenities: ['WIFI', 'PARKING', 'OUTDOOR_SEATING', 'SEA_VIEW'],
    },
    products: [
      {
        name: 'Tôm Hùm Bông Nướng Phô Mai',
        category: 'Hải Sản Cao Cấp',
        description: 'Tôm hùm tươi sống nướng sốt phô mai béo ngậy thơm nức.',
        price: 450000,
        imageUrl: 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Cua Huỳnh Đế Hấp Sả Gừng',
        category: 'Đặc Sản Biển',
        description: 'Cua thịt chắc ngọt, gạch béo thơm đặc sản biển miền Trung.',
        price: 380000,
        imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Mực Trứng Hấp Hành Gừng',
        category: 'Món Nhậu Đậm Đà',
        description: 'Mực trứng tươi rói nguyên con giòn ngọt đậm đà chấm mắm gừng.',
        price: 180000,
        imageUrl: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Trần Văn Đảnh (Chủ Quán Năm Đảnh)',
      email: 'owner.namdanh@fconnect.vn',
      password: 'merchant123',
      phone: '0905333111',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Hải Sản Năm Đảnh',
      slug: 'hai-san-nam-danh-tho-quang',
      description: 'Hải sản bình dân nức tiếng Đà Nẵng, đồ ăn tươi ngon đồng giá cực hấp dẫn dành cho sinh viên và du khách.',
      categories: ['RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1559742811-822873691df8?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 60000, max: 220000 },
      vibes: ['Sôi động / Nhộn nhịp', 'Rộng rãi / Nhóm đông', 'Vỉa hè / Đường phố'],
      purposes: ['Tụ tập bạn bè', 'Bữa ăn gia đình'],
      status: 'APPROVED',
      ratingSummary: { average: 4.7, totalReviews: 520 },
      googleRating: { rating: 4.5, userRatingsTotal: 6200 },
    },
    branch: {
      name: 'Hải Sản Năm Đảnh - Trần Quang Khải',
      address: {
        street: 'K139/H59/38 Trần Quang Khải',
        ward: 'Thọ Quang',
        district: 'Sơn Trà',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2562, 16.1025],
      },
      phone: '0905 333 111',
      amenities: ['PARKING', 'OUTDOOR_SEATING'],
    },
    products: [
      {
        name: 'Ống Điếu Xào Sa Tế Cay',
        category: 'Ốc & Sò',
        description: 'Ốc giòn sần sật xào sa tế cay nồng thơm lừng.',
        price: 85000,
        imageUrl: 'https://images.unsplash.com/photo-1559742811-822873691df8?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Gỏi Cá Trích Nam Ô',
        category: 'Đặc Sản',
        description: 'Cá trích tươi rút xương trộn thính giòn bùi cuốn bánh tráng rau rừng.',
        price: 95000,
        imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Càng Cúm Rang Muối Ớt',
        category: 'Cua Ghẹ',
        description: 'Càng cúm đậm vị muối ớt cay xè lai rai cực đỉnh.',
        price: 90000,
        imageUrl: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Nguyễn Mộc (Chủ Quán Mộc Quán)',
      email: 'owner.mocquan@fconnect.vn',
      password: 'merchant123',
      phone: '0905666777',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Hải Sản Mộc Quán',
      slug: 'hai-san-moc-quan-to-hien-thanh',
      description: 'Không gian mở phong cách mộc mạc dân dã, nổi tiếng với món hải sản sốt phô mai và nướng than hoa.',
      categories: ['RESTAURANT', 'BBQ'],
      logoUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 100000, max: 350000 },
      vibes: ['Ngoài trời / Sân vườn', 'Ấm cúng / Gia đình', 'Rộng rãi / Nhóm đông'],
      purposes: ['Bữa ăn gia đình', 'Tụ tập bạn bè', 'Hẹn hò cặp đôi'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 280 },
      googleRating: { rating: 4.7, userRatingsTotal: 2100 },
    },
    branch: {
      name: 'Mộc Quán - 26 Tô Hiến Thành',
      address: {
        street: '26 Tô Hiến Thành',
        ward: 'Phước Mỹ',
        district: 'Sơn Trà',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2415, 16.061],
      },
      phone: '0905 666 777',
      amenities: ['WIFI', 'PARKING', 'AIR_CONDITIONING', 'OUTDOOR_SEATING'],
    },
    products: [
      {
        name: 'Hàu Nướng Phô Mai Mộc',
        category: 'Hải Sản Nướng',
        description: 'Hàu sữa béo múp ngập phô mai mozzarella kéo sợi.',
        price: 120000,
        imageUrl: 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Tôm Sú Nướng Muối Ớt Xanh',
        category: 'Hải Sản Nướng',
        description: 'Tôm sú tươi sống nướng than giòn vỏ thơm ngọt.',
        price: 160000,
        imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Bà Mua (Chủ Quán Mì Quảng Bà Mua)',
      email: 'owner.bamua@fconnect.vn',
      password: 'merchant123',
      phone: '0905888222',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Mì Quảng Bà Mua',
      slug: 'mi-quang-ba-mua-tran-binh-trong',
      description: 'Hệ thống Mì Quảng trứ danh Đà Nẵng với nước nhưn đậm đà, tôm thịt ếch gà tươi ngon, bánh tráng giòn rụm.',
      categories: ['RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 35000, max: 70000 },
      vibes: ['Ấm cúng / Gia đình', 'Cổ điển / Vintage'],
      purposes: ['Bữa ăn gia đình', 'Ăn một mình / Chill'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 410 },
      googleRating: { rating: 4.6, userRatingsTotal: 4800 },
    },
    branch: {
      name: 'Mì Quảng Bà Mua - 19 Trần Bình Trọng',
      address: {
        street: '19 Trần Bình Trọng',
        ward: 'Phước Ninh',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2201, 16.0638],
      },
      phone: '0905 888 222',
      amenities: ['WIFI', 'AIR_CONDITIONING', 'PARKING'],
    },
    products: [
      {
        name: 'Mì Quảng Gà Ta Rút Xương',
        category: 'Mì Quảng Đặc Sản',
        description: 'Thịt gà ta thả vườn dai thơm quyện nước cốt gà vàng óng.',
        price: 45000,
        imageUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Mì Quảng Tôm Thịt Trứng Cút',
        category: 'Mì Quảng Đặc Sản',
        description: 'Tôm sông rim mặn ngọt cùng thịt ba chỉ đậm vị quê hương.',
        price: 40000,
        imageUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Mì Quảng Ếch Đồng Niêu Đất',
        category: 'Mì Quảng Đặc Sản',
        description: 'Thịt ếch đồng kho sả ớt trong niêu đất thơm lừng ăn kèm mì sợi dẻo.',
        price: 55000,
        imageUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Lê Thị Một (Chủ Quán Mì Quảng 1A)',
      email: 'owner.miquang1a@fconnect.vn',
      password: 'merchant123',
      phone: '0905111222',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Mì Quảng 1A Hải Phòng',
      slug: 'mi-quang-1a-hai-phong',
      description: 'Quán mì Quảng lâu đời nhất nhì Đà Nẵng, sợi mì dai ngon, nước dùng sánh đậm vị truyền thống.',
      categories: ['RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 30000, max: 65000 },
      vibes: ['Cổ điển / Vintage', 'Ấm cúng / Gia đình'],
      purposes: ['Bữa ăn gia đình', 'Ăn một mình / Chill'],
      status: 'APPROVED',
      ratingSummary: { average: 4.7, totalReviews: 295 },
      googleRating: { rating: 4.5, userRatingsTotal: 3200 },
    },
    branch: {
      name: 'Mì Quảng 1A - 1A Hải Phòng',
      address: {
        street: '1A Hải Phòng',
        ward: 'Hải Châu 1',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2195, 16.0722],
      },
      phone: '0236 3827 936',
      amenities: ['WIFI', 'PARKING'],
    },
    products: [
      {
        name: 'Mì Quảng Thập Cẩm Đặc Biệt',
        category: 'Mì Quảng',
        description: 'Đầy đủ tôm, thịt, gà, trứng cút cùng rau sống hoa chuối bắp.',
        price: 50000,
        imageUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Chả Bò Đà Nẵng Thượng Hạng',
        category: 'Ăn Kèm',
        description: 'Chả bò giòn ngọt cay nhẹ tiêu đen chuẩn vị Đà Nẵng.',
        price: 25000,
        imageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Phạm Đại Lộc (Chủ Quán Đại Lộc)',
      email: 'owner.dailoc@fconnect.vn',
      password: 'merchant123',
      phone: '0905555444',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Bánh Tráng Cuốn Thịt Heo Đại Lộc Quán',
      slug: 'banh-trang-thit-heo-dai-loc-quan',
      description: 'Đặc sản bánh tráng Đại Lộc phơi sương, thịt heo hai đầu da luộc mềm ngọt ăn cùng mắm nêm đậm đà bí truyền.',
      categories: ['RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 45000, max: 120000 },
      vibes: ['Ấm cúng / Gia đình', 'Rộng rãi / Nhóm đông'],
      purposes: ['Bữa ăn gia đình', 'Tụ tập bạn bè', 'Tiếp khách / Đối tác'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 340 },
      googleRating: { rating: 4.6, userRatingsTotal: 2900 },
    },
    branch: {
      name: 'Đại Lộc Quán - 97 Trưng Nữ Vương',
      address: {
        street: '97 Trưng Nữ Vương',
        ward: 'Bình Hiên',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2198, 16.0582],
      },
      phone: '0905 555 444',
      amenities: ['WIFI', 'AIR_CONDITIONING', 'PARKING'],
    },
    products: [
      {
        name: 'Mẹt Thịt Heo Hai Đầu Da Bánh Tráng Đại Lộc',
        category: 'Món Chính',
        description: 'Thịt luộc mềm béo hai đầu da cuốn kèm đĩa rau rừng tươi mơn mởn.',
        price: 95000,
        imageUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Cá Nục Hấp Cuốn Bánh Tráng',
        category: 'Đặc Sản',
        description: 'Cá nục tươi hấp hành ớt cuốn bánh tráng chấm mắm cay.',
        price: 85000,
        imageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Cô Ba (Chủ Quán Bánh Xèo Cô Ba)',
      email: 'owner.banhxeocoba@fconnect.vn',
      password: 'merchant123',
      phone: '0905222999',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Bánh Xèo Tôm Nhảy Cô Ba',
      slug: 'banh-xeo-tom-nhay-co-ba',
      description: 'Bánh xèo vỏ giòn rụm màu vàng óng, tôm đất nhảy tanh tách ngọt lịm chấm sốt tương gan đậu phộng gia truyền béo ngậy.',
      categories: ['RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 35000, max: 85000 },
      vibes: ['Ấm cúng / Gia đình', 'Sôi động / Nhộn nhịp'],
      purposes: ['Tụ tập bạn bè', 'Bữa ăn gia đình'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 285 },
      googleRating: { rating: 4.6, userRatingsTotal: 3400 },
    },
    branch: {
      name: 'Bánh Xèo Cô Ba - 248 Trưng Nữ Vương',
      address: {
        street: '248 Trưng Nữ Vương',
        ward: 'Bình Thuận',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2185, 16.052],
      },
      phone: '0905 222 999',
      amenities: ['WIFI', 'PARKING'],
    },
    products: [
      {
        name: 'Bánh Xèo Tôm Nhảy Giòn Rụm',
        category: 'Bánh Xèo',
        description: 'Tôm tươi sống nhảy tanh tách đúc cùng giá đỗ thơm giòn.',
        price: 40000,
        imageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Nem Lụi Nướng Than Hoa',
        category: 'Nem Lụi',
        description: 'Nem lụi thịt nạc vai băm nhuyễn thơm mùi sả nướng trên than hoa.',
        price: 12000,
        imageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Nguyễn Văn Hờn (Chủ Quán Bún Chả Cá 109)',
      email: 'owner.bunchaca109@fconnect.vn',
      password: 'merchant123',
      phone: '0905777888',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Bún Chả Cá 109 Nguyễn Chí Thanh',
      slug: 'bun-cha-ca-109-nguyen-chi-thanh',
      description: 'Nồi nước dùng ninh từ xương cá ngọt thanh tự nhiên cùng bí đỏ, măng, thơm cà chua. Chả cá hấp và chiên dai ngon không pha bột.',
      categories: ['RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 30000, max: 55000 },
      vibes: ['Cổ điển / Vintage', 'Ấm cúng / Gia đình'],
      purposes: ['Ăn một mình / Chill', 'Bữa ăn gia đình'],
      status: 'APPROVED',
      ratingSummary: { average: 4.7, totalReviews: 360 },
      googleRating: { rating: 4.6, userRatingsTotal: 4100 },
    },
    branch: {
      name: 'Bún Chả Cá 109 - 109 Nguyễn Chí Thanh',
      address: {
        street: '109 Nguyễn Chí Thanh',
        ward: 'Hải Châu 1',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2215, 16.0695],
      },
      phone: '0236 3825 148',
      amenities: ['WIFI', 'PARKING'],
    },
    products: [
      {
        name: 'Tô Bún Chả Cá Đặc Biệt (Cá Thu + Cá Thác Lác)',
        category: 'Bún Chả Cá',
        description: 'Tô bún đầy ắp chả chiên giòn, chả hấp ngọt thịt kèm nước dùng thanh tao.',
        price: 45000,
        imageUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Lê Quốc Hải (Chủ Cơm Gà A Hải)',
      email: 'owner.comgaahai@fconnect.vn',
      password: 'merchant123',
      phone: '0905123999',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Cơm Gà A Hải',
      slug: 'com-ga-a-hai-thai-phien',
      description: 'Cơm gà xối mỡ trứ danh với đùi gà chiên vàng ươm da giòn rụm bên ngoài, mềm mọng nước bên trong, hạt cơm dẻo vàng óng.',
      categories: ['RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 40000, max: 90000 },
      vibes: ['Sôi động / Nhộn nhịp', 'Ấm cúng / Gia đình'],
      purposes: ['Bữa ăn gia đình', 'Ăn một mình / Chill'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 430 },
      googleRating: { rating: 4.6, userRatingsTotal: 5200 },
    },
    branch: {
      name: 'Cơm Gà A Hải - 100 Thái Phiên',
      address: {
        street: '100 Thái Phiên',
        ward: 'Phước Ninh',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2208, 16.0645],
      },
      phone: '0905 123 999',
      amenities: ['WIFI', 'AIR_CONDITIONING', 'PARKING'],
    },
    products: [
      {
        name: 'Cơm Gà Xối Mỡ Đùi Góc Tư',
        category: 'Cơm Gà',
        description: 'Đùi gà giòn tan vàng ươm ăn kèm kim chi và canh lá giang chua nhẹ.',
        price: 65000,
        imageUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Hoàng Ngọc (Chủ Bún Mắm Ngọc)',
      email: 'owner.bunmamngoc@fconnect.vn',
      password: 'merchant123',
      phone: '0905444111',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Bún Mắm Nêm Ngọc Đà Nẵng',
      slug: 'bun-mam-nem-ngoc-da-nang',
      description: 'Hương vị bún mắm nêm chuẩn miền Trung với thịt heo quay giòn bì, nem chua, chả bò và chén mắm nêm thơm nồng khó quên.',
      categories: ['RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 25000, max: 50000 },
      vibes: ['Ấm cúng / Gia đình', 'Vỉa hè / Đường phố'],
      purposes: ['Ăn một mình / Chill', 'Tụ tập bạn bè'],
      status: 'APPROVED',
      ratingSummary: { average: 4.7, totalReviews: 240 },
      googleRating: { rating: 4.5, userRatingsTotal: 1800 },
    },
    branch: {
      name: 'Bún Mắm Ngọc - 20 Đoàn Thị Điểm',
      address: {
        street: '20 Đoàn Thị Điểm',
        ward: 'Hải Châu 2',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2168, 16.068],
      },
      phone: '0905 444 111',
      amenities: ['WIFI', 'PARKING'],
    },
    products: [
      {
        name: 'Tô Bún Mắm Heo Quay Đặc Biệt',
        category: 'Bún Mắm',
        description: 'Heo quay giòn rụm, mít non thái sợi, rau thơm tươi trộn mắm nêm cá cơm nguyên chất.',
        price: 35000,
        imageUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Lưu Khải (Chủ 43 Factory Coffee)',
      email: 'owner.43factory@fconnect.vn',
      password: 'merchant123',
      phone: '0905999000',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: '43 Factory Coffee Roaster',
      slug: '43-factory-coffee-roaster',
      description: 'Không gian cà phê Specialty hàng đầu Việt Nam giữa hồ cá Koi xanh mát. Nơi tôn vinh hương vị hạt cà phê nguyên bản thế giới.',
      categories: ['CAFE', 'DESSERT'],
      logoUrl: 'https://images.unsplash.com/photo-1559925393-8be0ec4767c8?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 60000, max: 150000 },
      vibes: ['Hiện đại / Sang trọng', 'Yên tĩnh / Làm việc', 'Check-in sống ảo'],
      purposes: ['Họp nhóm / Học bài', 'Gặp gỡ bạn bè', 'Ăn một mình / Chill'],
      status: 'APPROVED',
      ratingSummary: { average: 4.9, totalReviews: 480 },
      googleRating: { rating: 4.8, userRatingsTotal: 3800 },
    },
    branch: {
      name: '43 Factory - Lô 422 Ngô Thì Sĩ',
      address: {
        street: 'Lô 422 Ngô Thì Sĩ',
        ward: 'Mỹ An',
        district: 'Ngũ Hành Sơn',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2448, 16.0489],
      },
      phone: '0905 999 000',
      amenities: ['WIFI', 'AIR_CONDITIONING', 'PARKING', 'OUTDOOR_SEATING'],
    },
    products: [
      {
        name: 'Single Origin Drip Coffee (Ethiopia)',
        category: 'Specialty Coffee',
        description: 'Chiết xuất phương pháp V60 mang nốt hương hoa quả thanh nhã.',
        price: 110000,
        imageUrl: 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Croissant Hạnh Nhân Bơ Pháp',
        category: 'Pastry',
        description: 'Bánh sừng bò ngàn lớp xốp giòn nướng thơm lừng.',
        price: 65000,
        imageUrl: 'https://images.unsplash.com/photo-1509722747041-616f39b57569?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Trần Trình (Chủ Trình Cà Phê)',
      email: 'owner.trinhcafe@fconnect.vn',
      password: 'merchant123',
      phone: '0905111333',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Trình Cà Phê (Lê Đình Dương)',
      slug: 'trinh-ca-phe-le-dinh-duong',
      description: 'Quán cà phê mang phong cách Hội An xưa với bức tường vàng cổ kính, món Cà phê Bơ đặc sản ngậy béo làm say lòng giới trẻ.',
      categories: ['CAFE'],
      logoUrl: 'https://images.unsplash.com/photo-1559925393-8be0ec4767c8?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 25000, max: 50000 },
      vibes: ['Cổ điển / Vintage', 'Check-in sống ảo', 'Ấm cúng / Gia đình'],
      purposes: ['Gặp gỡ bạn bè', 'Hẹn hò cặp đôi', 'Thư giãn cuối tuần'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 320 },
      googleRating: { rating: 4.7, userRatingsTotal: 2600 },
    },
    branch: {
      name: 'Trình Cà Phê - 22/4 Lê Đình Dương',
      address: {
        street: '22/4 Lê Đình Dương',
        ward: 'Phước Ninh',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.219, 16.0615],
      },
      phone: '0905 111 333',
      amenities: ['WIFI', 'OUTDOOR_SEATING'],
    },
    products: [
      {
        name: 'Cà Phê Bơ Béo Ngậy (Món Tủ)',
        category: 'Cà Phê Sáng Tạo',
        description: 'Bơ sáp xay sánh mịn kết hợp cà phê phin đậm đà thơm ngát.',
        price: 42000,
        imageUrl: 'https://images.unsplash.com/photo-1572490122747-3968b75cc699?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Nguyễn Cộng (Chủ Cộng Cà Phê Bạch Đằng)',
      email: 'owner.congbachdang@fconnect.vn',
      password: 'merchant123',
      phone: '0905888333',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Cộng Cà Phê - Bạch Đằng',
      slug: 'cong-ca-phe-bach-dang',
      description: 'Tọa lạc ngay mặt tiền bờ sông Hàn thơ mộng ngắm cầu Rồng. Nổi tiếng với Cà Phê Cốt Dừa thơm béo và phong cách thời bao cấp.',
      categories: ['CAFE'],
      logoUrl: 'https://images.unsplash.com/photo-1559925393-8be0ec4767c8?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 35000, max: 75000 },
      vibes: ['Cổ điển / Vintage', 'Ngoài trời / Sân vườn', 'Check-in sống ảo'],
      purposes: ['Gặp gỡ bạn bè', 'Thư giãn cuối tuần', 'Ăn một mình / Chill'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 540 },
      googleRating: { rating: 4.6, userRatingsTotal: 6900 },
    },
    branch: {
      name: 'Cộng Cà Phê - 96 Bạch Đằng',
      address: {
        street: '96 - 98 Bạch Đằng',
        ward: 'Hải Châu 1',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2241, 16.0692],
      },
      phone: '0236 6553 644',
      amenities: ['WIFI', 'AIR_CONDITIONING', 'RIVER_VIEW', 'OUTDOOR_SEATING'],
    },
    products: [
      {
        name: 'Cà Phê Cốt Dừa Đá Xay',
        category: 'Món Chữ Ký',
        description: 'Cốt dừa béo ngậy ngọt dịu hòa quyện cà phê phin truyền thống.',
        price: 55000,
        imageUrl: 'https://images.unsplash.com/photo-1572490122747-3968b75cc699?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Trần BonPas (Chủ BonPas Bakery)',
      email: 'owner.bonpas@fconnect.vn',
      password: 'merchant123',
      phone: '0905777111',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'BonPas Bakery & Coffee',
      slug: 'bonpas-bakery-and-coffee',
      description: 'Thiên đường bánh ngọt tươi trong ngày và cà phê hiện đại. Không gian trẻ trung, bánh ngon chuẩn hương vị Âu.',
      categories: ['BAKERY', 'CAFE', 'DESSERT'],
      logoUrl: 'https://images.unsplash.com/photo-1509722747041-616f39b57569?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 25000, max: 70000 },
      vibes: ['Hiện đại / Sang trọng', 'Yên tĩnh / Làm việc', 'Ấm cúng / Gia đình'],
      purposes: ['Họp nhóm / Học bài', 'Gặp gỡ bạn bè'],
      status: 'APPROVED',
      ratingSummary: { average: 4.7, totalReviews: 290 },
      googleRating: { rating: 4.5, userRatingsTotal: 3100 },
    },
    branch: {
      name: 'BonPas - 143 Nguyễn Chí Thanh',
      address: {
        street: '143 Nguyễn Chí Thanh',
        ward: 'Hải Châu 1',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2212, 16.0682],
      },
      phone: '0236 3888 388',
      amenities: ['WIFI', 'AIR_CONDITIONING', 'PARKING'],
    },
    products: [
      {
        name: 'Bánh Mì Phô Mai Bơ Tỏi Hàn Quốc',
        category: 'Bánh Tươi Hàng Ngày',
        description: 'Lớp kem phô mai béo ngậy ngập tràn bên trong vỏ bánh bơ tỏi thơm lừng.',
        price: 38000,
        imageUrl: 'https://images.unsplash.com/photo-1509722747041-616f39b57569?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Ngô Hươu (Chủ The Alley Đà Nẵng)',
      email: 'owner.thealley@fconnect.vn',
      password: 'merchant123',
      phone: '0905333777',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'The Alley - Trân Châu Đường Đen',
      slug: 'the-alley-tran-chau-duong-den',
      description: 'Thương hiệu trà sữa trân châu đường đen số 1 với sữa tươi thanh trùng Đà Lạt ngọt béo và trân châu thủ công dẻo quánh.',
      categories: ['MILK_TEA', 'DESSERT'],
      logoUrl: 'https://images.unsplash.com/photo-1558857563-b371033873b8?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1558857563-b371033873b8?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 45000, max: 85000 },
      vibes: ['Hiện đại / Sang trọng', 'Check-in sống ảo'],
      purposes: ['Gặp gỡ bạn bè', 'Hẹn hò cặp đôi'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 310 },
      googleRating: { rating: 4.6, userRatingsTotal: 2500 },
    },
    branch: {
      name: 'The Alley - 298 Đống Đa',
      address: {
        street: '298 Đống Đa',
        ward: 'Thanh Bình',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.214, 16.0775],
      },
      phone: '0236 6555 298',
      amenities: ['WIFI', 'AIR_CONDITIONING', 'PARKING'],
    },
    products: [
      {
        name: 'Sữa Tươi Trân Châu Đường Đen Hoàng Gia',
        category: 'Trà Sữa Chữ Ký',
        description: 'Vị ngọt thanh dịu từ mật mía tự nhiên hòa sữa tươi thanh trùng.',
        price: 62000,
        imageUrl: 'https://images.unsplash.com/photo-1558857563-b371033873b8?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Kim Gogi (Chủ Gogi House Vincom)',
      email: 'owner.gogivincom@fconnect.vn',
      password: 'merchant123',
      phone: '02367300515',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Gogi House - Vincom Ngô Quyền',
      slug: 'gogi-house-vincom-ngo-quyen',
      description: 'Quán thịt nướng Hàn Quốc đỉnh cao với dẻ sườn bò Mỹ sốt Galbi, ba chỉ bò ướp đậm đà nướng tại bàn cùng lẩu kim chi chua cay.',
      categories: ['BBQ', 'RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 200000, max: 450000 },
      vibes: ['Hiện đại / Sang trọng', 'Ấm cúng / Gia đình', 'Rộng rãi / Nhóm đông'],
      purposes: ['Bữa ăn gia đình', 'Tụ tập bạn bè', 'Sinh nhật / Tiệc'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 420 },
      googleRating: { rating: 4.7, userRatingsTotal: 3900 },
    },
    branch: {
      name: 'Gogi House - Tầng 4 Vincom Ngô Quyền',
      address: {
        street: '910A Ngô Quyền',
        ward: 'An Hải Bắc',
        district: 'Sơn Trà',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2315, 16.0718],
      },
      phone: '0236 7300 515',
      amenities: ['WIFI', 'AIR_CONDITIONING', 'PARKING', 'PRIVATE_ROOM'],
    },
    products: [
      {
        name: 'Dẻ Sườn Bò Mỹ Sốt Galbi Thượng Hạng',
        category: 'Thịt Nướng Hàn Quốc',
        description: 'Thịt bò vân mỡ đan xen mềm ngọt ướp sốt hoa quả truyền thống.',
        price: 269000,
        imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Nguyễn Ba Duệ (Chủ Lẩu Bò Ba Duệ)',
      email: 'owner.laubobadue@fconnect.vn',
      password: 'merchant123',
      phone: '0905123444',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Lẩu Bò Ba Duệ',
      slug: 'lau-bo-ba-due-thi-sach',
      description: 'Nồi lẩu bò ngập tràn thịt nạm gân mềm nhừ, đuôi bò giòn sần sật, nước dùng hầm xương ngọt lịm thơm mùi thảo mộc.',
      categories: ['RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 80000, max: 250000 },
      vibes: ['Sôi động / Nhộn nhịp', 'Ấm cúng / Gia đình', 'Rộng rãi / Nhóm đông'],
      purposes: ['Tụ tập bạn bè', 'Bữa ăn gia đình'],
      status: 'APPROVED',
      ratingSummary: { average: 4.7, totalReviews: 310 },
      googleRating: { rating: 4.6, userRatingsTotal: 2800 },
    },
    branch: {
      name: 'Lẩu Bò Ba Duệ - 40 Thi Sách',
      address: {
        street: '40 Thi Sách',
        ward: 'Hòa Thuận Tây',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2045, 16.0528],
      },
      phone: '0905 123 444',
      amenities: ['WIFI', 'PARKING', 'OUTDOOR_SEATING'],
    },
    products: [
      {
        name: 'Nồi Lẩu Bò Thập Cẩm Niêu Lớn',
        category: 'Lẩu Bò',
        description: 'Bao gồm nạm, gân, đuôi bò, đậu khuôn, rau má xanh mướt.',
        price: 220000,
        imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Madame Lân (Chủ Nhà Hàng Madame Lân)',
      email: 'owner.madamelan@fconnect.vn',
      password: 'merchant123',
      phone: '0905697555',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Madame Lân Restaurant',
      slug: 'madame-lan-restaurant-bach-dang',
      description: 'Nhà hàng ẩm thực 3 miền Việt Nam trong khuôn viên biệt thự phố cổ ven sông Hàn. Điểm đến ẩm thực sang trọng cho du khách quốc tế.',
      categories: ['RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 80000, max: 350000 },
      vibes: ['Hiện đại / Sang trọng', 'Ấm cúng / Gia đình', 'Ngoài trời / Sân vườn'],
      purposes: ['Tiếp khách / Đối tác', 'Bữa ăn gia đình', 'Hẹn hò cặp đôi'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 620 },
      googleRating: { rating: 4.7, userRatingsTotal: 8400 },
    },
    branch: {
      name: 'Madame Lân - 04 Bạch Đằng',
      address: {
        street: '04 Bạch Đằng',
        ward: 'Thạch Thang',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2238, 16.0792],
      },
      phone: '0905 697 555',
      amenities: ['WIFI', 'AIR_CONDITIONING', 'PARKING', 'RIVER_VIEW', 'PRIVATE_ROOM'],
    },
    products: [
      {
        name: 'Bánh Khoái Tôm Thịt Hoàng Cung',
        category: 'Đặc Sản Cố Đô',
        description: 'Bánh chiên giòn rụm với tôm tươi thịt băm ăn kèm nước lèo đậu gan.',
        price: 75000,
        imageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Yosuke Masuko (Chủ Pizza 4Ps)',
      email: 'owner.pizza4ps@fconnect.vn',
      password: 'merchant123',
      phone: '02836220500',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: "Pizza 4P's - Indochina Bạch Đằng",
      slug: 'pizza-4ps-indochina-bach-dang',
      description: 'Nhà hàng Pizza lò củi nổi tiếng toàn cầu, mang triết lý Making the World Smile for Peace qua phô mai tươi tự làm và ẩm thực Ý - Nhật.',
      categories: ['RESTAURANT', 'DESSERT'],
      logoUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 150000, max: 550000 },
      vibes: ['Lãng mạn / Hẹn hò', 'Hiện đại / Sang trọng', 'Ấm cúng / Gia đình'],
      purposes: ['Hẹn hò cặp đôi', 'Tiếp khách / Đối tác', 'Sinh nhật / Tiệc'],
      status: 'APPROVED',
      ratingSummary: { average: 4.9, totalReviews: 890 },
      googleRating: { rating: 4.8, userRatingsTotal: 9600 },
    },
    branch: {
      name: "Pizza 4P's - 74 Bạch Đằng",
      address: {
        street: '74 Bạch Đằng',
        ward: 'Hải Châu 1',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2245, 16.0712],
      },
      phone: '028 3622 0500',
      amenities: ['WIFI', 'AIR_CONDITIONING', 'RIVER_VIEW', 'PRIVATE_ROOM'],
    },
    products: [
      {
        name: 'Pizza 4 Cheese Kèm Mật Ong Rừng',
        category: 'Pizza Lò Củi',
        description: 'Sự kết hợp hoàn hảo của 4 loại phô mai cao cấp cùng mật ong hoa rừng ngọt dịu.',
        price: 240000,
        imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Mì Ý Cua Sốt Kem Cà Chua Cay',
        category: 'Pasta',
        description: 'Thịt cua tươi ngọt lịm nguyên con hòa quyện sốt kem cà chua béo ngậy.',
        price: 225000,
        imageUrl: 'https://images.unsplash.com/photo-1621996346565-e3d5d6281273?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'David Thái (Chủ Highlands Coffee NVL)',
      email: 'owner.highlands@fconnect.vn',
      password: 'merchant123',
      phone: '02363888999',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Highlands Coffee - Nguyễn Văn Linh',
      slug: 'highlands-coffee-nguyen-van-linh-dn',
      description: 'Thương hiệu cà phê quốc dân với Phin Sữa Đá đượm vị đậm đà và Freeze Trà Xanh mát lạnh ngay góc phố sầm uất Nguyễn Văn Linh.',
      categories: ['CAFE', 'BAKERY'],
      logoUrl: 'https://images.unsplash.com/photo-1559925393-8be0ec4767c8?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 29000, max: 75000 },
      vibes: ['Hiện đại / Sang trọng', 'Ngoài trời / Sân vườn', 'Yên tĩnh / Làm việc'],
      purposes: ['Họp nhóm / Học bài', 'Gặp gỡ bạn bè'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 380 },
      googleRating: { rating: 4.6, userRatingsTotal: 4200 },
    },
    branch: {
      name: 'Highlands Coffee - 186 Nguyễn Văn Linh',
      address: {
        street: '186 Nguyễn Văn Linh',
        ward: 'Nam Dương',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2165, 16.0605],
      },
      phone: '0236 3888 999',
      amenities: ['WIFI', 'AIR_CONDITIONING', 'PARKING', 'OUTDOOR_SEATING'],
    },
    products: [
      {
        name: 'Phin Sữa Đá Cỡ Lớn',
        category: 'Cà Phê Phin',
        description: 'Cà phê phin truyền thống thơm nồng kết hợp sữa đặc ngọt ngào.',
        price: 39000,
        imageUrl: 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Freeze Trà Xanh Thạch Giòn',
        category: 'Đá Xay',
        description: 'Trà xanh đá xay mát lạnh cùng thạch giòn sần sật và kem tươi béo.',
        price: 55000,
        imageUrl: 'https://images.unsplash.com/photo-1572490122747-3968b75cc699?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Nguyễn Thị Trang (Chủ Bếp Trang)',
      email: 'owner.beptrang@fconnect.vn',
      password: 'merchant123',
      phone: '0905123555',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Bếp Trang - Mì Quảng Ếch',
      slug: 'bep-trang-mi-quang-ech-pasteur',
      description: 'Mì Quảng Ếch độc đáo trứ danh Đà Nẵng, ếch đồng kho sả ớt trong thố đất nghi ngút khói chấm bánh tráng mè nướng giòn.',
      categories: ['RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 45000, max: 95000 },
      vibes: ['Ấm cúng / Gia đình', 'Hiện đại / Sang trọng'],
      purposes: ['Bữa ăn gia đình', 'Tụ tập bạn bè', 'Tiếp khách / Đối tác'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 410 },
      googleRating: { rating: 4.6, userRatingsTotal: 3800 },
    },
    branch: {
      name: 'Bếp Trang - 24 Pasteur',
      address: {
        street: '24 Pasteur',
        ward: 'Hải Châu 1',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2195, 16.0705],
      },
      phone: '0905 123 555',
      amenities: ['WIFI', 'AIR_CONDITIONING', 'PARKING'],
    },
    products: [
      {
        name: 'Mẹt Mì Quảng Ếch Thố Đất Đặc Biệt',
        category: 'Mì Quảng',
        description: 'Ếch đồng béo ngậy rim sả ớt trong thố đất ăn kèm sợi mì vàng nghệ dẻo thơm.',
        price: 79000,
        imageUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Nguyễn Thị Hoa (Chủ Bánh Tráng Dì Hoa)',
      email: 'owner.dihoa@fconnect.vn',
      password: 'merchant123',
      phone: '0905888123',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Bánh Tráng Kẹp Dì Hoa',
      slug: 'banh-trang-kep-di-hoa-nui-thanh',
      description: 'Món ăn vặt tuổi thơ nổi tiếng nhất Đà Nẵng với bánh tráng kẹp pate trải giòn, bò khô trứng cút chấm nước bò sốt cay ngọt sền sệt.',
      categories: ['FAST_FOOD', 'DESSERT'],
      logoUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 15000, max: 40000 },
      vibes: ['Vỉa hè / Đường phố', 'Sôi động / Nhộn nhịp'],
      purposes: ['Tụ tập bạn bè', 'Ăn một mình / Chill'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 520 },
      googleRating: { rating: 4.7, userRatingsTotal: 4900 },
    },
    branch: {
      name: 'Dì Hoa - 62/2A Núi Thành',
      address: {
        street: '62/2A Núi Thành',
        ward: 'Hòa Cường Bắc',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2208, 16.0545],
      },
      phone: '0905 888 123',
      amenities: ['WIFI', 'PARKING'],
    },
    products: [
      {
        name: 'Đĩa Bánh Tráng Kẹp Pate Trứng Rải',
        category: 'Ăn Vặt',
        description: 'Bánh tráng nướng giòn rụm thơm nức mũi chấm nước sốt bò sa tế gia truyền.',
        price: 20000,
        imageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Phan Mười (Chủ Bê Thui Mười Hiển)',
      email: 'owner.muoihien@fconnect.vn',
      password: 'merchant123',
      phone: '0905333555',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Bê Thui Cầu Mống Mười Hiển',
      slug: 'be-thui-cau-mong-muoi-hien',
      description: 'Bê thui nguyên con quay than hồng chín tới, thịt mềm ngọt hồng hào, da giòn trong suốt cuốn bánh tráng rau rừng chấm mắm nêm mè rang.',
      categories: ['RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 100000, max: 300000 },
      vibes: ['Ấm cúng / Gia đình', 'Rộng rãi / Nhóm đông'],
      purposes: ['Tụ tập bạn bè', 'Bữa ăn gia đình', 'Tiếp khách / Đối tác'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 290 },
      googleRating: { rating: 4.6, userRatingsTotal: 2700 },
    },
    branch: {
      name: 'Mười Hiển - Lô 138 Lê Đình Dương',
      address: {
        street: '138 Lê Đình Dương',
        ward: 'Phước Ninh',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2178, 16.061],
      },
      phone: '0905 333 555',
      amenities: ['WIFI', 'AIR_CONDITIONING', 'PARKING'],
    },
    products: [
      {
        name: 'Dĩa Bê Thui Cầu Mống Nửa Cân',
        category: 'Đặc Sản Bê Thui',
        description: 'Thịt bê chín hồng đào thái mỏng, da giòn sần sật cuốn rau thơm và chuối chát.',
        price: 180000,
        imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Bà Lan (Chủ Bánh Mì Bà Lan)',
      email: 'owner.balan@fconnect.vn',
      password: 'merchant123',
      phone: '0905222444',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Tiệm Bánh Mì Bà Lan',
      slug: 'tiem-banh-mi-ba-lan-trung-nu-vuong',
      description: 'Hương vị bánh mì đệ nhất Đà Thành với lớp pate thơm béo, chả bò cây nhà làm giòn ngọt và giò lụa gia truyền.',
      categories: ['BAKERY', 'FAST_FOOD'],
      logoUrl: 'https://images.unsplash.com/photo-1509722747041-616f39b57569?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1509722747041-616f39b57569?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 20000, max: 40000 },
      vibes: ['Vỉa hè / Đường phố', 'Ấm cúng / Gia đình'],
      purposes: ['Ăn một mình / Chill'],
      status: 'APPROVED',
      ratingSummary: { average: 4.9, totalReviews: 610 },
      googleRating: { rating: 4.7, userRatingsTotal: 7200 },
    },
    branch: {
      name: 'Bánh Mì Bà Lan - 62 Trưng Nữ Vương',
      address: {
        street: '62 Trưng Nữ Vương',
        ward: 'Bình Hiên',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2212, 16.0602],
      },
      phone: '0905 222 444',
      amenities: ['PARKING'],
    },
    products: [
      {
        name: 'Bánh Mì Chả Bò Pate Đặc Biệt',
        category: 'Bánh Mì',
        description: 'Vỏ bánh mì giòn tan ngập tràn pate, chả bò Đà Nẵng và dưa leo ớt xanh giòn rụm.',
        price: 25000,
        imageUrl: 'https://images.unsplash.com/photo-1509722747041-616f39b57569?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Đặng Cua Biển (Chủ Cua Biển Quán)',
      email: 'owner.cuabien@fconnect.vn',
      password: 'merchant123',
      phone: '0905777999',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Hải Sản Cua Biển Quán',
      slug: 'hai-san-cua-bien-quan-my-khe',
      description: 'Nhà hàng hải sản view biển Mỹ Khê tuyệt đẹp, chuyên các loại cua gạch Cà Mau, tôm hùm và cá mú sống thả bể tự nhiên.',
      categories: ['RESTAURANT', 'BUFFET'],
      logoUrl: 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 120000, max: 500000 },
      vibes: ['Ngoài trời / Sân vườn', 'Rộng rãi / Nhóm đông'],
      purposes: ['Bữa ăn gia đình', 'Tiếp khách / Đối tác', 'Tụ tập bạn bè'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 380 },
      googleRating: { rating: 4.6, userRatingsTotal: 3900 },
    },
    branch: {
      name: 'Cua Biển Quán - 112 Võ Nguyên Giáp',
      address: {
        street: '112 Võ Nguyên Giáp',
        ward: 'Phước Mỹ',
        district: 'Sơn Trà',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2442, 16.0648],
      },
      phone: '0905 777 999',
      amenities: ['WIFI', 'PARKING', 'AIR_CONDITIONING', 'SEA_VIEW', 'OUTDOOR_SEATING'],
    },
    products: [
      {
        name: 'Cua Gạch Rang Me Chua Ngọt',
        category: 'Món Cua Biển',
        description: 'Cua gạch đầy ắp sốt me đậm đà chua cay ăn kèm bánh mì nóng giòn.',
        price: 320000,
        imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Trần Nhà Đỏ (Chủ Cơm Niêu Nhà Đỏ)',
      email: 'owner.comnieunhado@fconnect.vn',
      password: 'merchant123',
      phone: '0905444888',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Cơm Niêu Nhà Đỏ Đà Nẵng',
      slug: 'com-nieu-nha-do-da-nang',
      description: 'Bữa cơm gia đình thuần Việt với cơm niêu đập giòn rụm cháy vàng, cá bống kho tộ, canh cua đồng rau đay cà pháo giòn tan.',
      categories: ['RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 70000, max: 250000 },
      vibes: ['Cổ điển / Vintage', 'Ấm cúng / Gia đình'],
      purposes: ['Bữa ăn gia đình', 'Tiếp khách / Đối tác'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 460 },
      googleRating: { rating: 4.6, userRatingsTotal: 4800 },
    },
    branch: {
      name: 'Cơm Niêu Nhà Đỏ - 176 Nguyễn Tri Phương',
      address: {
        street: '176 Nguyễn Tri Phương',
        ward: 'Chính Gián',
        district: 'Thanh Khê',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2045, 16.0592],
      },
      phone: '0905 444 888',
      amenities: ['WIFI', 'AIR_CONDITIONING', 'PARKING', 'PRIVATE_ROOM'],
    },
    products: [
      {
        name: 'Niêu Cơm Đập Cháy Giòn Kèm Cá Bống Kho Tộ',
        category: 'Cơm Niêu',
        description: 'Cơm cháy giòn tan rưới mỡ hành chấm nước cá bống kho tiêu đậm đà.',
        price: 135000,
        imageUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Bà Diệu (Chủ Bún Bò Bà Diệu)',
      email: 'owner.bunbobadieu@fconnect.vn',
      password: 'merchant123',
      phone: '0905111888',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Bún Bò Huế Bà Diệu',
      slug: 'bun-bo-hue-ba-dieu-tran-tong',
      description: 'Nước dùng bún bò hầm xương bò và giò heo thơm lừng mùi sả ruốc Huế, nạm gân bò mềm ngọt cùng chả cua và huyết luộc mọng nước.',
      categories: ['RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 35000, max: 70000 },
      vibes: ['Cổ điển / Vintage', 'Ấm cúng / Gia đình'],
      purposes: ['Bữa ăn gia đình', 'Ăn một mình / Chill'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 310 },
      googleRating: { rating: 4.6, userRatingsTotal: 3400 },
    },
    branch: {
      name: 'Bún Bò Bà Diệu - 17 Trần Tống',
      address: {
        street: '17 Trần Tống',
        ward: 'Vĩnh Trung',
        district: 'Thanh Khê',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2115, 16.0635],
      },
      phone: '0905 111 888',
      amenities: ['WIFI', 'PARKING'],
    },
    products: [
      {
        name: 'Tô Bún Bò Giò Gân Đầy Đủ',
        category: 'Bún Bò',
        description: 'Tô bún bò nóng hổi ngập tràn bắp bò, gân trong, khoanh giò heo và chả cua.',
        price: 55000,
        imageUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Bà Liên (Chủ Chè Liên Đà Nẵng)',
      email: 'owner.chelien@fconnect.vn',
      password: 'merchant123',
      phone: '0905666222',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Chè Liên Đà Nẵng (Chè Sầu)',
      slug: 'che-lien-da-nang-che-sau',
      description: 'Thương hiệu Chè Sầu riêng nức tiếng cả nước với sầu riêng tươi cơm dày béo ngậy ngập tràn nước cốt dừa và thạch ngọc trai.',
      categories: ['DESSERT'],
      logoUrl: 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 20000, max: 45000 },
      vibes: ['Sôi động / Nhộn nhịp', 'Ấm cúng / Gia đình'],
      purposes: ['Gặp gỡ bạn bè', 'Ăn một mình / Chill'],
      status: 'APPROVED',
      ratingSummary: { average: 4.9, totalReviews: 780 },
      googleRating: { rating: 4.8, userRatingsTotal: 8900 },
    },
    branch: {
      name: 'Chè Liên - 189 Hoàng Diệu',
      address: {
        street: '189 Hoàng Diệu',
        ward: 'Nam Dương',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2162, 16.0618],
      },
      phone: '0905 666 222',
      amenities: ['WIFI', 'AIR_CONDITIONING', 'PARKING'],
    },
    products: [
      {
        name: 'Chè Thái Sầu Riêng Đặc Biệt',
        category: 'Chè Đặc Sản',
        description: 'Múi sầu riêng tươi béo ngậy hòa quyện nước cốt dừa béo bùi và thạch rau câu giòn.',
        price: 35000,
        imageUrl: 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Somchai Vũ (Chủ KhaNom Thai)',
      email: 'owner.khanomthai@fconnect.vn',
      password: 'merchant123',
      phone: '0905999444',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'KhaNom Thai Street Food',
      slug: 'khanom-thai-street-food',
      description: 'Thiên đường ẩm thực đường phố Thái Lan với lẩu Tomyum hải sản chua cay bùng nổ vị giác, Pad Thai tôm tươi và xôi xoài ngọt lịm.',
      categories: ['RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1559847844-5315695dadae?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1559847844-5315695dadae?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 45000, max: 150000 },
      vibes: ['Check-in sống ảo', 'Hiện đại / Sang trọng'],
      purposes: ['Gặp gỡ bạn bè', 'Hẹn hò cặp đôi'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 290 },
      googleRating: { rating: 4.6, userRatingsTotal: 2300 },
    },
    branch: {
      name: 'KhaNom Thai - 179 Huỳnh Thúc Kháng',
      address: {
        street: '179 Huỳnh Thúc Kháng',
        ward: 'Bình Hiên',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2168, 16.056],
      },
      phone: '0905 999 444',
      amenities: ['WIFI', 'AIR_CONDITIONING', 'PARKING'],
    },
    products: [
      {
        name: 'Lẩu Tomyum Hải Sản Nước Cốt Dừa',
        category: 'Món Thái',
        description: 'Vị chua cay béo ngậy đặc trưng Thái Lan với tôm mực tươi và nấm tuyết.',
        price: 139000,
        imageUrl: 'https://images.unsplash.com/photo-1559847844-5315695dadae?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Phạm Ly (Chủ The Cup Cafe)',
      email: 'owner.thecupcafe@fconnect.vn',
      password: 'merchant123',
      phone: '0905333888',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'The Cup Cafe - Cà Phê Gần Biển',
      slug: 'the-cup-cafe-nguyen-van-thoai',
      description: 'Quán cà phê không gian mở gần bãi biển Mỹ Khê, bàn ghế gỗ mộc, cây xanh thoáng mát lý tưởng để làm việc và đọc sách.',
      categories: ['CAFE'],
      logoUrl: 'https://images.unsplash.com/photo-1559925393-8be0ec4767c8?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 30000, max: 65000 },
      vibes: ['Yên tĩnh / Làm việc', 'Hiện đại / Sang trọng'],
      purposes: ['Họp nhóm / Học bài', 'Gặp gỡ bạn bè'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 240 },
      googleRating: { rating: 4.6, userRatingsTotal: 1900 },
    },
    branch: {
      name: 'The Cup Cafe - 233 Nguyễn Văn Thoại',
      address: {
        street: '233 Nguyễn Văn Thoại',
        ward: 'Mỹ An',
        district: 'Ngũ Hành Sơn',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2415, 16.0525],
      },
      phone: '0905 333 888',
      amenities: ['WIFI', 'AIR_CONDITIONING', 'PARKING'],
    },
    products: [
      {
        name: 'Trà Đào Cam Sả Tươi Mát',
        category: 'Trà Trái Cây',
        description: 'Vị trà thanh mát kết hợp lát đào giòn và hương sả sảng khoái.',
        price: 45000,
        imageUrl: 'https://images.unsplash.com/photo-1558857563-b371033873b8?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Lâm Brew (Chủ Brewman Coffee)',
      email: 'owner.brewman@fconnect.vn',
      password: 'merchant123',
      phone: '0905222777',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Brewman Coffee Concept',
      slug: 'brewman-coffee-concept',
      description: 'Quán cà phê phong cách nhà kính ẩn mình trong con hẻm yên bình giữa lòng phố Thái Phiên, phục vụ cà phê thủ công tinh tế.',
      categories: ['CAFE'],
      logoUrl: 'https://images.unsplash.com/photo-1559925393-8be0ec4767c8?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 35000, max: 80000 },
      vibes: ['Cổ điển / Vintage', 'Yên tĩnh / Làm việc'],
      purposes: ['Họp nhóm / Học bài', 'Ăn một mình / Chill'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 210 },
      googleRating: { rating: 4.7, userRatingsTotal: 1800 },
    },
    branch: {
      name: 'Brewman - K27A/21 Thái Phiên',
      address: {
        street: 'K27A/21 Thái Phiên',
        ward: 'Phước Ninh',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2225, 16.0652],
      },
      phone: '0905 222 777',
      amenities: ['WIFI', 'AIR_CONDITIONING', 'OUTDOOR_SEATING'],
    },
    products: [
      {
        name: 'Cold Brew Cam Vàng Mát Lạnh',
        category: 'Cold Brew',
        description: 'Cà phê ủ lạnh 24 giờ thơm mùi hoa quả tươi và cam vàng thanh dịu.',
        price: 49000,
        imageUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Võ Garden (Chủ Bao Bì Garden)',
      email: 'owner.baobigarden@fconnect.vn',
      password: 'merchant123',
      phone: '0905888555',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Bao Bì Garden Cafe',
      slug: 'bao-bi-garden-cafe',
      description: 'Quán cà phê sân thượng rooftop view toàn cảnh thành phố và cầu sông Hàn, tràn ngập cây xanh và góc chụp hình cực chill.',
      categories: ['CAFE', 'BAR'],
      logoUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 35000, max: 85000 },
      vibes: ['Rooftop / View trên cao', 'Ngoài trời / Sân vườn', 'Check-in sống ảo'],
      purposes: ['Gặp gỡ bạn bè', 'Hẹn hò cặp đôi'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 260 },
      googleRating: { rating: 4.6, userRatingsTotal: 2200 },
    },
    branch: {
      name: 'Bao Bì Garden - 34 Ngô Gia Tự',
      address: {
        street: '34 Ngô Gia Tự',
        ward: 'Hải Châu 1',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2198, 16.074],
      },
      phone: '0905 888 555',
      amenities: ['WIFI', 'ROOFTOP_VIEW', 'OUTDOOR_SEATING'],
    },
    products: [
      {
        name: 'Trà Lựu Đỏ Macchiato Sân Thượng',
        category: 'Đồ Uống Signatures',
        description: 'Vị trà hoa quả ngọt thơm phủ lớp kem muối mặn mà độc đáo.',
        price: 52000,
        imageUrl: 'https://images.unsplash.com/photo-1558857563-b371033873b8?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Hoàng Manwah (Chủ Manwah Indochina)',
      email: 'owner.manwahdn@fconnect.vn',
      password: 'merchant123',
      phone: '02367300520',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Manwah Taiwanese Hotpot - Indochina',
      slug: 'manwah-taiwanese-hotpot-dn',
      description: 'Thưởng thức buffet lẩu Đài Loan truyền thống với nước dùng thảo mộc thơm lành, thịt bò Mỹ cao cấp, há cảo và quầy buffet kem tráng miệng không giới hạn.',
      categories: ['BUFFET', 'RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 250000, max: 490000 },
      vibes: ['Hiện đại / Sang trọng', 'Ấm cúng / Gia đình', 'Rộng rãi / Nhóm đông'],
      purposes: ['Bữa ăn gia đình', 'Sinh nhật / Tiệc', 'Tiếp khách / Đối tác'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 430 },
      googleRating: { rating: 4.7, userRatingsTotal: 3800 },
    },
    branch: {
      name: 'Manwah - Tầng 2 Indochina Riverside',
      address: {
        street: '74 Bạch Đằng',
        ward: 'Hải Châu 1',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2248, 16.0715],
      },
      phone: '0236 7300 520',
      amenities: ['WIFI', 'AIR_CONDITIONING', 'RIVER_VIEW', 'PARKING'],
    },
    products: [
      {
        name: 'Buffet Lẩu Đài Loan Thượng Hạng',
        category: 'Buffet Lẩu',
        description: 'Thỏa thích hơn 68 món nhúng bò Wagyu, hải sản, nấm quý và quầy tráng miệng.',
        price: 389000,
        imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Nguyễn Búp (Chủ Búp Seafood)',
      email: 'owner.bupseafood@fconnect.vn',
      password: 'merchant123',
      phone: '0905123777',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Búp Seafood Restaurant',
      slug: 'bup-seafood-restaurant',
      description: 'Hải sản nướng than hoa và xào lăn đậm vị phố biển Đà Nẵng, nguồn hàng tươi sống giá bình dân được cư dân bản địa cực kỳ ưa chuộng.',
      categories: ['RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 90000, max: 320000 },
      vibes: ['Ngoài trời / Sân vườn', 'Ấm cúng / Gia đình'],
      purposes: ['Tụ tập bạn bè', 'Bữa ăn gia đình'],
      status: 'APPROVED',
      ratingSummary: { average: 4.7, totalReviews: 260 },
      googleRating: { rating: 4.5, userRatingsTotal: 2100 },
    },
    branch: {
      name: 'Búp Seafood - 145 Tuệ Tĩnh',
      address: {
        street: '145 Tuệ Tĩnh',
        ward: 'Bình Thuận',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2155, 16.0495],
      },
      phone: '0905 123 777',
      amenities: ['WIFI', 'PARKING', 'OUTDOOR_SEATING'],
    },
    products: [
      {
        name: 'Sò Điệp Nướng Mỡ Hành Đậu Phộng',
        category: 'Hải Sản Nướng',
        description: 'Sò điệp béo ngọt ngập mỡ hành thơm nức bùi bùi.',
        price: 95000,
        imageUrl: 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Võ Bé Anh (Chủ Bé Anh Galaxy)',
      email: 'owner.beanhgalaxy@fconnect.vn',
      password: 'merchant123',
      phone: '0905555123',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Hải Sản Bé Anh Galaxy',
      slug: 'hai-san-be-anh-galaxy',
      description: 'Tổ hợp nhà hàng hải sản cao cấp bậc nhất cung đường biển Sơn Trà với không gian tiệc sang trọng và hải sản tươi sống bắt tại hồ.',
      categories: ['RESTAURANT', 'BUFFET'],
      logoUrl: 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 150000, max: 550000 },
      vibes: ['Hiện đại / Sang trọng', 'Rộng rãi / Nhóm đông'],
      purposes: ['Tiếp khách / Đối tác', 'Bữa ăn gia đình', 'Sinh nhật / Tiệc'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 390 },
      googleRating: { rating: 4.6, userRatingsTotal: 3400 },
    },
    branch: {
      name: 'Bé Anh Galaxy - Lô B14-01 Hồ Nghinh',
      address: {
        street: 'Lô B14-01 Hồ Nghinh',
        ward: 'Phước Mỹ',
        district: 'Sơn Trà',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2422, 16.069],
      },
      phone: '0905 555 123',
      amenities: ['WIFI', 'AIR_CONDITIONING', 'PARKING', 'PRIVATE_ROOM'],
    },
    products: [
      {
        name: 'Tu Hài Nướng Mỡ Hành Thơm Lừng',
        category: 'Đặc Sản',
        description: 'Tu hài thịt giòn ngọt sần sật nướng mỡ hành nóng hổi.',
        price: 180000,
        imageUrl: 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Lê Tiến Hưng (Chủ Bánh Cuốn Tiến Hưng)',
      email: 'owner.tienhung@fconnect.vn',
      password: 'merchant123',
      phone: '02363826287',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Bánh Cuốn Nóng Tiến Hưng',
      slug: 'banh-cuon-nong-tien-hung-tran-phu',
      description: 'Thương hiệu bánh cuốn gia truyền lâu đời nhất Đà Nẵng, bánh tráng tay mỏng mướt nhân thịt nấm mộc nhĩ ăn kèm chả quế thơm lừng.',
      categories: ['RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 30000, max: 60000 },
      vibes: ['Cổ điển / Vintage', 'Ấm cúng / Gia đình'],
      purposes: ['Ăn một mình / Chill', 'Bữa ăn gia đình'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 320 },
      googleRating: { rating: 4.6, userRatingsTotal: 3100 },
    },
    branch: {
      name: 'Tiến Hưng - 190 Trần Phú',
      address: {
        street: '190 Trần Phú',
        ward: 'Phước Ninh',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2228, 16.0632],
      },
      phone: '0236 3826 287',
      amenities: ['WIFI', 'PARKING'],
    },
    products: [
      {
        name: 'Đĩa Bánh Cuốn Nóng Kèm Chả Quế',
        category: 'Bánh Cuốn',
        description: 'Bánh tráng mỏng nóng hổi rắc hành phi giòn tan chấm nước mắm chua ngọt ấm bụng.',
        price: 40000,
        imageUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Bác Hải (Chủ Cà Phê Trứng Bác Hải)',
      email: 'owner.bachai@fconnect.vn',
      password: 'merchant123',
      phone: '0905999123',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Cà Phê Trứng Bác Hải',
      slug: 'ca-phe-trung-bac-hai-le-dinh-duong',
      description: 'Lớp kem trứng đánh bông vàng sánh béo ngậy không một chút mùi tanh, hòa quyện dưới đáy là cà phê phin đậm đà ấm nóng.',
      categories: ['CAFE'],
      logoUrl: 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 25000, max: 45000 },
      vibes: ['Cổ điển / Vintage', 'Ấm cúng / Gia đình'],
      purposes: ['Ăn một mình / Chill', 'Gặp gỡ bạn bè'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 240 },
      googleRating: { rating: 4.7, userRatingsTotal: 2500 },
    },
    branch: {
      name: 'Bác Hải - 128 Lê Đình Dương',
      address: {
        street: '128 Lê Đình Dương',
        ward: 'Phước Ninh',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2182, 16.0612],
      },
      phone: '0905 999 123',
      amenities: ['WIFI', 'OUTDOOR_SEATING'],
    },
    products: [
      {
        name: 'Tách Cà Phê Trứng Hà Nội Đặc Biệt',
        category: 'Cà Phê Trứng',
        description: 'Kem trứng đánh bông mịn như mây kết hợp cà phê nguyên chất sánh đặc.',
        price: 35000,
        imageUrl: 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Bà Đệ (Chủ Tré Bà Đệ)',
      email: 'owner.bade@fconnect.vn',
      password: 'merchant123',
      phone: '02363822270',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Đặc Sản Nem Tré Bà Đệ',
      slug: 'dac-san-nem-tre-ba-de-hai-phong',
      description: 'Món quà trứ danh Đà Nẵng với tré gói rơm truyền thống từ thịt tai mũi heo giòn sần sật ướp riềng tỏi thính thơm nức mũi.',
      categories: ['FAST_FOOD', 'RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 40000, max: 150000 },
      vibes: ['Cổ điển / Vintage'],
      purposes: ['Ăn một mình / Chill', 'Tụ tập bạn bè'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 450 },
      googleRating: { rating: 4.6, userRatingsTotal: 4600 },
    },
    branch: {
      name: 'Tré Bà Đệ - 81 Hải Phòng',
      address: {
        street: '81 Hải Phòng',
        ward: 'Thạch Thang',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2188, 16.0735],
      },
      phone: '0236 3822 270',
      amenities: ['PARKING'],
    },
    products: [
      {
        name: 'Tré Gói Rơm Truyền Thống Đặc Biệt',
        category: 'Đặc Sản Quà Biếu',
        description: 'Tré giòn dai thơm mùi riềng ớt tỏi ăn kèm tương ớt rim cay ngọt.',
        price: 95000,
        imageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Alexandre Waterfront (Chủ Waterfront Bar)',
      email: 'owner.waterfront@fconnect.vn',
      password: 'merchant123',
      phone: '02363843373',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Waterfront Danang Restaurant & Bar',
      slug: 'waterfront-danang-restaurant-bar',
      description: 'Nhà hàng & Lounge Bar cao cấp mặt tiền đường Bạch Đằng, ngắm trọn vẹn cảnh đêm sông Hàn lung linh cùng ẩm thực Âu - Á và Cocktail thượng hạng.',
      categories: ['BAR', 'RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 120000, max: 600000 },
      vibes: ['Lãng mạn / Hẹn hò', 'Hiện đại / Sang trọng', 'Rooftop / View trên cao'],
      purposes: ['Hẹn hò cặp đôi', 'Tiếp khách / Đối tác'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 510 },
      googleRating: { rating: 4.7, userRatingsTotal: 3900 },
    },
    branch: {
      name: 'Waterfront Danang - 150 Bạch Đằng',
      address: {
        street: '150 Bạch Đằng',
        ward: 'Hải Châu 1',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2245, 16.0655],
      },
      phone: '0236 3843 373',
      amenities: ['WIFI', 'AIR_CONDITIONING', 'RIVER_VIEW', 'OUTDOOR_SEATING'],
    },
    products: [
      {
        name: 'Bò Bít Tết Thăn Ngoại Úc Sốt Rượu Vang',
        category: 'Món Âu',
        description: 'Thăn bò mềm mọng sốt vang đỏ thơm nức ăn kèm khoai tây nghiền trufe.',
        price: 345000,
        imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Nguyễn Kichi (Chủ Kichi-Kichi Lotte)',
      email: 'owner.kichilotte@fconnect.vn',
      password: 'merchant123',
      phone: '02367300518',
      role: 'MERCHANT',
      status: 'ACTIVE',
    },
    business: {
      name: 'Kichi-Kichi Lẩu Băng Chuyền - Lotte Mart',
      slug: 'kichi-kichi-lau-bang-chuyen-lotte',
      description: 'Vua lẩu băng chuyền với hơn 100 món nhúng chuyển động không ngừng: ba chỉ bò Mỹ, cá hồi Na Uy, tôm tươi, nấm linh chi và nước lẩu Tomyum đậm đà.',
      categories: ['BUFFET', 'RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 239000, max: 319000 },
      vibes: ['Hiện đại / Sang trọng', 'Sôi động / Nhộn nhịp', 'Rộng rãi / Nhóm đông'],
      purposes: ['Bữa ăn gia đình', 'Tụ tập bạn bè'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 410 },
      googleRating: { rating: 4.6, userRatingsTotal: 3600 },
    },
    branch: {
      name: 'Kichi-Kichi - Tầng 2 Lotte Mart Đà Nẵng',
      address: {
        street: '06 Nại Nam',
        ward: 'Hòa Cường Bắc',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2295, 16.0355],
      },
      phone: '0236 7300 518',
      amenities: ['WIFI', 'AIR_CONDITIONING', 'PARKING'],
    },
    products: [
      {
        name: 'Buffet Lẩu Băng Chuyền Tiêu Chuẩn',
        category: 'Buffet Lẩu',
        description: 'Thưởng thức không giới hạn bò Mỹ, hải sản và rau nấm tươi trên dải băng chuyền.',
        price: 269000,
        imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
];

/**
 * Runner function to execute the seed
 */
export async function seedDanangRestaurants() {
  try {
    const mongoUri = process.env.MONGODB_URI;
    if (!mongoUri) {
      throw new Error('MONGODB_URI is not defined in environment variables');
    }

    console.log('Connecting to MongoDB Atlas...');
    await mongoose.connect(mongoUri);
    console.log('✅ Connected to MongoDB Atlas successfully.');

    let insertedCount = 0;
    let updatedCount = 0;

    for (const item of danangRestaurantsData) {
      const { merchant, business, branch, products } = item;

      // 1. Create or Find Merchant User
      let user = await User.findOne({ email: merchant.email });
      if (!user) {
        user = await User.create({
          fullName: merchant.fullName,
          email: merchant.email,
          password: merchant.password,
          phone: merchant.phone,
          role: merchant.role,
          status: merchant.status,
          avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
        });
        console.log(`👤 Created Merchant User: ${merchant.email}`);
      } else {
        // Update role if needed
        user.role = 'MERCHANT';
        user.fullName = merchant.fullName;
        await user.save();
      }

      // 2. Create or Update Business
      let biz = await Business.findOne({ slug: business.slug });
      if (!biz) {
        biz = await Business.create({
          ...business,
          ownerId: user._id,
        });
        insertedCount++;
        console.log(`🏪 Created Business: ${business.name} (Slug: ${business.slug})`);
      } else {
        // Update info while keeping owner
        Object.assign(biz, business);
        biz.ownerId = user._id;
        await biz.save();
        updatedCount++;
        console.log(`🔄 Updated Business: ${business.name}`);
      }

      // 3. Create or Update Branch
      let br = await Branch.findOne({ businessId: biz._id });
      if (!br) {
        br = await Branch.create({
          businessId: biz._id,
          name: branch.name,
          address: branch.address,
          location: branch.location,
          phone: branch.phone,
          amenities: branch.amenities,
          openingHours: [
            { day: 0, open: '07:00', close: '22:30' },
            { day: 1, open: '07:00', close: '22:30' },
            { day: 2, open: '07:00', close: '22:30' },
            { day: 3, open: '07:00', close: '22:30' },
            { day: 4, open: '07:00', close: '22:30' },
            { day: 5, open: '07:00', close: '23:00' },
            { day: 6, open: '07:00', close: '23:00' },
          ],
          status: 'ACTIVE',
        });
        console.log(`📍 Created Branch: ${branch.name}`);
      } else {
        br.name = branch.name;
        br.address = branch.address;
        br.location = branch.location;
        br.phone = branch.phone;
        br.amenities = branch.amenities;
        await br.save();
      }

      // 4. Create Menu & Products
      let menu = await Menu.findOne({ businessId: biz._id });
      if (!menu) {
        menu = await Menu.create({
          businessId: biz._id,
          branchId: br._id,
          name: `Menu Thực Đơn - ${biz.name}`,
          description: `Thực đơn chính thức của ${biz.name}`,
          status: 'ACTIVE',
        });
      }

      if (Array.isArray(products) && products.length > 0) {
        for (const prod of products) {
          const existingProd = await Product.findOne({ menuId: menu._id, name: prod.name });
          if (!existingProd) {
            await Product.create({
              menuId: menu._id,
              branchId: br._id,
              name: prod.name,
              category: prod.category || 'Món Chính',
              description: prod.description || '',
              price: prod.price,
              imageUrl: prod.imageUrl || 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=80',
              status: 'AVAILABLE',
            });
          }
        }
      }
    }

    console.log(`\n🎉 Seed hoàn tất: Chèn mới ${insertedCount} quán, Cập nhật ${updatedCount} quán.`);
    console.log(`Tất cả 20 quán đều gắn liền với 20 tài khoản Merchant riêng biệt.`);
  } catch (error) {
    console.error('❌ Lỗi khi seed dữ liệu:', error);
  } finally {
    await mongoose.disconnect();
    console.log('🔌 Đã đóng kết nối MongoDB.');
  }
}

// If run directly from CLI
if (process.argv[1] && process.argv[1].endsWith('seedDanangRestaurants.js')) {
  seedDanangRestaurants().then(() => process.exit(0));
}

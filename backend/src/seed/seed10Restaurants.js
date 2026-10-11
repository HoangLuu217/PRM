import mongoose from 'mongoose';
import dotenv from 'dotenv';
import dns from 'dns';
import {
  User,
  Business,
  Branch,
  Menu,
  Product,
  Table,
  Booking,
  Order,
  Review,
  Favorite,
  Staff,
} from '../models/index.js';

dotenv.config();

// Fix Node.js DNS SRV resolution issue on Windows for MongoDB Atlas
try {
  dns.setDefaultResultOrder('ipv4first');
  dns.setServers(['8.8.8.8', '1.1.1.1']);
} catch (e) {
  // ignore
}

export const tenRestaurants = [
  {
    merchant: {
      fullName: 'Võ Văn Mặn (Chủ Quán Bé Mặn)',
      email: 'owner1@fconnect.vn',
      password: 'merchant123',
      phone: '0905207848',
      role: 'MERCHANT',
      status: 'ACTIVE',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
    },
    business: {
      name: 'Hải Sản Bé Mặn (Mỹ Khê)',
      slug: 'hai-san-be-man-my-khe',
      description: 'Hải sản tươi sống bắt tại bể uy tín bậc nhất bờ biển Mỹ Khê Đà Nẵng. Không gian rộng rãi, thoáng đãng đón gió biển.',
      categories: ['RESTAURANT', 'BUFFET'],
      logoUrl: 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 150000, max: 600000 },
      vibes: ['Ngoài trời / Sân vườn', 'Rộng rãi / Nhóm đông', 'Gần biển / View đẹp'],
      purposes: ['Bữa ăn gia đình', 'Tụ tập bạn bè', 'Tiếp khách / Đối tác'],
      features: ['Hải sản tươi sống', 'Chỗ để xe ô tô', 'Phòng riêng VIP', 'Thanh toán thẻ'],
      spaceTags: ['Ven biển', 'Thoáng mát', 'Nhộn nhịp'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 320 },
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
      amenities: ['WIFI', 'PARKING', 'OUTDOOR_SEATING', 'SEA_VIEW', 'AIR_CONDITIONER'],
    },
    products: [
      {
        name: 'Tôm Hùm Bông Nướng Phô Mai',
        category: 'Hải Sản Cao Cấp',
        description: 'Tôm hùm bông tươi sống sốt phô mai kéo sợi thơm ngậy.',
        price: 450000,
        imageUrl: 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Cua Huỳnh Đế Hấp Sả Gừng',
        category: 'Đặc Sản Biển',
        description: 'Cua thịt chắc ngọt béo gạch trứ danh miền Trung.',
        price: 380000,
        imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Mực Trứng Hấp Hành Gừng',
        category: 'Món Nhậu Biển',
        description: 'Mực trứng tươi rói giòn sần sật chấm mắm gừng cay nồng.',
        price: 180000,
        imageUrl: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Dương Thành Long (Chủ Quán Chú Long)',
      email: 'owner2@fconnect.vn',
      password: 'merchant123',
      phone: '0905112233',
      role: 'MERCHANT',
      status: 'ACTIVE',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
    },
    business: {
      name: 'Cà Phê Muối Chú Long (Nguyễn Văn Linh)',
      slug: 'ca-phe-muoi-chu-long-nguyen-van-linh',
      description: 'Chuỗi cà phê muối nổi tiếng với lớp kem béo ngậy đậm đà, hạt cà phê Đắk Lắk nguyên chất rang mộc.',
      categories: ['CAFE'],
      logoUrl: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 25000, max: 55000 },
      vibes: ['Yên tĩnh / Làm việc', 'Chill / Thư giãn', 'Check-in sống ảo'],
      purposes: ['Học tập & Làm việc', 'Hẹn hò cặp đôi', 'Gặp gỡ bạn bè'],
      features: ['Wifi tốc độ cao', 'Nhiều ổ cắm sạc', 'Điều hòa 24/7', 'Giao hàng tận nơi'],
      spaceTags: ['Hiện đại', 'Yên tĩnh', 'Máy lạnh'],
      status: 'APPROVED',
      ratingSummary: { average: 4.7, totalReviews: 245 },
      googleRating: { rating: 4.8, userRatingsTotal: 1890 },
    },
    branch: {
      name: 'Cà Phê Muối Chú Long - 128 Nguyễn Văn Linh',
      address: {
        street: '128 Nguyễn Văn Linh',
        ward: 'Nam Dương',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2165, 16.0610],
      },
      phone: '0905 112 233',
      amenities: ['WIFI', 'AIR_CONDITIONER', 'PARKING', 'POWER_OUTLETS'],
    },
    products: [
      {
        name: 'Cà Phê Muối Đặc Biệt',
        category: 'Signature Coffee',
        description: 'Vị cà phê đậm đà hòa quyện cùng lớp kem muối béo mặn thơm ngậy.',
        price: 32000,
        imageUrl: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Bạc Xỉu Sữa Tươi Kem Mặn',
        category: 'Signature Coffee',
        description: 'Vị ngọt nhẹ của sữa tươi kết hợp kem béo mặn tinh tế.',
        price: 35000,
        imageUrl: 'https://images.unsplash.com/photo-1517256064527-09c73fc73e38?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Trà Sữa Oolong Nướng',
        category: 'Trà Đặc Biệt',
        description: 'Trà ô long ủ lạnh thơm đậm vị kết hợp trân châu hoàng kim dẻo mềm.',
        price: 38000,
        imageUrl: 'https://images.unsplash.com/photo-1558857563-b37fcbfca609?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Yosuke Masuko (Chủ Quán Pizza 4P\'s)',
      email: 'owner3@fconnect.vn',
      password: 'merchant123',
      phone: '02836220500',
      role: 'MERCHANT',
      status: 'ACTIVE',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
    },
    business: {
      name: 'Pizza 4P\'s Hoàng Văn Thụ (Indochine)',
      slug: 'pizza-4ps-hoang-van-thu-da-nang',
      description: 'Nhà hàng phong cách Ý kết hợp Nhật Bản nổi tiếng với phô mai Burrata tự làm tươi mỗi ngày và pizza nướng củi thơm lừng.',
      categories: ['RESTAURANT', 'FAST_FOOD'],
      logoUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 200000, max: 700000 },
      vibes: ['Sang trọng / Lãng mạn', 'Ấm cúng / Gia đình', 'Không gian xanh'],
      purposes: ['Hẹn hò cặp đôi', 'Bữa ăn gia đình', 'Kỷ niệm sinh nhật'],
      features: ['Lò nướng củi', 'Phô mai tự sản xuất', 'Menu chay cao cấp', 'Rượu vang quốc tế'],
      spaceTags: ['Sang trọng', 'Lãng mạn', 'Máy lạnh'],
      status: 'APPROVED',
      ratingSummary: { average: 4.9, totalReviews: 540 },
      googleRating: { rating: 4.9, userRatingsTotal: 4120 },
    },
    branch: {
      name: 'Pizza 4P\'s - 08 Hoàng Văn Thụ',
      address: {
        street: '08 Hoàng Văn Thụ',
        ward: 'Phước Ninh',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2230, 16.0645],
      },
      phone: '028 3622 0500',
      amenities: ['WIFI', 'AIR_CONDITIONER', 'PARKING', 'CREDIT_CARD', 'DISABLED_ACCESS'],
    },
    products: [
      {
        name: 'Pizza 4 Loại Phô Mai (4 Cheese Pizza)',
        category: 'Pizza Nướng Củi',
        description: 'Kết hợp 4 loại phô mai thủ công hảo hạng rưới mật ong nguyên chất.',
        price: 240000,
        imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Pizza Burrata Thịt Nguội Parma Ham',
        category: 'Pizza Nướng Củi',
        description: 'Phô mai Burrata tươi béo mềm nguyên quả kết hợp thịt nguội Parma Ham trứ danh.',
        price: 295000,
        imageUrl: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Mì Ý Cua Sốt Kem Cà Chua',
        category: 'Mì Ý & Pasta',
        description: 'Thịt cua xé thơm ngọt sốt kem cà chua béo nhẹ phong cách Ý - Nhật.',
        price: 235000,
        imageUrl: 'https://images.unsplash.com/photo-1621996346565-e3d5d6281292?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Nguyễn Thị Mua (Chủ Quán Bà Mua)',
      email: 'owner4@fconnect.vn',
      password: 'merchant123',
      phone: '0905445566',
      role: 'MERCHANT',
      status: 'ACTIVE',
      avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=400&q=80',
    },
    business: {
      name: 'Mì Quảng Bà Mua (Trần Bình Trọng)',
      slug: 'mi-quang-ba-mua-tran-binh-trong',
      description: 'Quán mì Quảng truyền thống xứ Quảng nức tiếng hơn 30 năm, nước dùng đậm đà ăn kèm bánh tráng mè nướng giòn rụm.',
      categories: ['RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 35000, max: 70000 },
      vibes: ['Ấm cúng / Gia đình', 'Bình dân / Quen thuộc', 'Truyền thống'],
      purposes: ['Ăn sáng nhanh', 'Bữa ăn gia đình', 'Thưởng thức đặc sản'],
      features: ['Rau sống sạch tươi', 'Bánh tráng nướng giòn', 'Trà đá miễn phí', 'Mang về'],
      spaceTags: ['Bình dân', 'Thoáng mát', 'Truyền thống'],
      status: 'APPROVED',
      ratingSummary: { average: 4.6, totalReviews: 410 },
      googleRating: { rating: 4.5, userRatingsTotal: 3200 },
    },
    branch: {
      name: 'Mì Quảng Bà Mua - 19 Trần Bình Trọng',
      address: {
        street: '19 Trần Bình Trọng',
        ward: 'Hải Châu 1',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2188, 16.0668],
      },
      phone: '0905 445 566',
      amenities: ['WIFI', 'PARKING', 'AIR_CONDITIONER'],
    },
    products: [
      {
        name: 'Mì Quảng Tôm Thịt Trứng',
        category: 'Mì Quảng Truyền Thống',
        description: 'Tôm đất đậm vị, thịt ba chỉ rim kĩ, trứng cút cùng bánh tráng mè giòn tan.',
        price: 45000,
        imageUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Mì Quảng Gà Ta Rút Xương',
        category: 'Mì Quảng Truyền Thống',
        description: 'Gà ta thả vườn thịt dai ngọt, nước dùng nấu củ nén thơm lừng.',
        price: 50000,
        imageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Mì Quảng Ếch Om Sả Ớt',
        category: 'Đặc Sản Xứ Quảng',
        description: 'Thịt ếch đồng om vàng óng thơm sả ớt cay nồng đậm vị miền Trung.',
        price: 55000,
        imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Lê Hoàng Nam (Chủ Quán Bếp Cuốn)',
      email: 'owner5@fconnect.vn',
      password: 'merchant123',
      phone: '0905778899',
      role: 'MERCHANT',
      status: 'ACTIVE',
      avatarUrl: 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=400&q=80',
    },
    business: {
      name: 'Bếp Cuốn Đà Nẵng (Hải Phòng)',
      slug: 'bep-cuon-da-nang-hai-phong',
      description: 'Không gian văn hóa ẩm thực miền Trung tinh tế với bánh tráng cuốn thịt heo Đại Lộc, ram bắp, bánh xèo giòn rụm.',
      categories: ['RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 80000, max: 250000 },
      vibes: ['Ấm cúng / Gia đình', 'Không gian xanh', 'Sang trọng / Lãng mạn'],
      purposes: ['Tiếp khách / Đối tác', 'Bữa ăn gia đình', 'Du lịch trải nghiệm'],
      features: ['Nước chấm gia truyền', 'Rau rừng Tây Giang', 'Máy lạnh toàn bộ', 'Phòng tiệc'],
      spaceTags: ['Ấm cúng', 'Mộc mạc', 'Lịch sự'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 290 },
      googleRating: { rating: 4.7, userRatingsTotal: 2150 },
    },
    branch: {
      name: 'Bếp Cuốn Đà Nẵng - 54 Hải Phòng',
      address: {
        street: '54 Hải Phòng',
        ward: 'Thạch Thang',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2170, 16.0742],
      },
      phone: '0905 778 899',
      amenities: ['WIFI', 'AIR_CONDITIONER', 'PARKING', 'CREDIT_CARD'],
    },
    products: [
      {
        name: 'Bánh Tráng Cuốn Thịt Heo Hai Đầu Da',
        category: 'Món Cuốn Đặc Sản',
        description: 'Thịt heo cỏ luộc khéo hai đầu da, chấm mắm nêm cá cơm nguyên chất thơm phức.',
        price: 125000,
        imageUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Bánh Xèo Tôm Nhảy Giòn Rụm',
        category: 'Món Cuốn Đặc Sản',
        description: 'Bánh xèo vàng ươm giòn tan với tôm đất tươi nhảy tanh tách.',
        price: 85000,
        imageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Ram Bắp Quảng Ngãi Giòn Tan',
        category: 'Khai Vị',
        description: 'Bắp non ngọt bùi gói bánh tráng mỏng chiên phồng chấm tương ớt rim.',
        price: 65000,
        imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Kim Dong Wook (Chủ Quán K-Pub)',
      email: 'owner6@fconnect.vn',
      password: 'merchant123',
      phone: '02367300500',
      role: 'MERCHANT',
      status: 'ACTIVE',
      avatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=400&q=80',
    },
    business: {
      name: 'K-Pub - Korean Grill Buffet (Vincom)',
      slug: 'k-pub-korean-grill-buffet-vincom',
      description: 'Quán nướng đường phố Hàn Quốc chuẩn phong cách Seoul với thịt nướng tẩm sốt đậm đà, buffet viền trứng phô mai không giới hạn.',
      categories: ['BBQ', 'BUFFET'],
      logoUrl: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 199000, max: 389000 },
      vibes: ['Sôi động / Nhộn nhịp', 'Rộng rãi / Nhóm đông', 'Hiện đại'],
      purposes: ['Tụ tập bạn bè', 'Liên hoan công ty', 'Bữa ăn gia đình'],
      features: ['Hút khói âm bàn', 'Buffet trứng phô mai', 'Panchan không giới hạn', 'Bia tươi ướp lạnh'],
      spaceTags: ['Trẻ trung', 'Sôi động', 'Hiện đại'],
      status: 'APPROVED',
      ratingSummary: { average: 4.7, totalReviews: 380 },
      googleRating: { rating: 4.6, userRatingsTotal: 2900 },
    },
    branch: {
      name: 'K-Pub - Tầng 4 TTTM Vincom Ngô Quyền',
      address: {
        street: '910A Ngô Quyền',
        ward: 'An Hải Bắc',
        district: 'Sơn Trà',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2325, 16.0718],
      },
      phone: '0236 7300 500',
      amenities: ['WIFI', 'AIR_CONDITIONER', 'PARKING', 'CREDIT_CARD', 'ELEVATOR'],
    },
    products: [
      {
        name: 'Buffet Nướng Thùng Phuy Đặc Biệt',
        category: 'Buffet Nướng',
        description: 'Hơn 30 món nướng thịt bò Mỹ, ba chỉ heo cuộn nấm và hải sản sốt K-Pub.',
        price: 299000,
        imageUrl: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Dẻ Sườn Bò Mỹ Sốt Bulgogi',
        category: 'Thịt Nướng Alacarte',
        description: 'Thịt bò vân mỡ mềm tan ướp sốt hoa quả truyền thống Hàn Quốc.',
        price: 189000,
        imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Canh Kim Chi Thịt Heo Nồi Đá',
        category: 'Món Ăn Kèm',
        description: 'Canh kim chi hầm nhừ chua cay nóng hổi kèm đậu hũ non.',
        price: 79000,
        imageUrl: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Trần Trúc Linh (Chủ Quán Gong Cha)',
      email: 'owner7@fconnect.vn',
      password: 'merchant123',
      phone: '0905889900',
      role: 'MERCHANT',
      status: 'ACTIVE',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
    },
    business: {
      name: 'Trà Sữa Gong Cha (Nguyễn Văn Thoại)',
      slug: 'tra-sua-gong-cha-nguyen-van-thoai',
      description: 'Thương hiệu trà sữa hoàng gia Đài Loan nổi tiếng với lớp Milk Foam béo ngậy thần thánh và lá trà ủ tươi nguyên vị.',
      categories: ['MILK_TEA', 'DESSERT'],
      logoUrl: 'https://images.unsplash.com/photo-1558857563-b37fcbfca609?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 45000, max: 75000 },
      vibes: ['Chill / Thư giãn', 'Check-in sống ảo', 'Yên tĩnh / Làm việc'],
      purposes: ['Hẹn hò cặp đôi', 'Gặp gỡ bạn bè', 'Học tập & Làm việc'],
      features: ['Lớp Milk Foam độc quyền', 'Trân châu trắng giòn', 'Trà tươi 4 tiếng', 'Máy lạnh mát'],
      spaceTags: ['Hiện đại', 'Mát mẻ', 'Thư giãn'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 430 },
      googleRating: { rating: 4.7, userRatingsTotal: 3100 },
    },
    branch: {
      name: 'Gong Cha - 225 Nguyễn Văn Thoại',
      address: {
        street: '225 Nguyễn Văn Thoại',
        ward: 'An Hải Đông',
        district: 'Sơn Trà',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2410, 16.0538],
      },
      phone: '0905 889 900',
      amenities: ['WIFI', 'AIR_CONDITIONER', 'PARKING', 'POWER_OUTLETS'],
    },
    products: [
      {
        name: 'Trà Alisan Milk Foam Trân Châu Trắng',
        category: 'Signature Milk Foam',
        description: 'Trà Alisan cao sơn thơm thanh kết hợp lớp kem mặn và trân châu giòn sần sật.',
        price: 59000,
        imageUrl: 'https://images.unsplash.com/photo-1558857563-b37fcbfca609?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Trà Sữa Oolong Trân Châu Đen',
        category: 'Trà Sữa Truyền Thống',
        description: 'Vị trà oolong đậm vị hòa cùng sữa thơm mịn và trân châu dẻo ngọt.',
        price: 55000,
        imageUrl: 'https://images.unsplash.com/photo-1517256064527-09c73fc73e38?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Trà Xoài Đá Xay Sương Sáo',
        category: 'Trà Trái Cây & Đá Xay',
        description: 'Xoài cát tươi xay nhuyễn ngọt mát giải nhiệt mùa hè cực đã.',
        price: 65000,
        imageUrl: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Phan Thị Ngọc Hân (Chủ Quán BonPas)',
      email: 'owner8@fconnect.vn',
      password: 'merchant123',
      phone: '0905667788',
      role: 'MERCHANT',
      status: 'ACTIVE',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
    },
    business: {
      name: 'Tiệm Bánh BonPas Bakery & Coffee (Lê Duẩn)',
      slug: 'tiem-banh-bonpas-bakery-coffee-le-duan',
      description: 'Thiên đường bánh mì & bánh ngọt phong cách Âu nướng tươi trong ngày, không gian cà phê sang chảnh bậc nhất trục đường thời trang Lê Duẩn.',
      categories: ['BAKERY', 'CAFE', 'DESSERT'],
      logoUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 20000, max: 85000 },
      vibes: ['Sang trọng / Lãng mạn', 'Check-in sống ảo', 'Chill / Thư giãn'],
      purposes: ['Hẹn hò cặp đôi', 'Gặp gỡ bạn bè', 'Mua sắm quà biếu'],
      features: ['Bánh nướng mới mỗi ngày', 'Khu trưng bày bánh Âu', 'Cà phê pha máy', 'Máy lạnh êm dịu'],
      spaceTags: ['Sang trọng', 'Thanh lịch', 'Check-in'],
      status: 'APPROVED',
      ratingSummary: { average: 4.8, totalReviews: 350 },
      googleRating: { rating: 4.7, userRatingsTotal: 2600 },
    },
    branch: {
      name: 'BonPas Bakery - 143 Lê Duẩn',
      address: {
        street: '143 Lê Duẩn',
        ward: 'Hải Châu 2',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2140, 16.0715],
      },
      phone: '0905 667 788',
      amenities: ['WIFI', 'AIR_CONDITIONER', 'PARKING', 'CREDIT_CARD'],
    },
    products: [
      {
        name: 'Bánh Sừng Bò Bơ Pháp Croissant',
        category: 'Bánh Mì & Pastry Âu',
        description: 'Vỏ ngàn lớp giòn tan thơm lừng bơ Pháp cao cấp nướng nóng hổi.',
        price: 32000,
        imageUrl: 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Bánh Tiramisu Phô Mai Mascarpone',
        category: 'Bánh Kem & Dessert',
        description: 'Bánh ngọt Ý chuẩn vị bột cacao đắng mịn và phô mai mềm ngậy tan trong miệng.',
        price: 48000,
        imageUrl: 'https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Trà Đào Cam Sả Tươi Mát',
        category: 'Đồ Uống Giải Khát',
        description: 'Miếng đào giòn mọng nước kết hợp vị thơm dịu của sả và cam tươi.',
        price: 42000,
        imageUrl: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Hoàng Diệu Anh (Chủ Quán Chay Ans)',
      email: 'owner9@fconnect.vn',
      password: 'merchant123',
      phone: '0905556677',
      role: 'MERCHANT',
      status: 'ACTIVE',
      avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=400&q=80',
    },
    business: {
      name: 'Nhà Hàng Chay Ans Vegetarian (Hoàng Diệu)',
      slug: 'nha-hang-chay-ans-vegetarian-hoang-dieu',
      description: 'Nhà hàng chay thực dưỡng thanh tịnh, thực đơn sáng tạo từ nấm và củ quả tự nhiên giúp thanh lọc cơ thể trong không gian an yên.',
      categories: ['RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 50000, max: 180000 },
      vibes: ['Yên tĩnh / Làm việc', 'Ấm cúng / Gia đình', 'Không gian xanh'],
      purposes: ['Thanh lọc cơ thể', 'Bữa ăn gia đình', 'Gặp gỡ bạn bè'],
      features: ['100% thuần chay', 'Không bột ngọt', 'Rau hữu cơ VietGAP', 'Nhạc thiền êm dịu'],
      spaceTags: ['Thanh tịnh', 'Yên tĩnh', 'Mộc mạc'],
      status: 'APPROVED',
      ratingSummary: { average: 4.9, totalReviews: 210 },
      googleRating: { rating: 4.8, userRatingsTotal: 1750 },
    },
    branch: {
      name: 'Ans Vegetarian - 169 Hoàng Diệu',
      address: {
        street: '169 Hoàng Diệu',
        ward: 'Nam Dương',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2180, 16.0585],
      },
      phone: '0905 556 677',
      amenities: ['WIFI', 'AIR_CONDITIONER', 'PARKING', 'VEGETARIAN_ONLY'],
    },
    products: [
      {
        name: 'Lẩu Nấm Thực Dưỡng Hoàng Kim',
        category: 'Lẩu Chay Thanh Đạm',
        description: 'Nước dùng hầm từ củ quả ngọt lịm kèm 8 loại nấm quý và đậu hũ ky non.',
        price: 180000,
        imageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Nấm Đùi Gà Kho Tiêu Nồi Đất',
        category: 'Món Chay Dùng Cơm',
        description: 'Nấm đùi gà chắc thịt rim tiêu đen Phú Quốc cay the đậm đà đưa cơm.',
        price: 65000,
        imageUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Cơm Gạo Lứt Hạt Sen Lá Sen',
        category: 'Cơm Thực Dưỡng',
        description: 'Cơm gạo lứt huyết rồng dẻo thơm hấp bọc lá sen đượm hương vị tự nhiên.',
        price: 60000,
        imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
  {
    merchant: {
      fullName: 'Daniel Long (Chủ Quán 7 Bridges)',
      email: 'owner10@fconnect.vn',
      password: 'merchant123',
      phone: '0905990011',
      role: 'MERCHANT',
      status: 'ACTIVE',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
    },
    business: {
      name: '7 Bridges Brewing Co. (Craft Beer Bạch Đằng)',
      slug: '7-bridges-brewing-craft-beer-bach-dang',
      description: 'Nhà máy bia thủ công đạt nhiều giải thưởng quốc tế với tầng thượng view trọn vẹn Cầu Rồng và dòng sông Hàn rực rỡ ánh đèn về đêm.',
      categories: ['BAR', 'RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 100000, max: 450000 },
      vibes: ['Ngoài trời / Sân vườn', 'Chill / Thư giãn', 'Sôi động / Nhộn nhịp', 'Gần biển / View đẹp'],
      purposes: ['Tụ tập bạn bè', 'Hẹn hò cặp đôi', 'Thư giãn cuối tuần'],
      features: ['Bia thủ công tươi tại vòi', 'Rooftop view Cầu Rồng', 'Đồ nhắm phong cách Âu', 'Âm nhạc sống'],
      spaceTags: ['Rooftop', 'View sông Hàn', 'Sôi động'],
      status: 'APPROVED',
      ratingSummary: { average: 4.9, totalReviews: 480 },
      googleRating: { rating: 4.8, userRatingsTotal: 3800 },
    },
    branch: {
      name: '7 Bridges Taproom - 493 Trần Hưng Đạo',
      address: {
        street: '493 Trần Hưng Đạo',
        ward: 'An Hải Tây',
        district: 'Sơn Trà',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2310, 16.0602],
      },
      phone: '0905 990 011',
      amenities: ['WIFI', 'OUTDOOR_SEATING', 'BAR_COUNTER', 'CREDIT_CARD', 'RIVER_VIEW'],
    },
    products: [
      {
        name: 'Bia Thủ Công Dragon Craft IPA',
        category: 'Craft Beer Tại Vòi',
        description: 'Hương hoa bia nồng nàn vị nhiệt đới bùng nổ, nồng độ cồn 6.5% trứ danh.',
        price: 95000,
        imageUrl: 'https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Xúc Xích Đức Nướng Than Kèm Dưa Cải Chua',
        category: 'Món Nhắm Chuẩn Bia',
        description: 'Xúc xích xông khói thịt chắc béo ngậy ăn kèm dưa cải muối chua kiểu Đức.',
        price: 135000,
        imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
      },
      {
        name: 'Cánh Gà Sốt BBQ Cay Khói',
        category: 'Món Nhắm Chuẩn Bia',
        description: 'Cánh gà chiên giòn áo sốt BBQ thơm mùi gỗ sồi cay the hấp dẫn.',
        price: 110000,
        imageUrl: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=400&q=80',
      },
    ],
  },
];

async function seed10() {
  try {
    const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/fconnect';
    console.log('📡 Đang kết nối tới MongoDB Atlas...');
    await mongoose.connect(uri, {
      serverSelectionTimeoutMS: 20000,
    });
    console.log('✅ Kết nối MongoDB Atlas thành công!');

    // 1. XÓA TẤT CẢ DỮ LIỆU CŨ
    console.log('\n🧹 [BƯỚC 1]: Xóa sạch toàn bộ Business cũ và tài khoản Merchant...');
    await Business.deleteMany({});
    await Branch.deleteMany({});
    await Menu.deleteMany({});
    await Product.deleteMany({});
    await Booking.deleteMany({});
    await Order.deleteMany({});
    await Review.deleteMany({});
    await Favorite.deleteMany({});
    await Staff.deleteMany({});
    await Table.deleteMany({});

    // Xóa các user Merchant cũ
    const delUsers = await User.deleteMany({
      $or: [
        { role: 'MERCHANT' },
        { email: { $regex: /^owner/i } },
        { email: { $regex: /@fconnect\.vn$/i } },
      ],
    });
    console.log(`- Đã dọn dẹp các tài khoản merchant cũ.`);

    // 2. TẠO 10 USER CHỦ QUÁN (MERCHANT) VÀ 10 QUÁN ĂN (BUSINESS)
    console.log('\n🚀 [BƯỚC 2]: Khởi tạo đúng 10 quán ăn và 10 tài khoản chủ quán tương ứng...');

    const generatedOwners = [];

    for (let i = 0; i < tenRestaurants.length; i++) {
      const item = tenRestaurants[i];
      const mData = item.merchant;
      const bData = item.business;
      const branchData = item.branch;
      const productsData = item.products;

      // 2.1 Tạo Merchant User (truyền plain password 'merchant123' để hook pre-save mã hóa đúng 1 lần)
      const user = await User.create({
        fullName: mData.fullName,
        email: mData.email,
        password: mData.password || 'merchant123',
        phone: mData.phone,
        role: 'MERCHANT',
        status: 'ACTIVE',
        avatarUrl: mData.avatarUrl,
        isEmailVerified: true,
        isPhoneVerified: true,
        authProvider: 'LOCAL',
      });

      // 2.2 Tạo Business gắn với ownerId
      const biz = await Business.create({
        ownerId: user._id,
        name: bData.name,
        slug: bData.slug,
        description: bData.description,
        categories: bData.categories,
        logoUrl: bData.logoUrl,
        coverImageUrl: bData.coverImageUrl,
        priceRange: bData.priceRange,
        vibes: bData.vibes,
        purposes: bData.purposes,
        features: bData.features,
        spaceTags: bData.spaceTags,
        status: 'APPROVED',
        ratingSummary: bData.ratingSummary,
        googleRating: bData.googleRating,
      });

      // 2.3 Tạo Branch gắn với businessId
      const branch = await Branch.create({
        businessId: biz._id,
        name: branchData.name,
        address: branchData.address,
        location: branchData.location,
        phone: branchData.phone,
        amenities: branchData.amenities,
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

      // 2.4 Tạo Menu
      const menu = await Menu.create({
        businessId: biz._id,
        branchId: branch._id,
        name: `Thực Đơn - ${biz.name}`,
        description: `Menu chính thức của ${biz.name}`,
        status: 'ACTIVE',
      });

      // 2.5 Tạo Products
      for (const prod of productsData) {
        await Product.create({
          menuId: menu._id,
          branchId: branch._id,
          name: prod.name,
          category: prod.category,
          description: prod.description,
          price: prod.price,
          imageUrl: prod.imageUrl,
          status: 'AVAILABLE',
        });
      }

      generatedOwners.push({
        stt: i + 1,
        restaurantName: biz.name,
        category: biz.categories.join(', '),
        address: `${branchData.address.street}, ${branchData.address.ward}, ${branchData.address.district}`,
        ownerName: user.fullName,
        email: user.email,
        password: 'merchant123',
        phone: user.phone,
      });

      console.log(`[${i + 1}/10] ✅ Đã tạo: "${biz.name}" | Chủ quán: ${user.email}`);
    }

    console.log('\n======================================================');
    console.log('🎉 ĐÃ RESET VÀ TẠO THÀNH CÔNG ĐÚNG 10 QUÁN & 10 CHỦ QUÁN!');
    console.log('======================================================');
    console.table(generatedOwners);
  } catch (error) {
    console.error('❌ Lỗi khi seed 10 quán:', error);
  } finally {
    await mongoose.disconnect();
    console.log('🔌 Đã ngắt kết nối MongoDB.');
  }
}

seed10().then(() => process.exit(0));

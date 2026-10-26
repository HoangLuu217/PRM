import mongoose from 'mongoose';
import dotenv from 'dotenv';
import dns from 'dns';
import path from 'path';
import { fileURLToPath } from 'url';

// Fix Node.js DNS SRV resolution issue on Windows
try {
  dns.setDefaultResultOrder('ipv4first');
  dns.setServers(['8.8.8.8', '1.1.1.1']);
} catch (e) {
  console.warn('DNS config warning:', e.message);
}

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '../../.env') });

import {
  User,
  Business,
  Branch,
  Menu,
  Product,
  Table,
} from '../models/index.js';

const seedOwner = async () => {
  try {
    const uri = process.env.MONGODB_URI;
    if (!uri) {
      console.error('❌ MONGODB_URI not found in backend/.env');
      process.exit(1);
    }

    console.log('📡 Connecting to MongoDB Atlas...');
    await mongoose.connect(uri, { serverSelectionTimeoutMS: 15000 });
    console.log('✅ Connected to MongoDB Atlas!');

    const OWNER_EMAIL = 'chuquan@fconnect.vn';
    const OWNER_PASSWORD = '123456';
    const BUSINESS_SLUG = 'bep-viet-dac-san-da-nang';

    // 1. Dọn dẹp dữ liệu cũ của chủ quán này nếu đã tồn tại
    console.log('🧹 Checking & cleaning existing seed data...');
    const oldUser = await User.findOne({ email: OWNER_EMAIL });
    if (oldUser) {
      const oldBizs = await Business.find({ ownerId: oldUser._id });
      for (const b of oldBizs) {
        const branches = await Branch.find({ businessId: b._id });
        for (const br of branches) {
          await Product.deleteMany({ branchId: br._id });
          await Table.deleteMany({ branchId: br._id });
          await Menu.deleteMany({ branchId: br._id });
        }
        await Branch.deleteMany({ businessId: b._id });
      }
      await Business.deleteMany({ ownerId: oldUser._id });
      await User.deleteOne({ _id: oldUser._id });
      console.log('🗑️ Removed old owner account and associated data.');
    }

    // 2. Tạo tài khoản Chủ Quán (MERCHANT)
    console.log('👤 Creating Merchant / Owner account...');
    const owner = await User.create({
      fullName: 'Nguyễn Văn Hùng (Chủ Quán Bếp Việt)',
      email: OWNER_EMAIL,
      password: OWNER_PASSWORD,
      phone: '0905123456',
      role: 'MERCHANT',
      status: 'ACTIVE',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
      isEmailVerified: true,
      isPhoneVerified: true,
      authProvider: 'LOCAL',
    });
    console.log(`✅ Owner account created: ${owner.email}`);

    // 3. Tạo Nhà hàng (Business)
    console.log('🏪 Creating Restaurant / Business...');
    const business = await Business.create({
      ownerId: owner._id,
      name: 'Bếp Việt - Đặc Sản Đà Nẵng',
      slug: BUSINESS_SLUG,
      description: 'Không gian ấm cúng, đậm chất truyền thống xứ Quảng. Chuyên các món ăn đặc sản Đà Nẵng - Miền Trung tươi ngon chuẩn vị.',
      categories: ['RESTAURANT'],
      logoUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=400&q=80',
      coverImageUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=900&q=80',
      priceRange: { min: 30000, max: 150000 },
      vibes: ['Ấm cúng / Gia đình', 'Không gian truyền thống', 'Thoáng mát'],
      purposes: ['Bữa ăn gia đình', 'Gặp gỡ bạn bè', 'Thưởng thức ẩm thực địa phương'],
      features: ['Đặt bàn trước', 'Wifi miễn phí', 'Thanh toán tiền mặt / Chuyển khoản', 'Chỗ để xe máy'],
      spaceTags: ['Trung tâm thành phố', 'Gần sông Hàn'],
      status: 'APPROVED',
      isBookingEnabled: true,
      ratingSummary: { average: 4.9, totalReviews: 48 },
      googleRating: { rating: 4.8, userRatingsTotal: 310 },
      subscription: {
        plan: 'PRO',
        status: 'ACTIVE',
        features: { maxBookingsPerMonth: 100 },
      },
    });
    console.log(`✅ Business created: ${business.name}`);

    // 4. Tạo Chi nhánh (Branch)
    console.log('📍 Creating Branch...');
    const branch = await Branch.create({
      businessId: business._id,
      name: 'Bếp Việt - 120 Bạch Đằng',
      address: {
        street: '120 Bạch Đằng',
        ward: 'Hải Châu 1',
        district: 'Hải Châu',
        city: 'Đà Nẵng',
      },
      location: {
        type: 'Point',
        coordinates: [108.2238, 16.0712], // [kinh độ, vĩ độ]
      },
      phone: '0905123456',
      amenities: ['Chỗ để xe', 'Máy lạnh', 'Thanh toán thẻ', 'Ghế trẻ em'],
      openingHours: [
        { day: 0, open: '07:00', close: '22:00' },
        { day: 1, open: '07:00', close: '22:00' },
        { day: 2, open: '07:00', close: '22:00' },
        { day: 3, open: '07:00', close: '22:00' },
        { day: 4, open: '07:00', close: '22:00' },
        { day: 5, open: '07:00', close: '22:30' },
        { day: 6, open: '07:00', close: '22:30' },
      ],
      status: 'ACTIVE',
    });
    console.log(`✅ Branch created: ${branch.name}`);

    // 5. Tạo một số bàn ăn (Tables) để khách có thể đặt bàn
    console.log('🪑 Creating Tables...');
    await Table.create([
      { branchId: branch._id, name: 'Bàn A01 (2 người)', capacity: 2, location: 'Tầng 1 - Cửa sổ', status: 'AVAILABLE' },
      { branchId: branch._id, name: 'Bàn A02 (4 người)', capacity: 4, location: 'Tầng 1 - Trung tâm', status: 'AVAILABLE' },
      { branchId: branch._id, name: 'Bàn B01 (6 người)', capacity: 6, location: 'Tầng 2 - View sông Hàn', status: 'AVAILABLE' },
      { branchId: branch._id, name: 'Bàn VIP (8 người)', capacity: 8, location: 'Phòng VIP riêng', status: 'AVAILABLE' },
    ]);
    console.log('✅ Created 4 tables.');

    // 6. Tạo Menu chính
    console.log('📜 Creating Menu...');
    const menu = await Menu.create({
      businessId: business._id,
      branchId: branch._id,
      name: 'Thực Đơn Bếp Việt',
      description: 'Món ngon tinh hoa ẩm thực Đà Nẵng',
      status: 'ACTIVE',
    });
    console.log(`✅ Menu created: ${menu.name}`);

    // 7. Tạo đúng 3 món ăn đặc trưng
    console.log('🍲 Creating 3 Dishes...');
    const dishes = [
      {
        name: 'Mì Quảng Tôm Thịt Đặc Biệt',
        category: 'Món Chính',
        description: 'Sợi mì gạo dẻo mềm, nước dùng đậm đà nấu từ xương, tôm rim tươi ngọt và thịt heo ba chỉ kèm bánh tráng nướng giòn rụm.',
        price: 45000,
        imageUrl: 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?auto=format&fit=crop&w=400&q=80',
        status: 'AVAILABLE',
      },
      {
        name: 'Bánh Xèo Nem Lụi Đà Nẵng',
        category: 'Món Đặc Sản',
        description: 'Vỏ bánh xèo vàng ươm giòn tan cuốn bánh tráng, rau sống tươi ngon cùng nem lụi nướng than hoa thơm lừng và nước lèo đậu phộng béo bùi.',
        price: 65000,
        imageUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=400&q=80',
        status: 'AVAILABLE',
      },
      {
        name: 'Chè Bắp Cốt Dừa Phố Cổ',
        category: 'Tráng Miệng',
        description: 'Bắp nếp ngọt thanh nấu nhuyễn dẻo thơm, chan nước cốt dừa béo ngậy mè rang bùi bùi, tráng miệng thanh mát chuẩn vị xứ Quảng.',
        price: 25000,
        imageUrl: 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?auto=format&fit=crop&w=400&q=80',
        status: 'AVAILABLE',
      },
    ];

    for (const d of dishes) {
      await Product.create({
        menuId: menu._id,
        branchId: branch._id,
        name: d.name,
        category: d.category,
        description: d.description,
        price: d.price,
        imageUrl: d.imageUrl,
        isAvailable: true,
        status: d.status,
      });
      console.log(`   + ${d.name} (${d.price.toLocaleString('vi-VN')} đ)`);
    }

    console.log('\n=========================================');
    console.log('🎉 SEED CHỦ QUÁN THÀNH CÔNG RỰC RỠ!');
    console.log('=========================================');
    console.log('📧 Email đăng nhập:   ' + OWNER_EMAIL);
    console.log('🔑 Mật khẩu:          ' + OWNER_PASSWORD);
    console.log('🏷️ Quyền (Role):      MERCHANT');
    console.log('🏪 Quán ăn:           ' + business.name);
    console.log('📍 Chi nhánh:         ' + branch.name + ' (' + branch.address.street + ')');
    console.log('🍲 3 Món trong Menu:');
    dishes.forEach((d, idx) => {
      console.log(`   ${idx + 1}. ${d.name} - ${d.price.toLocaleString('vi-VN')} đ [${d.category}]`);
    });
    console.log('=========================================\n');

    await mongoose.disconnect();
    console.log('🔌 Disconnected from MongoDB.');
    process.exit(0);
  } catch (error) {
    console.error('❌ Lỗi khi seed dữ liệu:', error);
    process.exit(1);
  }
};

seedOwner();

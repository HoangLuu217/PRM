import mongoose from 'mongoose';
import dotenv from 'dotenv';
import {
  User,
  Staff,
  Business,
  Branch,
  Menu,
  Product,
  Table,
  Booking,
  Cart,
  Order,
  Favorite,
  Review,
  UserInteraction,
  Notification,
  Article,
} from '../models/index.js';
import { mockUsers, mockBusinesses } from './seedData.js';

dotenv.config();

const mockReviewsData = [
  {
    busIndex: 0, // Highlands Coffee
    rating: 5,
    content: 'Phin Sữa Đá đượm vị thơm ngậy chuẩn gu truyền thống. Không gian quán thoáng mát ngay mặt đường Nguyễn Văn Linh!',
    images: ['https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=600&q=80'],
    isVerified: true,
  },
  {
    busIndex: 0,
    rating: 5,
    content: 'Freeze Trà Xanh kèm thạch giòn sần sật béo ngậy, bánh mì que pate thơm nức mũi. Nhân viên phục vụ siêu nhanh!',
    images: ['https://images.unsplash.com/photo-1572490122747-3968b75cc699?auto=format&fit=crop&w=600&q=80'],
    isVerified: true,
  },
  {
    busIndex: 1, // Pizza 4P's
    rating: 5,
    content: 'Pizza 4 Cheese kết hợp mật ong tự nhiên ngon không thốt nên lời! Phô mai Burrata tươi béo ngậy hòa quyện đến hoàn hảo.',
    images: ['https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=600&q=80'],
    isVerified: true,
  },
  {
    busIndex: 1,
    rating: 5,
    content: 'Mì Ý cua sốt kem cà chua cua tươi nguyên con cực kỳ chất lượng. View nhìn ra sông Hàn thơ mộng cho buổi hẹn hò.',
    images: ['https://images.unsplash.com/photo-1621996346565-e3d5d6281273?auto=format&fit=crop&w=600&q=80'],
    isVerified: true,
  },
  {
    busIndex: 2, // K-Pub Korean BBQ
    rating: 5,
    content: 'Buffet nướng Hàn Quốc 30+ món thịt bò Mỹ sốt cay đậm đà, quầy Line Panchan ăn thả ga. Nhân viên nướng thịt tại bàn siêu nhiệt tình!',
    images: ['https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80'],
    isVerified: true,
  },
  {
    busIndex: 2,
    rating: 4,
    content: 'Lẩu kim chi hải sản chua cay thơm nức. Không gian phong cách Pub Hàn Quốc sôi động rất thích hợp tụ tập bạn bè.',
    images: ['https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=600&q=80'],
    isVerified: true,
  },
  {
    busIndex: 3, // Gong Cha
    rating: 5,
    content: 'Trà Sữa Trân Châu Đen Hoàng Gia kèm lớp Milk Foam mặn béo thần thánh! Vị trà Ceylon đậm đà đớp một hớp là mê ngay.',
    images: ['https://images.unsplash.com/photo-1558857563-b371033873b8?auto=format&fit=crop&w=600&q=80'],
    isVerified: true,
  },
  {
    busIndex: 3,
    rating: 5,
    content: 'Quán trà sữa gần biển Nguyễn Văn Thoại mát mẻ, nhân viên pha chế đúng chuẩn 100% đường đá yêu cầu.',
    images: ['https://images.unsplash.com/photo-1558857563-b371033873b8?auto=format&fit=crop&w=600&q=80'],
    isVerified: true,
  },
  {
    busIndex: 4, // Hải Sản Bé Mặn
    rating: 5,
    content: 'Tôm hùm bông nướng bơ tỏi thịt chắc ngọt lừ vớt tại bể! Hải sản tươi sống nổi tiếng nhất biển Mỹ Khê Đà Nẵng.',
    images: ['https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=600&q=80'],
    isVerified: true,
  },
  {
    busIndex: 4,
    rating: 5,
    content: 'Cua huỳnh đế hấp sả gừng chấm muối ớt xanh đặc sản ngon khó cưỡng. Giá cả niêm yết rõ ràng không lo chặt chém!',
    images: ['https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80'],
    isVerified: true,
  },
];

import dns from 'dns';

// Fix Node.js DNS SRV resolution issue on Windows for MongoDB Atlas
try {
  dns.setDefaultResultOrder('ipv4first');
  dns.setServers(['8.8.8.8', '1.1.1.1']);
} catch (e) {
  console.warn('DNS config warning:', e.message);
}

const seedAll = async () => {
  try {
    const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/fconnect';
    await mongoose.connect(uri, { serverSelectionTimeoutMS: 15000 });
    console.log('🌱 Connected to MongoDB for seeding...');

    const SEED_EMAILS = [
      'customer@gmail.com',
      'admin@gmail.com',
      'owner@gmail.com',
      'staff@gmail.com',
    ];

    const SEED_BUSINESS_SLUGS = [
      'highlands-coffee-nguyen-van-linh',
      'pizza-4ps-bach-dang',
      'k-pub-korean-bbq-da-nang',
      'gong-cha-nguyen-van-thoai',
      'hai-san-be-man-da-nang',
    ];

    const SEED_ARTICLE_SLUGS = [
      'top-5-quan-ca-phe-view-bien-da-nang',
      'trai-nghiem-am-thuc-hai-san-be-man',
      'bi-quyet-thuong-thuc-bbq-chuan-vi-han',
      'xu-huong-tra-sua-den-long-2026',
    ];

    // Find seeded IDs
    const seededUsers = await User.find({ email: { $in: SEED_EMAILS } }).select('_id');
    const seededUserIds = seededUsers.map((u) => u._id);

    const seededBusinesses = await Business.find({ slug: { $in: SEED_BUSINESS_SLUGS } }).select('_id');
    const seededBusinessIds = seededBusinesses.map((b) => b._id);

    const seededBranches = await Branch.find({ businessId: { $in: seededBusinessIds } }).select('_id');
    const seededBranchIds = seededBranches.map((b) => b._id);

    const seededMenus = await Menu.find({ businessId: { $in: seededBusinessIds } }).select('_id');
    const seededMenuIds = seededMenus.map((m) => m._id);

    // Clear ONLY existing seed data (preserve manually added data)
    await Promise.all([
      User.deleteMany({ _id: { $in: seededUserIds } }),
      Business.deleteMany({ _id: { $in: seededBusinessIds } }),
      Branch.deleteMany({ _id: { $in: seededBranchIds } }),
      Menu.deleteMany({ _id: { $in: seededMenuIds } }),
      Product.deleteMany({ $or: [{ branchId: { $in: seededBranchIds } }, { menuId: { $in: seededMenuIds } }] }),
      Table.deleteMany({ branchId: { $in: seededBranchIds } }),
      Staff.deleteMany({ $or: [{ userId: { $in: seededUserIds } }, { businessId: { $in: seededBusinessIds } }] }),
      Booking.deleteMany({ $or: [{ bookingCode: 'FCB202609001' }, { userId: { $in: seededUserIds } }, { businessId: { $in: seededBusinessIds } }] }),
      Order.deleteMany({ $or: [{ orderCode: 'FCO202609001' }, { userId: { $in: seededUserIds } }, { businessId: { $in: seededBusinessIds } }] }),
      Favorite.deleteMany({ $or: [{ userId: { $in: seededUserIds } }, { businessId: { $in: seededBusinessIds } }] }),
      Review.deleteMany({ $or: [{ userId: { $in: seededUserIds } }, { businessId: { $in: seededBusinessIds } }] }),
      UserInteraction.deleteMany({ userId: { $in: seededUserIds } }),
      Article.deleteMany({ slug: { $in: SEED_ARTICLE_SLUGS } }),
    ]);
    console.log('🧹 Cleaned existing seed data (preserved manually created data)');

    // 1. Seed Users
    const users = await User.create(mockUsers);
    console.log(`👤 Created ${users.length} users`);

    const customer = users.find((u) => u.role === 'USER' && u.email === 'customer@gmail.com');
    const owner = users.find((u) => u.email === 'owner@gmail.com');
    const staffUser = users.find((u) => u.email === 'staff@gmail.com');

    // 2. Iterate through mockBusinesses and build detailed entities
    const createdBusinesses = [];
    const createdBranches = [];

    for (let busData of mockBusinesses) {
      const { branchInfo, products, ...businessPayload } = busData;

      // Create Business
      const business = await Business.create({
        ...businessPayload,
        ownerId: owner._id,
      });
      createdBusinesses.push(business);

      // Create Branch
      const branch = await Branch.create({
        businessId: business._id,
        name: branchInfo.name,
        address: {
          street: branchInfo.street,
          ward: branchInfo.ward,
          district: branchInfo.district,
          city: branchInfo.city,
        },
        location: {
          type: 'Point',
          coordinates: branchInfo.coordinates,
        },
        phone: branchInfo.phone,
        openingHours: [
          { day: 1, open: '07:00', close: '22:30' },
          { day: 2, open: '07:00', close: '22:30' },
          { day: 3, open: '07:00', close: '22:30' },
        ],
        amenities: branchInfo.amenities,
        status: 'ACTIVE',
      });
      createdBranches.push(branch);

      // Assign Staff to first branch
      if (createdBusinesses.length === 1) {
        await Staff.create({
          userId: staffUser._id,
          businessId: business._id,
          branchId: branch._id,
          position: 'RECEPTIONIST',
          permissions: ['BOOKING_MANAGE', 'ORDER_VIEW', 'ORDER_MANAGE', 'CHECK_IN'],
          status: 'ACTIVE',
        });
      }

      // Create Menu
      const menu = await Menu.create({
        businessId: business._id,
        branchId: branch._id,
        name: `Menu Thực Đơn - ${business.name}`,
        description: 'Menu món ăn & đồ uống chính thức',
        status: 'ACTIVE',
      });

      // Create Products for this Branch
      for (let prodData of products) {
        await Product.create({
          ...prodData,
          menuId: menu._id,
          branchId: branch._id,
          isAvailable: true,
        });
      }

      // Create Table
      await Table.create({
        branchId: branch._id,
        name: 'A01',
        capacity: 4,
        location: 'Tầng 1 - Cửa sổ',
        status: 'AVAILABLE',
      });
    }

    // 3. Seed Sample Booking & Order for first business
    const firstBusiness = createdBusinesses[0];
    const firstBranch = createdBranches[0];

    const booking = await Booking.create({
      userId: customer._id,
      businessId: firstBusiness._id,
      branchId: firstBranch._id,
      bookingCode: 'FCB202609001',
      bookingDate: '2026-09-15',
      startTime: '19:00',
      endTime: '21:00',
      guestCount: 2,
      status: 'CONFIRMED',
      note: 'Hẹn hò kỉ niệm 1 năm, xếp góc yên tĩnh giúp mình nhé',
    });

    const order = await Order.create({
      orderCode: 'FCO202609001',
      userId: customer._id,
      businessId: firstBusiness._id,
      branchId: firstBranch._id,
      bookingId: booking._id,
      orderType: 'PRE_ORDER',
      items: [
        {
          productId: firstBusiness._id,
          productName: 'Phin Sữa Đá (Đặc Sản)',
          unitPrice: 39000,
          quantity: 2,
          selectedOptions: [{ name: 'Size', value: 'L', additionalPrice: 10000 }],
          subtotal: 98000,
        },
      ],
      subtotal: 98000,
      discount: 0,
      total: 98000,
      status: 'CONFIRMED',
    });

    booking.preOrderId = order._id;
    await booking.save();

    await Favorite.create({
      userId: customer._id,
      businessId: firstBusiness._id,
    });

    // 4. Seed Reviews for ALL Businesses
    let seededReviewsCount = 0;
    for (let rData of mockReviewsData) {
      const targetBus = createdBusinesses[rData.busIndex];
      const targetBranch = createdBranches[rData.busIndex];

      await Review.create({
        userId: customer._id,
        businessId: targetBus._id,
        branchId: targetBranch._id,
        bookingId: booking._id,
        orderId: order._id,
        rating: rData.rating,
        content: rData.content,
        images: rData.images,
        isVerified: rData.isVerified,
        status: 'PUBLISHED',
      });
      seededReviewsCount++;

      // Update business rating summary
      const allBusReviews = await Review.find({ businessId: targetBus._id, status: 'PUBLISHED' });
      const sum = allBusReviews.reduce((acc, item) => acc + item.rating, 0);
      const avg = Math.round((sum / allBusReviews.length) * 10) / 10;
      await Business.findByIdAndUpdate(targetBus._id, {
        ratingSummary: { average: avg, totalReviews: allBusReviews.length },
      });
    }

    // 5. Seed Interactions & Notifications
    const sampleInteractions = [
      {
        userId: customer._id,
        businessId: firstBusiness._id,
        branchId: firstBranch._id,
        type: 'SEARCH',
        metadata: { query: 'Hải sản tươi sống Đà Nẵng', category: 'RESTAURANT' },
        createdAt: new Date(Date.now() - 3600000 * 1),
      },
      {
        userId: customer._id,
        businessId: firstBusiness._id,
        branchId: firstBranch._id,
        type: 'VIEW',
        metadata: { source: 'HOMEPAGE_RECOMMENDATION', durationSec: 45 },
        createdAt: new Date(Date.now() - 3600000 * 2),
      },
      {
        userId: customer._id,
        businessId: firstBusiness._id,
        branchId: firstBranch._id,
        type: 'CLICK',
        metadata: { target: 'MENU_ITEM', item: 'Cua Huỳnh Đế Hấp Sả' },
        createdAt: new Date(Date.now() - 3600000 * 3),
      },
      {
        userId: customer._id,
        businessId: createdBusinesses[1]?._id || firstBusiness._id,
        branchId: firstBranch._id,
        type: 'FAVORITE',
        metadata: { list: 'Địa điểm ăn tối lý tưởng' },
        createdAt: new Date(Date.now() - 3600000 * 4),
      },
      {
        userId: customer._id,
        businessId: firstBusiness._id,
        branchId: firstBranch._id,
        type: 'BOOKING',
        metadata: { guests: 4, timeSlot: '19:30', note: 'Bàn gần kính' },
        createdAt: new Date(Date.now() - 3600000 * 5),
      },
      {
        userId: customer._id,
        businessId: createdBusinesses[1]?._id || firstBusiness._id,
        branchId: firstBranch._id,
        type: 'ORDER',
        metadata: { totalAmount: 420000, itemsCount: 3, paymentMethod: 'MOMO' },
        createdAt: new Date(Date.now() - 3600000 * 6),
      },
      {
        userId: customer._id,
        businessId: createdBusinesses[0]?._id || firstBusiness._id,
        branchId: firstBranch._id,
        type: 'SEARCH',
        metadata: { query: 'Cà phê view biển Võ Nguyên Giáp', category: 'CAFE' },
        createdAt: new Date(Date.now() - 3600000 * 8),
      },
      {
        userId: customer._id,
        businessId: createdBusinesses[1]?._id || firstBusiness._id,
        branchId: firstBranch._id,
        type: 'VIEW',
        metadata: { source: 'SEARCH_RESULTS_MAP' },
        createdAt: new Date(Date.now() - 3600000 * 10),
      },
      {
        userId: customer._id,
        businessId: firstBusiness._id,
        branchId: firstBranch._id,
        type: 'RATING',
        metadata: { score: 5, tags: ['Ngon', 'Sạch sẻ', 'Phục vụ tốt'] },
        createdAt: new Date(Date.now() - 3600000 * 12),
      },
      {
        userId: customer._id,
        businessId: createdBusinesses[2]?._id || firstBusiness._id,
        branchId: firstBranch._id,
        type: 'CLICK',
        metadata: { target: 'PROMOTION_BANNER', discountCode: 'SUMMER50K' },
        createdAt: new Date(Date.now() - 3600000 * 14),
      },
    ];

    await UserInteraction.insertMany(sampleInteractions);

    // 6. Seed Articles & Posts
    const sampleArticles = [
      {
        title: 'Top 5 Quán Cà Phê View Biển Tuyệt Đẹp Không Thể Bỏ Qua Tại Đà Nẵng',
        slug: 'top-5-quan-ca-phe-view-bien-da-nang',
        summary: 'Khám phá những tọa độ ngắm hoàng hôn đỉnh cao cùng tách cà phê chuẩn gu bên bờ biển Mỹ Khê.',
        content: 'Đà Nẵng không chỉ nổi tiếng với những bãi biển xanh ngắt mà còn thu hút giới trẻ nhờ hàng loạt quán cà phê có không gian mở cực chill...',
        category: 'Review Quán Hot',
        coverImage: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=800&q=80',
        authorId: customer._id,
        authorName: 'Hoàng Lưu F&B Critic',
        authorRole: 'Chuyên gia Ẩm thực',
        authorAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
        businessId: firstBusiness._id,
        branchId: firstBranch._id,
        tags: ['Cafe', 'View Biển', 'Sống Ảo', 'Đà Nẵng'],
        views: 1240,
        likes: 185,
        readTime: '5 phút đọc',
        isFeatured: true,
        status: 'PUBLISHED',
      },
      {
        title: 'Trải Nghiệm Ẩm Thực Hải Sản Tươi Sống Đỉnh Cao Tại Bé Mặn Đà Nẵng',
        slug: 'trai-nghiem-am-thuc-hai-san-be-man',
        summary: 'Đánh giá chi tiết các món Cua Huỳnh Đế, Tôm Hùm Nướng Bơ Tỏi và Ốc Hương Trứng Muối cực hấp dẫn.',
        content: 'Quán Hải Sản Bé Mặn từ lâu đã là điểm đến không thể bỏ qua đối với thực khách khi ghé thăm thành phố biển...',
        category: 'Ẩm Thực Vùng Miền',
        coverImage: 'https://images.unsplash.com/photo-1559847844-5315695dadae?auto=format&fit=crop&w=800&q=80',
        authorId: customer._id,
        authorName: 'Hoàng Lưu F&B Critic',
        authorRole: 'Chuyên gia Ẩm thực',
        authorAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
        businessId: createdBusinesses[1]?._id || firstBusiness._id,
        branchId: firstBranch._id,
        tags: ['Hải Sản', 'Bé Mặn', 'Ăn Tối', 'Đà Nẵng'],
        views: 2150,
        likes: 340,
        readTime: '6 phút đọc',
        isFeatured: true,
        status: 'PUBLISHED',
      },
      {
        title: 'Bí Quyết Thưởng Thức Lẩu Nướng BBQ Chuẩn Vị Hàn Quốc Tại Pizza 4P\'s & BBQ',
        slug: 'bi-quyet-thuong-thuc-bbq-chuan-vi-han',
        summary: 'Mẹo chọn thịt bò Bò Mỹ Omai cao cấp và sốt chấm đặc biệt của nhà hàng.',
        content: 'Thịt nướng Hàn Quốc luôn nằm trong tốp lựa chọn của giới trẻ khi tụ họp gia đình và bạn bè cuối tuần...',
        category: 'Góc Ẩm Thực',
        coverImage: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=800&q=80',
        authorId: customer._id,
        authorName: 'Hoàng Lưu F&B Critic',
        authorRole: 'Chuyên gia Ẩm thực',
        authorAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
        businessId: createdBusinesses[2]?._id || firstBusiness._id,
        branchId: firstBranch._id,
        tags: ['BBQ', 'Nướng Hàn Quốc', 'Tụ Hợp'],
        views: 890,
        likes: 92,
        readTime: '4 phút đọc',
        isFeatured: false,
        status: 'PUBLISHED',
      },
      {
        title: 'Xu Hướng Trà Sữa Đèn Lồng Đang Gây Bão Giới Trẻ Năm 2026',
        slug: 'xu-huong-tra-sua-den-long-2026',
        summary: 'Bản tin cập nhật những món uống sáng tạo kết hợp topping độc lạ.',
        content: 'Trà sữa luôn đổi mới từng ngày với nhiều trào lưu topping phong phú...',
        category: 'Bản Tin F&B',
        coverImage: 'https://images.unsplash.com/photo-1558857563-b371033873b8?auto=format&fit=crop&w=800&q=80',
        authorId: customer._id,
        authorName: 'Hoàng Lưu F&B Critic',
        authorRole: 'Chuyên gia Ẩm thực',
        authorAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
        businessId: firstBusiness._id,
        branchId: firstBranch._id,
        tags: ['Trà Sữa', 'Trào Lưu', 'Đà Nẵng'],
        views: 430,
        likes: 45,
        readTime: '3 phút đọc',
        isFeatured: false,
        status: 'DRAFT',
      },
    ];

    await Article.insertMany(sampleArticles);

    console.log(`⭐ Seeded ${seededReviewsCount} Verified Reviews for all ${createdBusinesses.length} Businesses`);
    console.log('✅ SEEDING COMPLETE SUCCESSFULLY WITH ARTICLES & REVIEWS! 🚀');
    process.exit(0);
  } catch (error) {
    console.error('❌ Seeding Error:', error);
    process.exit(1);
  }
};

seedAll();

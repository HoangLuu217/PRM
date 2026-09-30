import mongoose from 'mongoose';
import dotenv from 'dotenv';
import dns from 'dns';

// Fix Node.js DNS SRV resolution issue on Windows
try {
  dns.setDefaultResultOrder('ipv4first');
  dns.setServers(['8.8.8.8', '1.1.1.1']);
} catch (e) {
  console.warn('DNS config warning:', e.message);
}

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

dotenv.config();

const cleanSeedData = async () => {
  try {
    const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/fconnect';
    console.log('📡 Connecting to MongoDB Atlas...');
    await mongoose.connect(uri, {
      serverSelectionTimeoutMS: 15000,
    });
    console.log('✅ Connected to MongoDB Atlas!');

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
    const seededUsers = await User.find({ email: { $in: SEED_EMAILS } }).select('_id email');
    const seededUserIds = seededUsers.map((u) => u._id);

    const seededBusinesses = await Business.find({ slug: { $in: SEED_BUSINESS_SLUGS } }).select('_id slug');
    const seededBusinessIds = seededBusinesses.map((b) => b._id);

    const seededBranches = await Branch.find({ businessId: { $in: seededBusinessIds } }).select('_id');
    const seededBranchIds = seededBranches.map((b) => b._id);

    const seededMenus = await Menu.find({ businessId: { $in: seededBusinessIds } }).select('_id');
    const seededMenuIds = seededMenus.map((m) => m._id);

    console.log(`\n🔍 Found Seeded Entities to Remove:`);
    console.log(`   - Seeded Users: ${seededUsers.length}`);
    console.log(`   - Seeded Businesses: ${seededBusinesses.length}`);
    console.log(`   - Seeded Branches: ${seededBranches.length}`);
    console.log(`   - Seeded Menus: ${seededMenus.length}`);

    // Perform selective deletion of SEED data only
    const resUsers = await User.deleteMany({ _id: { $in: seededUserIds } });
    const resBusinesses = await Business.deleteMany({ _id: { $in: seededBusinessIds } });
    const resBranches = await Branch.deleteMany({ _id: { $in: seededBranchIds } });
    const resMenus = await Menu.deleteMany({ _id: { $in: seededMenuIds } });
    const resProducts = await Product.deleteMany({
      $or: [{ branchId: { $in: seededBranchIds } }, { menuId: { $in: seededMenuIds } }],
    });
    const resTables = await Table.deleteMany({ branchId: { $in: seededBranchIds } });
    const resStaff = await Staff.deleteMany({
      $or: [{ userId: { $in: seededUserIds } }, { businessId: { $in: seededBusinessIds } }],
    });
    const resBookings = await Booking.deleteMany({
      $or: [
        { bookingCode: 'FCB202609001' },
        { userId: { $in: seededUserIds } },
        { businessId: { $in: seededBusinessIds } },
      ],
    });
    const resOrders = await Order.deleteMany({
      $or: [
        { orderCode: 'FCO202609001' },
        { userId: { $in: seededUserIds } },
        { businessId: { $in: seededBusinessIds } },
      ],
    });
    const resFavorites = await Favorite.deleteMany({
      $or: [{ userId: { $in: seededUserIds } }, { businessId: { $in: seededBusinessIds } }],
    });
    const resReviews = await Review.deleteMany({
      $or: [{ userId: { $in: seededUserIds } }, { businessId: { $in: seededBusinessIds } }],
    });
    const resInteractions = await UserInteraction.deleteMany({ userId: { $in: seededUserIds } });
    const resArticles = await Article.deleteMany({ slug: { $in: SEED_ARTICLE_SLUGS } });

    console.log('\n🧹 DELETED SEED DATA SUMMARY:');
    console.log(`   - Users deleted: ${resUsers.deletedCount}`);
    console.log(`   - Businesses deleted: ${resBusinesses.deletedCount}`);
    console.log(`   - Branches deleted: ${resBranches.deletedCount}`);
    console.log(`   - Menus deleted: ${resMenus.deletedCount}`);
    console.log(`   - Products deleted: ${resProducts.deletedCount}`);
    console.log(`   - Tables deleted: ${resTables.deletedCount}`);
    console.log(`   - Staff deleted: ${resStaff.deletedCount}`);
    console.log(`   - Bookings deleted: ${resBookings.deletedCount}`);
    console.log(`   - Orders deleted: ${resOrders.deletedCount}`);
    console.log(`   - Favorites deleted: ${resFavorites.deletedCount}`);
    console.log(`   - Reviews deleted: ${resReviews.deletedCount}`);
    console.log(`   - Interactions deleted: ${resInteractions.deletedCount}`);
    console.log(`   - Articles deleted: ${resArticles.deletedCount}`);

    // Check remaining manual data count
    const countUsers = await User.countDocuments();
    const countBusinesses = await Business.countDocuments();
    const countBranches = await Branch.countDocuments();
    const countProducts = await Product.countDocuments();
    const countArticles = await Article.countDocuments();

    console.log('\n✅ REMAINING MANUALLY CREATED DATA (KEPT INTACT IN MONGODB ATLAS):');
    console.log(`   - Remaining Users: ${countUsers}`);
    console.log(`   - Remaining Businesses: ${countBusinesses}`);
    console.log(`   - Remaining Branches: ${countBranches}`);
    console.log(`   - Remaining Products: ${countProducts}`);
    console.log(`   - Remaining Articles: ${countArticles}`);

    process.exit(0);
  } catch (error) {
    console.error('❌ Clean Error:', error);
    process.exit(1);
  }
};

cleanSeedData();

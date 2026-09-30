import dotenv from 'dotenv';
dotenv.config();
import mongoose from 'mongoose';
import { User, UserInteraction, Business } from '../src/models/index.js';

async function seedDistinctTastes() {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('Connected to MongoDB');

  const businesses = await Business.find({ status: 'APPROVED' }).lean();
  console.log(`Loaded ${businesses.length} businesses`);

  const cafeBiz = businesses.filter(b => b.categories?.includes('CAFE') || b.categories?.includes('BAKERY'));
  const bbqBiz = businesses.filter(b => b.categories?.includes('BBQ') || b.categories?.includes('BUFFET'));
  const milkTeaBiz = businesses.filter(b => b.categories?.includes('MILK_TEA') || b.categories?.includes('DESSERT'));

  console.log(`Found: ${cafeBiz.length} cafes/bakeries, ${bbqBiz.length} BBQ/buffet, ${milkTeaBiz.length} milk tea/dessert`);

  // 1. User 1: hoangluu2172k4@gmail.com -> Cafe & Bakery lover
  const u1 = await User.findOne({ email: 'hoangluu2172k4@gmail.com' });
  if (u1) {
    u1.preferences = {
      favoriteCategories: ['CAFE', 'BAKERY'],
      priceRange: { min: 25000, max: 120000 },
      preferredAreas: ['Hải Châu', 'Sơn Trà'],
    };
    await u1.save();

    // Clean old & seed fresh cafe interactions
    await UserInteraction.deleteMany({ userId: u1._id });
    const u1Interactions = [];
    cafeBiz.forEach(b => {
      u1Interactions.push(
        { userId: u1._id, businessId: b._id, type: 'CLICK', metadata: { source: 'category_pill_click' } },
        { userId: u1._id, businessId: b._id, type: 'VIEW', metadata: { dwellSeconds: 45 } }
      );
    });
    if (cafeBiz[0]) {
      u1Interactions.push(
        { userId: u1._id, businessId: cafeBiz[0]._id, type: 'FAVORITE' },
        { userId: u1._id, businessId: cafeBiz[0]._id, type: 'ORDER', metadata: { total: 85000 } }
      );
    }
    if (cafeBiz[1]) {
      u1Interactions.push({ userId: u1._id, businessId: cafeBiz[1]._id, type: 'FAVORITE' });
    }
    u1Interactions.push(
      { userId: u1._id, type: 'SEARCH', metadata: { keyword: 'cà phê đẹp yên tĩnh đà nẵng' } },
      { userId: u1._id, type: 'SEARCH', metadata: { keyword: 'cafe làm việc' } }
    );
    await UserInteraction.insertMany(u1Interactions);
    console.log(`✅ Seeded User 1 (HOÀNG LƯU - CAFE lover): ${u1Interactions.length} interactions`);
  }

  // 2. User 2: trongphuc20704@gmail.com -> BBQ & Buffet lover
  const u2 = await User.findOne({ email: 'trongphuc20704@gmail.com' });
  if (u2) {
    u2.preferences = {
      favoriteCategories: ['BBQ', 'BUFFET'],
      priceRange: { min: 150000, max: 400000 },
      preferredAreas: ['Hải Châu', 'Thanh Khê'],
    };
    await u2.save();

    await UserInteraction.deleteMany({ userId: u2._id });
    const u2Interactions = [];
    bbqBiz.forEach(b => {
      u2Interactions.push(
        { userId: u2._id, businessId: b._id, type: 'CLICK', metadata: { source: 'search' } },
        { userId: u2._id, businessId: b._id, type: 'VIEW', metadata: { dwellSeconds: 60 } }
      );
    });
    if (bbqBiz[0]) {
      u2Interactions.push(
        { userId: u2._id, businessId: bbqBiz[0]._id, type: 'FAVORITE' },
        { userId: u2._id, businessId: bbqBiz[0]._id, type: 'BOOKING', metadata: { guestCount: 4 } }
      );
    }
    if (bbqBiz[1]) {
      u2Interactions.push({ userId: u2._id, businessId: bbqBiz[1]._id, type: 'FAVORITE' });
    }
    u2Interactions.push(
      { userId: u2._id, type: 'SEARCH', metadata: { keyword: 'quán nướng ngon đà nẵng' } },
      { userId: u2._id, type: 'SEARCH', metadata: { keyword: 'lẩu bò tụ tập' } }
    );
    await UserInteraction.insertMany(u2Interactions);
    console.log(`✅ Seeded User 2 (Trong Phuc - BBQ lover): ${u2Interactions.length} interactions`);
  }

  // 3. User 3: luuldhde180497@fpt.edu.vn -> Milk Tea & Dessert lover
  const u3 = await User.findOne({ email: 'luuldhde180497@fpt.edu.vn' });
  if (u3) {
    u3.preferences = {
      favoriteCategories: ['MILK_TEA', 'DESSERT'],
      priceRange: { min: 20000, max: 80000 },
      preferredAreas: ['Hải Châu'],
    };
    await u3.save();

    await UserInteraction.deleteMany({ userId: u3._id });
    const u3Interactions = [];
    milkTeaBiz.forEach(b => {
      u3Interactions.push(
        { userId: u3._id, businessId: b._id, type: 'CLICK', metadata: { source: 'category' } },
        { userId: u3._id, businessId: b._id, type: 'VIEW', metadata: { dwellSeconds: 30 } }
      );
    });
    if (milkTeaBiz[0]) {
      u3Interactions.push(
        { userId: u3._id, businessId: milkTeaBiz[0]._id, type: 'FAVORITE' },
        { userId: u3._id, businessId: milkTeaBiz[0]._id, type: 'ORDER', metadata: { total: 65000 } }
      );
    }
    u3Interactions.push(
      { userId: u3._id, type: 'SEARCH', metadata: { keyword: 'trà sữa trân châu đường đen' } },
      { userId: u3._id, type: 'SEARCH', metadata: { keyword: 'chè sầu riêng ăn vặt' } }
    );
    await UserInteraction.insertMany(u3Interactions);
    console.log(`✅ Seeded User 3 (K18 DN - Milk Tea lover): ${u3Interactions.length} interactions`);
  }

  // 4. User 4: hoangluu2172k4+1@gmail.com -> Fresh / Cold Start (0 interactions, empty preferences)
  const u4 = await User.findOne({ email: 'hoangluu2172k4+1@gmail.com' });
  if (u4) {
    u4.preferences = { favoriteCategories: [], priceRange: { min: 0, max: 1000000 }, preferredAreas: [] };
    await u4.save();
    await UserInteraction.deleteMany({ userId: u4._id });
    console.log(`✅ Reset User 4 (Cold start): 0 interactions & empty preferences`);
  }

  console.log('\n🎉 Finished seeding distinct user tastes!');
  process.exit(0);
}

seedDistinctTastes().catch(err => {
  console.error(err);
  process.exit(1);
});

import mongoose from 'mongoose';
import dotenv from 'dotenv';
import { Business } from '../models/index.js';

dotenv.config();

const defaultTagMappings = [
  {
    keyword: 'highlands',
    vibes: ['Yên tĩnh / Làm việc', 'Hiện đại / Sang trọng', 'Ngoài trời / Sân vườn'],
    purposes: ['Họp nhóm / Học bài', 'Gặp gỡ bạn bè', 'Ăn một mình / Chill'],
    priceRange: { min: 29000, max: 75000 },
  },
  {
    keyword: 'pizza',
    vibes: ['Lãng mạn / Hẹn hò', 'Hiện đại / Sang trọng', 'Ấm cúng / Gia đình'],
    purposes: ['Hẹn hò cặp đôi', 'Bữa ăn gia đình', 'Tiếp khách / Công việc', 'Tổ chức sinh nhật / Tiệc'],
    priceRange: { min: 150000, max: 650000 },
  },
  {
    keyword: 'k-pub',
    vibes: ['Sôi động / Nhộn nhịp', 'Hiện đại / Sang trọng', 'Rộng rãi / Nhóm đông'],
    purposes: ['Tụ tập bạn bè', 'Bữa ăn gia đình', 'Tổ chức sinh nhật / Tiệc'],
    priceRange: { min: 199000, max: 399000 },
  },
  {
    keyword: 'gong cha',
    vibes: ['Check-in sống ảo', 'Yên tĩnh / Làm việc', 'Ấm cúng / Gia đình'],
    purposes: ['Gặp gỡ bạn bè', 'Họp nhóm / Học bài', 'Thư giãn cuối tuần', 'Ăn một mình / Chill'],
    priceRange: { min: 38000, max: 85000 },
  },
  {
    keyword: 'bé mặn',
    vibes: ['Ngoài trời / Sân vườn', 'Rộng rãi / Nhóm đông', 'Vỉa hè / Đường phố'],
    purposes: ['Bữa ăn gia đình', 'Tụ tập bạn bè', 'Tiếp khách / Công việc'],
    priceRange: { min: 100000, max: 600000 },
  },
];

const fallbackVibesByCategory = {
  CAFE: ['Yên tĩnh / Làm việc', 'Check-in sống ảo', 'Ấm cúng / Gia đình'],
  RESTAURANT: ['Hiện đại / Sang trọng', 'Ấm cúng / Gia đình', 'Lãng mạn / Hẹn hò'],
  MILK_TEA: ['Trẻ trung / Năng động', 'Check-in sống ảo', 'Yên tĩnh / Làm việc'],
  BBQ: ['Sôi động / Nhộn nhịp', 'Rộng rãi / Nhóm đông', 'Ấm cúng / Gia đình'],
  BUFFET: ['Rộng rãi / Nhóm đông', 'Hiện đại / Sang trọng', 'Ấm cúng / Gia đình'],
  BAKERY: ['Ấm cúng / Gia đình', 'Check-in sống ảo', 'Yên tĩnh / Làm việc'],
  FAST_FOOD: ['Trẻ trung / Năng động', 'Nhanh chóng / Tiện lợi'],
  BAR: ['Sôi động / Nhộn nhịp', 'Rooftop / View trên cao', 'Lãng mạn / Hẹn hò'],
  OTHER: ['Ấm cúng / Gia đình', 'Yên tĩnh / Làm việc'],
};

const fallbackPurposesByCategory = {
  CAFE: ['Họp nhóm / Học bài', 'Gặp gỡ bạn bè', 'Ăn một mình / Chill'],
  RESTAURANT: ['Bữa ăn gia đình', 'Hẹn hò cặp đôi', 'Tiếp khách / Công việc'],
  MILK_TEA: ['Gặp gỡ bạn bè', 'Họp nhóm / Học bài', 'Thư giãn cuối tuần'],
  BBQ: ['Tụ tập bạn bè', 'Bữa ăn gia đình', 'Tổ chức sinh nhật / Tiệc'],
  BUFFET: ['Bữa ăn gia đình', 'Tổ chức sinh nhật / Tiệc', 'Tụ tập bạn bè'],
  BAKERY: ['Gặp gỡ bạn bè', 'Ăn một mình / Chill'],
  FAST_FOOD: ['Ăn nhanh', 'Gặp gỡ bạn bè'],
  BAR: ['Hẹn hò cặp đôi', 'Tụ tập bạn bè', 'Thư giãn cuối tuần'],
  OTHER: ['Gặp gỡ bạn bè', 'Bữa ăn gia đình'],
};

async function run() {
  try {
    const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/fconnect';
    console.log('Connecting to MongoDB:', uri);
    await mongoose.connect(uri);
    console.log('✅ Connected to MongoDB');

    const businesses = await Business.find({});
    console.log(`Found ${businesses.length} businesses to inspect`);

    let updatedCount = 0;
    for (const biz of businesses) {
      let matched = defaultTagMappings.find((m) =>
        biz.name.toLowerCase().includes(m.keyword) || biz.slug.toLowerCase().includes(m.keyword)
      );

      const cat = (biz.categories && biz.categories[0]) || 'RESTAURANT';
      const newVibes = (biz.vibes && biz.vibes.length > 0)
        ? biz.vibes
        : (matched?.vibes || fallbackVibesByCategory[cat] || fallbackVibesByCategory.RESTAURANT);

      const newPurposes = (biz.purposes && biz.purposes.length > 0)
        ? biz.purposes
        : (matched?.purposes || fallbackPurposesByCategory[cat] || fallbackPurposesByCategory.RESTAURANT);

      const priceRange = (biz.priceRange && (biz.priceRange.min > 0 || biz.priceRange.max > 0))
        ? biz.priceRange
        : (matched?.priceRange || { min: 30000, max: 150000 });

      await Business.findByIdAndUpdate(biz._id, {
        vibes: newVibes,
        purposes: newPurposes,
        priceRange,
      });

      console.log(`Updated [${biz.name}]: vibes=${newVibes.length}, purposes=${newPurposes.length}, price=${priceRange.min}-${priceRange.max}`);
      updatedCount++;
    }

    console.log(`🎉 Successfully updated ${updatedCount} businesses with vibes & purposes!`);
    process.exit(0);
  } catch (err) {
    console.error('❌ Error updating tags:', err);
    process.exit(1);
  }
}

run();

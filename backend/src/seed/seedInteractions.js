import mongoose from 'mongoose';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import path from 'path';
import { Business, UserInteraction, User } from '../models/index.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

export const seedInteractions = async () => {
  try {
    if (mongoose.connection.readyState !== 1) {
      console.log('Connecting to MongoDB...');
      await mongoose.connect(process.env.MONGODB_URI);
      console.log('Connected to MongoDB.');
    }

    const businesses = await Business.find().select('_id name categories slug googleRating');
    if (businesses.length === 0) {
      console.log('No businesses found to seed interactions.');
      return;
    }

    // Optional user ID from database
    const sampleUser = await User.findOne();
    const sampleUserId = sampleUser ? sampleUser._id : null;

    console.log(`Generating interaction history for ${businesses.length} businesses...`);

    // Clean existing interactions to have fresh realistic dataset
    await UserInteraction.deleteMany({});

    const interactions = [];

    // Realistic search keywords for Da Nang food scene
    const searchTerms = [
      'pizza 4ps đà nẵng',
      'hải sản đà nẵng ngon rẻ',
      'quán ăn ngon đà nẵng',
      'cà phê đẹp ngắm sông hàn',
      'bếp trang mì quảng',
      'chè sầu riêng liên',
      'bánh xèo bà dưỡng hoàng diệu',
      'cơm niêu nhà đỏ',
      'quán nướng đà nẵng',
      'hải sản bé mặn đà nẵng',
      '43 factory coffee',
      'quán cà phê yên tĩnh đà nẵng',
      'quán lẩu bò ngon đà nẵng',
      'bún chả cá bà hoa',
    ];

    businesses.forEach((biz) => {
      // Base click/view interactions based on fame / google ratings
      let baseWeight = 20;
      const ggRating = biz.googleRating?.rating || 4.2;
      const ggReviews = biz.googleRating?.userRatingsTotal || 500;

      if (ggRating >= 4.8 || ggReviews > 5000) baseWeight = 85;
      else if (ggRating >= 4.6 || ggReviews > 2000) baseWeight = 55;
      else if (ggRating >= 4.4) baseWeight = 35;

      // Generate CLICK & VIEW interactions
      const numClicks = Math.floor(baseWeight * (0.8 + Math.random() * 0.5));
      for (let i = 0; i < numClicks; i++) {
        interactions.push({
          userId: sampleUserId,
          businessId: biz._id,
          type: Math.random() > 0.3 ? 'CLICK' : 'VIEW',
          metadata: {
            source: 'customer_home_featured',
            device: Math.random() > 0.5 ? 'mobile' : 'desktop',
          },
          createdAt: new Date(Date.now() - Math.floor(Math.random() * 15 * 86400000)),
        });
      }

      // Generate SEARCH interactions related to this business
      const numSearches = Math.floor((baseWeight / 2) * (0.7 + Math.random() * 0.6));
      for (let j = 0; j < numSearches; j++) {
        const matchingKeyword =
          biz.name.toLowerCase() + (Math.random() > 0.5 ? ' đà nẵng' : '');
        interactions.push({
          userId: sampleUserId,
          businessId: biz._id,
          type: 'SEARCH',
          metadata: {
            keyword: matchingKeyword,
          },
          createdAt: new Date(Date.now() - Math.floor(Math.random() * 15 * 86400000)),
        });
      }
    });

    // Add generic top searches distributed
    for (let k = 0; k < 60; k++) {
      const kw = searchTerms[Math.floor(Math.random() * searchTerms.length)];
      interactions.push({
        userId: sampleUserId,
        type: 'SEARCH',
        metadata: { keyword: kw },
        createdAt: new Date(Date.now() - Math.floor(Math.random() * 10 * 86400000)),
      });
    }

    await UserInteraction.insertMany(interactions);
    console.log(` Successfully seeded ${interactions.length} user interactions (Clicks, Views, Searches)!`);
  } catch (err) {
    console.error('Error seeding interactions:', err);
  }
};

// If run directly
if (process.argv[1] && process.argv[1].endsWith('seedInteractions.js')) {
  seedInteractions()
    .then(() => {
      console.log('Done.');
      process.exit(0);
    })
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}

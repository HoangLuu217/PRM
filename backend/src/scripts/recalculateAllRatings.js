import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

import mongoose from 'mongoose';
import { Business, Review } from '../models/index.js';

async function recalculate() {
  try {
    const uri = process.env.MONGODB_URI;
    if (!uri) {
      throw new Error('MONGODB_URI is not defined in .env');
    }

    console.log('Connecting to MongoDB...');
    await mongoose.connect(uri);
    console.log('✅ Connected to MongoDB.');

    const businesses = await Business.find({});
    console.log(`Found ${businesses.length} businesses.`);

    let updatedCount = 0;
    for (const bus of businesses) {
      const reviews = await Review.find({ businessId: bus._id, status: 'PUBLISHED' });
      let average = 0;
      let totalReviews = reviews.length;

      if (totalReviews > 0) {
        const sum = reviews.reduce((acc, r) => acc + (Number(r.rating) || 5), 0);
        average = Math.round((sum / totalReviews) * 10) / 10;
      }

      await Business.findByIdAndUpdate(bus._id, {
        ratingSummary: { average, totalReviews },
      });

      if (totalReviews > 0) {
        console.log(`- [${bus.name}]: ${totalReviews} reviews, average ${average}`);
      }
      updatedCount++;
    }

    console.log(`✅ Successfully updated ratingSummary for all ${updatedCount} businesses.`);
    process.exit(0);
  } catch (err) {
    console.error('❌ Error during recalculation:', err);
    process.exit(1);
  }
}

recalculate();

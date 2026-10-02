import mongoose from 'mongoose';
import dns from 'dns';

export const connectDB = async () => {
  try {
    try {
      dns.setServers(['8.8.8.8', '8.8.4.4', '1.1.1.1']);
    } catch (e) {}

    const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/fconnect';
    const conn = await mongoose.connect(uri);
    console.log(`✅ MongoDB Connected: ${conn.connection.host}`);
  } catch (error) {
    console.error(`❌ MongoDB Connection Error: ${error.message}`);
    // In dev mode without local mongo, log fallback warning
    if (process.env.NODE_ENV === 'development') {
      console.warn('⚠️ MongoDB connection failed. Make sure MongoDB is running or configure MONGODB_URI in .env');
    }
  }
};

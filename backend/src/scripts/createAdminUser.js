import dotenv from 'dotenv';
import mongoose from 'mongoose';
import { User } from '../models/User.js';

dotenv.config();

const createAdmin = async () => {
  try {
    const uri = process.env.MONGODB_URI;
    if (!uri) {
      throw new Error('MONGODB_URI is not set in .env');
    }

    await mongoose.connect(uri);
    console.log('✅ Connected to MongoDB Atlas:', mongoose.connection.name);

    // Desired Admin credentials
    const adminAccounts = [
      {
        fullName: 'Quản Trị Viên FConnect',
        email: 'admin@fconnect.vn',
        password: 'Admin@123456',
        phone: '0909999999',
        role: 'ADMIN',
        status: 'ACTIVE',
        isEmailVerified: true,
        isPhoneVerified: true,
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
      },
      {
        fullName: 'Nguyễn Quản Trị (Admin)',
        email: 'admin@gmail.com',
        password: 'adminpassword',
        phone: '0908888888',
        role: 'ADMIN',
        status: 'ACTIVE',
        isEmailVerified: true,
        isPhoneVerified: true,
        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
      },
    ];

    for (const acc of adminAccounts) {
      let existing = await User.findOne({ email: acc.email });
      if (existing) {
        console.log(`ℹ️ User ${acc.email} already exists. Updating to ADMIN role & password...`);
        existing.fullName = acc.fullName;
        existing.password = acc.password; // pre-save will rehash
        existing.role = 'ADMIN';
        existing.status = 'ACTIVE';
        existing.isEmailVerified = true;
        existing.isPhoneVerified = true;
        existing.phone = acc.phone;
        await existing.save();
        console.log(`✅ Updated ${acc.email} to ADMIN successfully.`);
      } else {
        await User.create(acc);
        console.log(`✅ Created new ADMIN account: ${acc.email}`);
      }
    }

    console.log('\n--- ADMIN ACCOUNTS READY ---');
    adminAccounts.forEach((acc) => {
      console.log(`Email: ${acc.email} | Password: ${acc.password} | Role: ${acc.role}`);
    });

    await mongoose.disconnect();
    process.exit(0);
  } catch (error) {
    console.error('❌ Error creating admin user:', error);
    process.exit(1);
  }
};

createAdmin();

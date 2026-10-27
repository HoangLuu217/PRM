import mongoose from 'mongoose';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

import { User, Business, Branch, Order, Product } from '../models/index.js';

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb+srv://namsky:namsky@note.ukpn84q.mongodb.net/FConnect?retryWrites=true&w=majority';

// Cấu hình doanh thu mục tiêu cho 6 tháng gần nhất (Tháng 5 -> Tháng 10 năm 2026)
const MONTHLY_TARGETS = [
  { month: 5, year: 2026, targetTotal: 3950000, orderCount: 7 },
  { month: 6, year: 2026, targetTotal: 3580000, orderCount: 6 },
  { month: 7, year: 2026, targetTotal: 3920000, orderCount: 7 },
  { month: 8, year: 2026, targetTotal: 6400000, orderCount: 11 }, // Tháng đỉnh doanh thu
  { month: 9, year: 2026, targetTotal: 4200000, orderCount: 8 },
  { month: 10, year: 2026, targetTotal: 3560000, orderCount: 6 },
];

const SAMPLE_DISHES = [
  { name: 'Lẩu Thái Hải Sản Tomyum', price: 289000 },
  { name: 'Bò Mỹ Nướng Tảng Sốt Tiêu', price: 245000 },
  { name: 'Gà Nướng Mật Ong Hoa Rừng', price: 185000 },
  { name: 'Mực Trứng Hấp Gừng Hành', price: 175000 },
  { name: 'Sườn Cốt Lết Nướng Phô Mai', price: 155000 },
  { name: 'Salad Rong Biển Trứng Tôm', price: 95000 },
  { name: 'Cơm Chiên Hải Sản Hoàng Bào', price: 115000 },
  { name: 'Trà Đào Cam Sả Tươi', price: 45000 },
  { name: 'Phin Sữa Đá Đậm Vị', price: 39000 },
  { name: 'Sinh Tố Bơ Dừa Nướng', price: 55000 },
];

async function seedMonthlyOrders() {
  try {
    console.log('Connecting to MongoDB:', MONGODB_URI.replace(/:[^:]*@/, ':****@'));
    await mongoose.connect(MONGODB_URI);
    console.log(' Connected to MongoDB');

    // 1. Lấy danh sách Branch và User khách hàng
    const branches = await Branch.find({});
    if (branches.length === 0) {
      console.error('❌ Không tìm thấy Branch nào trong database. Hãy chạy seed chính trước.');
      process.exit(1);
    }

    const customers = await User.find({ role: 'USER' });
    let fallbackUser = customers[0];
    if (!fallbackUser) {
      fallbackUser = await User.findOne({});
    }

    console.log(`Tìm thấy ${branches.length} chi nhánh và ${customers.length} khách hàng để tạo đơn hàng.`);

    // 2. Xóa các đơn hàng seed doanh thu cũ nếu có (FCO_SEED_*)
    const deleteResult = await Order.deleteMany({ orderCode: /^FCO_SEED_/ });
    console.log(`🧹 Đã dọn dẹp ${deleteResult.deletedCount} đơn hàng seed cũ trước đó.`);

    let totalCreatedOrders = 0;
    let totalCreatedRevenue = 0;

    // 3. Tạo đơn hàng phân bổ đều cho từng tháng
    for (const config of MONTHLY_TARGETS) {
      const { month, year, targetTotal, orderCount } = config;
      console.log(`\n📅 Đang tạo đơn hàng Tháng ${month}/${year} (Mục tiêu: ${targetTotal.toLocaleString('vi-VN')} đ, số lượng: ${orderCount} đơn)...`);

      // Chia nhỏ targetTotal thành các khoản tiền đơn hàng hợp lý
      let remaining = targetTotal;
      const orderAmounts = [];
      for (let i = 0; i < orderCount; i++) {
        if (i === orderCount - 1) {
          orderAmounts.push(remaining);
        } else {
          // Mỗi đơn từ 300k - 800k
          const avg = Math.floor(remaining / (orderCount - i));
          const variation = Math.floor((Math.random() * 0.4 - 0.2) * avg);
          const amt = Math.max(150000, avg + variation);
          orderAmounts.push(amt);
          remaining -= amt;
        }
      }

      for (let idx = 0; idx < orderAmounts.length; idx++) {
        const amount = orderAmounts[idx];
        const branch = branches[idx % branches.length];
        const customer = customers.length > 0 ? customers[idx % customers.length] : fallbackUser;

        // Ngày trong tháng (từ ngày 2 đến ngày 28)
        const day = Math.min(28, Math.max(2, Math.floor((idx + 1) * (26 / orderCount))));
        const hour = 11 + Math.floor(Math.random() * 9); // 11h - 20h
        const minute = Math.floor(Math.random() * 60);
        const orderDate = new Date(year, month - 1, day, hour, minute);

        const orderCode = `FCO_SEED_${year}${String(month).padStart(2, '0')}${String(idx + 1).padStart(3, '0')}`;

        // Chọn ngẫu nhiên 2 - 3 món ăn
        const dish1 = SAMPLE_DISHES[Math.floor(Math.random() * SAMPLE_DISHES.length)];
        const dish2 = SAMPLE_DISHES[Math.floor(Math.random() * SAMPLE_DISHES.length)];

        const items = [
          {
            productId: branch._id,
            productName: dish1.name,
            unitPrice: dish1.price,
            quantity: 1,
            subtotal: dish1.price,
          },
          {
            productId: branch._id,
            productName: dish2.name,
            unitPrice: amount - dish1.price > 0 ? amount - dish1.price : dish2.price,
            quantity: 1,
            subtotal: amount - dish1.price > 0 ? amount - dish1.price : dish2.price,
          },
        ];

        const calculatedTotal = items.reduce((sum, item) => sum + item.subtotal, 0);

        const newOrder = new Order({
          orderCode,
          userId: customer._id,
          businessId: branch.businessId,
          branchId: branch._id,
          orderType: idx % 2 === 0 ? 'DINE_IN' : 'PRE_ORDER',
          items,
          subtotal: calculatedTotal,
          discount: 0,
          total: calculatedTotal,
          status: 'COMPLETED', // Đã hoàn thành -> tính vào doanh thu
          note: `Đơn hàng tự động seed ngày ${day}/${month}/${year}`,
          createdAt: orderDate,
          updatedAt: orderDate,
        });

        await newOrder.save();
        totalCreatedOrders++;
        totalCreatedRevenue += calculatedTotal;
      }

      console.log(`✅ Hoàn thành Tháng ${month}: Tạo thành công ${orderCount} đơn hàng.`);
    }

    console.log('\n=========================================');
    console.log(`🎉 TỔNG KẾT: Đã tạo thành công ${totalCreatedOrders} đơn hàng hoàn tất!`);
    console.log(`💰 Tổng doanh thu tạo mẫu: ${totalCreatedRevenue.toLocaleString('vi-VN')} đ`);
    console.log('=========================================\n');

    await mongoose.disconnect();
    console.log('Đã ngắt kết nối MongoDB.');
    process.exit(0);
  } catch (error) {
    console.error('❌ Lỗi khi seed doanh thu:', error);
    process.exit(1);
  }
}

seedMonthlyOrders();

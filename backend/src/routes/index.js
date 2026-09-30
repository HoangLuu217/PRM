import express from 'express';
import authRoutes from './authRoutes.js';
import businessRoutes from './businessRoutes.js';
import branchRoutes from './branchRoutes.js';
import productRoutes from './productRoutes.js';
import tableRoutes from './tableRoutes.js';
import bookingRoutes from './bookingRoutes.js';
import cartRoutes from './cartRoutes.js';
import orderRoutes from './orderRoutes.js';
import favoriteRoutes from './favoriteRoutes.js';
import reviewRoutes from './reviewRoutes.js';
import staffRoutes from './staffRoutes.js';
import interactionRoutes from './interactionRoutes.js';
import notificationRoutes from './notificationRoutes.js';
import aiRoutes from './aiRoutes.js';
import adminRoutes from './adminRoutes.js';
import articleRoutes from './articleRoutes.js';
import uploadRoutes from './uploadRoutes.js';
import paymentRoutes from './paymentRoutes.js';
import subscriptionRoutes from './subscriptionRoutes.js';

const router = express.Router();

router.use('/auth', authRoutes);
router.use('/businesses', businessRoutes);
router.use('/branches', branchRoutes);
router.use('/products', productRoutes);
router.use('/tables', tableRoutes);
router.use('/bookings', bookingRoutes);
router.use('/payments', paymentRoutes);
router.use('/subscriptions', subscriptionRoutes);
router.use('/carts', cartRoutes);
router.use('/orders', orderRoutes);
router.use('/favorites', favoriteRoutes);
router.use('/reviews', reviewRoutes);
router.use('/staff', staffRoutes);
router.use('/interactions', interactionRoutes);
router.use('/notifications', notificationRoutes);
router.use('/ai', aiRoutes);
router.use('/admin', adminRoutes);
router.use('/articles', articleRoutes);
router.use('/upload', uploadRoutes);

// Legacy routes fallbacks
router.use('/restaurants', businessRoutes);
router.use('/menu', productRoutes);
router.use('/reservations', bookingRoutes);

export default router;

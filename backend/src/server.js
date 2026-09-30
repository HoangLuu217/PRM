import http from 'http';
import express from 'express';
import cors from 'cors';
import morgan from 'morgan';
import dotenv from 'dotenv';
import { connectDB } from './config/db.js';
import apiRoutes from './routes/index.js';
import { errorHandler } from './middlewares/errorHandler.js';
import { initSocket } from './socket.js';

// Environment configuration
dotenv.config();

const app = express();
const httpServer = http.createServer(app);
const PORT = process.env.PORT || 5000;

// Initialize Realtime Socket.IO
initSocket(httpServer);

// Connect to MongoDB
connectDB();

// Middleware
app.use(cors());
app.use(express.json());
app.use(morgan('dev'));

// Welcome / Health check route
app.get('/', (req, res) => {
  res.json({
    status: 'online',
    platform: 'FConnect F&B Platform API Server',
    version: '2.0.0',
    endpoints: {
      auth: '/api/auth',
      businesses: '/api/businesses',
      branches: '/api/branches',
      products: '/api/products',
      tables: '/api/tables',
      bookings: '/api/bookings',
      carts: '/api/carts',
      orders: '/api/orders',
      favorites: '/api/favorites',
      reviews: '/api/reviews',
      staff: '/api/staff',
      interactions: '/api/interactions',
      notifications: '/api/notifications',
      ai: '/api/ai',
      admin: '/api/admin',
    },
  });
});

// API Routes
app.use('/api', apiRoutes);

// Error Handling Middleware
app.use(errorHandler);

httpServer.listen(PORT, () => {
  console.log(`🚀 FConnect Server & Socket.IO running in ${process.env.NODE_ENV || 'development'} mode on port ${PORT}`);
  console.log(`📍 API Health check: http://localhost:${PORT}/`);
});

export { app, httpServer };
export default app;

import express from 'express';
import cors from 'cors';
import morgan from 'morgan';
import apiRoutes from './routes/index.js';
import { errorHandler } from './middlewares/errorHandler.js';

const app = express();

app.use(cors());
app.use(express.json());
app.use(morgan('dev'));

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

app.use('/api', apiRoutes);
app.use(errorHandler);

export { app };
export default app;

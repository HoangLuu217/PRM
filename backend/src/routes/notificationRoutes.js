import express from 'express';
import {
  getMyNotifications,
  markNotificationRead,
} from '../controllers/notificationController.js';
import { protect } from '../middlewares/auth.js';

const router = express.Router();

router.use(protect);

router.get('/', getMyNotifications);
router.put('/:id/read', markNotificationRead);

export default router;

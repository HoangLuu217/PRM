import express from 'express';
import {
  getConversations,
  getMessages,
  sendMessage,
  deleteMessage,
} from '../controllers/chatController.js';
import { protect } from '../middlewares/auth.js';

const router = express.Router();

// Tất cả các API chat đều phải đăng nhập mới xài được
router.use(protect);

router.get('/conversations', getConversations);
router.get('/conversations/:conversationId/messages', getMessages);
router.post('/messages', sendMessage);
router.delete('/messages/:messageId', deleteMessage);

export default router;

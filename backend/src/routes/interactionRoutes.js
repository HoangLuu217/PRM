import express from 'express';
import {
  logInteraction,
  getUserInteractions,
} from '../controllers/interactionController.js';
import { protect, optionalProtect } from '../middlewares/auth.js';

const router = express.Router();

router.post('/', optionalProtect, logInteraction);
router.get('/', protect, getUserInteractions);

export default router;

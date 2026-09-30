import express from 'express';
import {
  getAIRecommendationsController,
  getAIRecommendedDishesController,
  getAINearMeRecommendationsController,
  getUserTasteProfileController,
  parseMenuWithAIController,
} from '../controllers/aiController.js';
import { protect, optionalProtect } from '../middlewares/auth.js';

const router = express.Router();

router.get('/taste-profile', protect, getUserTasteProfileController);
router.post('/parse-menu', optionalProtect, parseMenuWithAIController);
router.get('/recommendations', optionalProtect, getAIRecommendationsController);
router.get('/recommended-dishes', optionalProtect, getAIRecommendedDishesController);
router.get('/near-me', optionalProtect, getAINearMeRecommendationsController);
router.post('/near-me', optionalProtect, getAINearMeRecommendationsController);

export default router;



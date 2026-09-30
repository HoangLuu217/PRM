import express from 'express';
import {
  getAdminStats,
  getAllBusinessesAdmin,
  getPendingBusinesses,
  approveBusinessStatus,
  updateBusinessAdmin,
  deleteBusinessAdmin,
  getUsersList,
  updateUserStatus,
  getAllReviewsAdmin,
  updateReviewStatusAdmin,
  getAIInteractionsAdmin,
  getArticlesAdmin,
  updateArticleStatusAdmin,
  deleteArticleAdmin,
} from '../controllers/adminController.js';
import { protect, adminOnly } from '../middlewares/auth.js';

const router = express.Router();

router.use(protect, adminOnly);

router.get('/stats', getAdminStats);
router.get('/businesses', getAllBusinessesAdmin);
router.get('/businesses/pending', getPendingBusinesses);
router.put('/businesses/:id/status', approveBusinessStatus);
router.put('/businesses/:id', updateBusinessAdmin);
router.delete('/businesses/:id', deleteBusinessAdmin);

router.get('/users', getUsersList);
router.put('/users/:id/status', updateUserStatus);

router.get('/reviews', getAllReviewsAdmin);
router.put('/reviews/:id/status', updateReviewStatusAdmin);

router.get('/interactions', getAIInteractionsAdmin);

router.get('/articles', getArticlesAdmin);
router.put('/articles/:id/status', updateArticleStatusAdmin);
router.delete('/articles/:id', deleteArticleAdmin);

export default router;

import express from 'express';
import {
  getArticles,
  getArticleById,
  createArticle,
  updateArticle,
  deleteArticle,
  likeArticle,
  incrementArticleView,
} from '../controllers/articleController.js';
import { protect, optionalProtect } from '../middlewares/auth.js';

const router = express.Router();

router.route('/')
  .get(optionalProtect, getArticles)
  .post(protect, createArticle);

router.route('/:id')
  .get(optionalProtect, getArticleById)
  .put(protect, updateArticle)
  .delete(protect, deleteArticle);

router.route('/:id/like')
  .post(protect, likeArticle);

router.route('/:id/view')
  .post(incrementArticleView);

export default router;

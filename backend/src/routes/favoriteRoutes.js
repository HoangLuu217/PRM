import express from 'express';
import {
  addFavorite,
  removeFavorite,
  getMyFavorites,
  getFavoriteIds,
  checkFavorite,
  getMyFavoriteDishes,
  addFavoriteDish,
  removeFavoriteDish,
} from '../controllers/favoriteController.js';
import { protect } from '../middlewares/auth.js';

const router = express.Router();

router.use(protect);

// Dish favorites
router.route('/dishes')
  .get(getMyFavoriteDishes)
  .post(addFavoriteDish);

router.delete('/dishes/:dishId', removeFavoriteDish);

// Business favorites
router.get('/ids', getFavoriteIds);
router.get('/check/:businessId', checkFavorite);

router.route('/')
  .get(getMyFavorites)
  .post(addFavorite);

router.delete('/:businessId', removeFavorite);

export default router;

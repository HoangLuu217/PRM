import express from 'express';
import {
  getProducts,
  getProductById,
  createProduct,
  createBatchProducts,
  updateProduct,
  deleteProduct,
} from '../controllers/productController.js';
import { protect, staffOnly } from '../middlewares/auth.js';
import Product from '../models/Product.js';

const router = express.Router();



router.post('/batch', protect, staffOnly, createBatchProducts);

router.route('/')
  .get(getProducts)
  .post(protect, staffOnly, createProduct);

router.route('/:id')
  .get(getProductById)
  .put(protect, staffOnly, updateProduct)
  .delete(protect, staffOnly, deleteProduct);

export default router;

import express from 'express';
import {
  getTables,
  createTable,
  updateTable,
  deleteTable,
} from '../controllers/tableController.js';
import { protect, staffOnly } from '../middlewares/auth.js';

const router = express.Router();

router.route('/')
  .get(getTables)
  .post(protect, staffOnly, createTable);

router.route('/:id')
  .put(protect, staffOnly, updateTable)
  .delete(protect, staffOnly, deleteTable);

export default router;

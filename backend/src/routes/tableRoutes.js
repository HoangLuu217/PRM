import { validateIds } from '../utils/operations.js';
import express from 'express';
import {
  getTables,
  createTable,
  updateTable,
  deleteTable,
} from '../controllers/tableController.js';
import { protect, branchOwnerOnly } from '../middlewares/auth.js';

const router = express.Router();
router.use(validateIds);

router.route('/')
  .get(getTables)
  .post(protect, branchOwnerOnly, createTable);

router.route('/:id')
  .put(protect, branchOwnerOnly, updateTable)
  .delete(protect, branchOwnerOnly, deleteTable);

export default router;

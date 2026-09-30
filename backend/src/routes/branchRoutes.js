import express from 'express';
import {
  getBranches,
  getBranchById,
  createBranch,
  updateBranch,
} from '../controllers/branchController.js';
import { protect, businessOwnerOnly } from '../middlewares/auth.js';

const router = express.Router();

router.route('/')
  .get(getBranches)
  .post(protect, businessOwnerOnly, createBranch);

router.route('/:id')
  .get(getBranchById)
  .put(protect, businessOwnerOnly, updateBranch);

export default router;

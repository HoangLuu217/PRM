import express from 'express';
import {
  createStaff,
  getBranchStaff,
  updateStaff,
} from '../controllers/staffController.js';
import { protect, businessOwnerOnly } from '../middlewares/auth.js';

const router = express.Router();

router.use(protect);

router.post('/', businessOwnerOnly, createStaff);
router.get('/branch/:branchId', businessOwnerOnly, getBranchStaff);
router.put('/:id', businessOwnerOnly, updateStaff);

export default router;

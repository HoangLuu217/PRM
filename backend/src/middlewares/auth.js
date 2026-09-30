import jwt from 'jsonwebtoken';
import { User, Staff, Business, Branch } from '../models/index.js';

// Protect routes - verify JWT or active auth headers
export const protect = async (req, res, next) => {
  let token;

  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    try {
      token = req.headers.authorization.split(' ')[1];
      const decoded = jwt.verify(token, process.env.JWT_SECRET || 'fconnect_super_secret_jwt_key_2026');

      req.user = await User.findById(decoded.id).select('-password');
      if (!req.user || req.user.status === 'SUSPENDED') {
        return res.status(401).json({ success: false, message: 'Tài khoản không tồn tại hoặc đã bị khóa' });
      }
      return next();
    } catch (error) {
      console.error('Auth verification error:', error.message);
      return res.status(401).json({ success: false, message: 'Token không hợp lệ hoặc đã hết hạn' });
    }
  }

  // Header fallbacks for development/testing
  if (req.headers['x-user-id']) {
    try {
      const user = await User.findById(req.headers['x-user-id']);
      if (user && user.status !== 'SUSPENDED') {
        req.user = user;
        return next();
      }
    } catch (error) {
      console.error('Dev auth fallback error:', error.message);
    }
  }

  return res.status(401).json({ success: false, message: 'Không có quyền truy cập, vui lòng đăng nhập' });
};

// Optional protect middleware - if token or auth header exists, populates req.user; otherwise proceeds without error
export const optionalProtect = async (req, res, next) => {
  let token;

  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    try {
      token = req.headers.authorization.split(' ')[1];
      const decoded = jwt.verify(token, process.env.JWT_SECRET || 'fconnect_super_secret_jwt_key_2026');
      const user = await User.findById(decoded.id).select('-password');
      if (user && user.status !== 'SUSPENDED') {
        req.user = user;
      }
    } catch (error) {
      // Ignore invalid/expired token in optional auth
    }
  } else if (req.headers['x-user-id']) {
    try {
      const user = await User.findById(req.headers['x-user-id']);
      if (user && user.status !== 'SUSPENDED') {
        req.user = user;
      }
    } catch (e) {}
  }

  next();
};

// Role-based authorization middleware
export const authorize = (...roles) => {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: `Quyền truy cập bị từ chối. Tính năng chỉ dành cho vai trò: ${roles.join(', ')}`,
      });
    }
    next();
  };
};

export const adminOnly = authorize('ADMIN');
export const merchantOnly = authorize('OWNER', 'MERCHANT', 'ADMIN');
export const ownerOnly = authorize('OWNER', 'ADMIN');

// Business Owner authorization middleware
export const businessOwnerOnly = async (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({ success: false, message: 'Vui lòng đăng nhập' });
  }

  if (req.user.role === 'ADMIN') {
    return next();
  }

  let businessId = req.params.businessId || req.body.businessId || req.query.businessId;

  // Fallback for route params like /api/businesses/:id or /api/branches/:id
  if (!businessId && req.params.id) {
    try {
      const biz = await Business.findById(req.params.id);
      if (biz) {
        businessId = biz._id;
      } else {
        const branch = await Branch.findById(req.params.id);
        if (branch) {
          businessId = branch.businessId;
        }
      }
    } catch (e) {
      console.warn('Fallback resolve businessId error:', e.message);
    }
  }

  // Fallback for OWNER users if businessId is still missing
  if (!businessId && req.user?._id) {
    try {
      const userBiz = await Business.findOne({ ownerId: req.user._id });
      if (userBiz) {
        businessId = userBiz._id;
      }
    } catch (e) {
      console.warn('Fallback resolve businessId by ownerId error:', e.message);
    }
  }

  if (!businessId) {
    return res.status(400).json({ success: false, message: 'Thiếu businessId' });
  }

  try {
    const business = await Business.findById(businessId);
    if (!business) {
      return res.status(404).json({ success: false, message: 'Doanh nghiệp không tồn tại' });
    }

    if (business.ownerId.toString() !== req.user._id.toString()) {
      return res.status(403).json({ success: false, message: 'Bạn không phải là chủ doanh nghiệp này' });
    }

    req.business = business;
    next();
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

// Staff authorization middleware
export const staffOnly = async (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({ success: false, message: 'Vui lòng đăng nhập' });
  }

  if (req.user.role === 'ADMIN') {
    return next();
  }

  try {
    const staff = await Staff.findOne({ userId: req.user._id, status: 'ACTIVE' });
    if (!staff) {
      // Check if user is a business owner as fallback
      const isOwner = await Business.exists({ ownerId: req.user._id });
      if (isOwner) {
        return next();
      }
      return res.status(403).json({ success: false, message: 'Bạn không có quyền nhân viên trên chi nhánh này' });
    }

    req.staff = staff;
    next();
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

// JWT token generator
export const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET || 'fconnect_super_secret_jwt_key_2026', {
    expiresIn: '30d',
  });
};

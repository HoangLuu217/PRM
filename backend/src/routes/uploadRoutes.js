import express from 'express';
import multer from 'multer';
import { uploadToCloudinary } from '../config/cloudinary.js';

const router = express.Router();

// Configure multer with memory storage (max 15MB)
const storage = multer.memoryStorage();
const upload = multer({
  storage,
  limits: {
    fileSize: 15 * 1024 * 1024, // 15MB
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Chỉ chấp nhận các tệp hình ảnh (jpg, png, webp, gif...)'), false);
    }
  },
});

// @desc    Upload single image to Cloudinary
// @route   POST /api/upload
// @access  Public (hoặc Authenticated)
router.post('/', upload.single('file'), async (req, res) => {
  try {
    let fileBuffer;

    if (req.file) {
      fileBuffer = req.file.buffer;
    } else if (req.body?.image) {
      // Base64 image
      const base64Data = req.body.image.replace(/^data:image\/\w+;base64,/, '');
      fileBuffer = Buffer.from(base64Data, 'base64');
    } else {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng chọn hoặc cung cấp tệp hình ảnh để tải lên.',
      });
    }

    const folder = req.body.folder || 'fconnect/businesses';
    const result = await uploadToCloudinary(fileBuffer, folder);

    return res.status(200).json({
      success: true,
      message: 'Tải ảnh lên Cloudinary thành công!',
      url: result.secure_url,
      data: {
        url: result.secure_url,
        publicId: result.public_id,
        format: result.format,
        width: result.width,
        height: result.height,
        bytes: result.bytes,
      },
    });
  } catch (error) {
    console.error('Lỗi khi tải ảnh lên Cloudinary:', error);
    return res.status(500).json({
      success: false,
      message: error.message || 'Lỗi xử lý khi tải ảnh lên Cloudinary',
    });
  }
});

export default router;

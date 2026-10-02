import { User, Otp, Business, Branch } from '../models/index.js';
import { generateToken } from '../middlewares/auth.js';
import { sendVerificationOtpEmail } from '../services/emailService.js';
import googleMapsService from '../services/googleMapsService.js';
import { verifyRecaptchaToken } from '../services/recaptchaService.js';

// @desc    Send 6-digit OTP code to Gmail
// @route   POST /api/auth/send-email-otp
// @access  Public
export const sendEmailOtp = async (req, res) => {
  try {
    const { email, fullName, type = 'REGISTER', recaptchaToken, isResend } = req.body;

    if (!email || !email.includes('@')) {
      return res.status(400).json({ success: false, message: 'Vui lòng cung cấp địa chỉ email hợp lệ' });
    }

    const cleanEmail = email.toLowerCase().trim();

    if (type === 'REGISTER') {
      const userExists = await User.findOne({ email: cleanEmail });
      if (userExists) {
        return res.status(400).json({ success: false, message: 'Email này đã được đăng ký tài khoản' });
      }

      // Bắt buộc xác minh reCAPTCHA cho lượt gửi OTP đăng ký đầu tiên (không áp dụng khi bấm gửi lại)
      if (!isResend) {
        const recaptchaResult = await verifyRecaptchaToken(recaptchaToken, req.ip);
        if (!recaptchaResult.success) {
          return res.status(400).json({
            success: false,
            message: recaptchaResult.message || 'Xác minh reCAPTCHA thất bại. Vui lòng thử lại.',
          });
        }
      }
    } else if (type === 'RESET_PASSWORD') {
      const userExists = await User.findOne({ email: cleanEmail });
      if (!userExists) {
        return res.status(404).json({ success: false, message: 'Không tìm thấy tài khoản với địa chỉ email này.' });
      }
    }

    // Generate random 6 digit numeric code
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();

    // Delete existing OTPs for this email and type
    await Otp.deleteMany({ email: cleanEmail, type });

    // Store new OTP with 5 mins expiration
    await Otp.create({
      email: cleanEmail,
      otp: otpCode,
      type,
    });

    // Send email via SMTP / Resend service
    const actionLabel = type === 'MERCHANT_SECURITY' 
      ? 'Bảo Mật Thay Đổi Trạng Thái Quán' 
      : (type === 'RESET_PASSWORD' ? 'Đặt Lại Mật Khẩu' : 'Đăng Ký Tài Khoản');
    await sendVerificationOtpEmail(cleanEmail, otpCode, fullName || 'Quý khách', actionLabel);

    res.json({
      success: true,
      message: `Mã xác thực OTP đã được gửi đến hộp thư: ${cleanEmail}. Vui lòng kiểm tra hộp thư đến (hoặc mục Spam).`,
      data: {
        email: cleanEmail,
      },
    });
  } catch (error) {
    console.error('Send Email OTP Error:', error);
    res.status(500).json({ success: false, message: error.message || 'Lỗi gửi mã xác thực email' });
  }
};

// @desc    Reset password with OTP
// @route   POST /api/auth/reset-password
// @access  Public
export const resetPassword = async (req, res) => {
  try {
    const { email, otp, newPassword } = req.body;

    if (!email || !otp || !newPassword) {
      return res.status(400).json({ success: false, message: 'Vui lòng cung cấp đầy đủ email, mã OTP và mật khẩu mới' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ success: false, message: 'Mật khẩu mới phải có ít nhất 6 ký tự' });
    }

    const cleanEmail = email.toLowerCase().trim();
    const existingOtp = await Otp.findOne({ email: cleanEmail, otp: otp.trim(), type: 'RESET_PASSWORD' });

    if (!existingOtp) {
      return res.status(400).json({
        success: false,
        message: 'Mã OTP không chính xác hoặc đã hết hạn (hiệu lực trong 5 phút).',
      });
    }

    const user = await User.findOne({ email: cleanEmail });
    if (!user) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy tài khoản người dùng' });
    }

    user.password = newPassword;
    await user.save();

    // Xóa mã OTP sau khi đổi mật khẩu thành công
    await Otp.deleteMany({ email: cleanEmail, type: 'RESET_PASSWORD' });

    res.json({
      success: true,
      message: 'Đặt lại mật khẩu thành công! Vui lòng đăng nhập bằng mật khẩu mới.',
    });
  } catch (error) {
    console.error('Reset Password Error:', error);
    res.status(500).json({ success: false, message: error.message || 'Lỗi đặt lại mật khẩu' });
  }
};

// @desc    Verify Email OTP code
// @route   POST /api/auth/verify-email-otp
// @access  Public
export const verifyEmailOtp = async (req, res) => {
  try {
    const { email, otp, type = 'REGISTER' } = req.body;

    if (!email || !otp) {
      return res.status(400).json({ success: false, message: 'Vui lòng cung cấp email và mã OTP' });
    }

    const cleanEmail = email.toLowerCase().trim();
    const existingOtp = await Otp.findOne({ email: cleanEmail, otp: otp.trim(), type });

    if (!existingOtp) {
      return res.status(400).json({
        success: false,
        message: 'Mã OTP không chính xác hoặc đã hết hạn (hiệu lực trong 5 phút).',
      });
    }

    // Xóa mã OTP sau khi xác minh thành công (với RESET_PASSWORD sẽ xóa tại bước đổi mật khẩu)
    if (type !== 'RESET_PASSWORD') {
      await Otp.deleteOne({ _id: existingOtp._id });
    }

    res.json({
      success: true,
      message: 'Xác thực mã OTP thành công!',
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Register a new user (Customer or Merchant)
// @route   POST /api/auth/register
// @access  Public
export const registerUser = async (req, res) => {
  try {
    const {
      fullName,
      email,
      password,
      phone,
      otpCode,
      role = 'USER',
      accountType, // 'USER' | 'MERCHANT'
      isPhoneVerified,
      preferences,
      businessName,
      businessCategory,
      businessAddress,
      businessDescription,
      googleMapsUrl,
    } = req.body;

    const userRole = accountType === 'MERCHANT' || role === 'MERCHANT' ? 'MERCHANT' : 'USER';
    const cleanEmail = email ? email.toLowerCase().trim() : '';

    const userExists = await User.findOne({ email: cleanEmail });
    if (userExists) {
      return res.status(400).json({ success: false, message: 'Email đã được sử dụng' });
    }

    // Verify OTP if provided
    let isEmailVerified = false;
    if (otpCode) {
      const existingOtp = await Otp.findOne({
        email: cleanEmail,
        otp: otpCode.trim(),
        type: 'REGISTER',
      });

      if (!existingOtp) {
        return res.status(400).json({
          success: false,
          message: 'Mã xác thực OTP không chính xác hoặc đã hết hạn.',
        });
      }

      isEmailVerified = true;
      // Delete used OTP
      await Otp.deleteMany({ email: cleanEmail, type: 'REGISTER' });
    } else {
      // Nếu đăng ký trực tiếp không qua OTP, bắt buộc phải có reCAPTCHA
      const recaptchaResult = await verifyRecaptchaToken(req.body.recaptchaToken, req.ip);
      if (!recaptchaResult.success) {
        return res.status(400).json({
          success: false,
          message: recaptchaResult.message || 'Xác minh reCAPTCHA thất bại. Vui lòng thử lại.',
        });
      }
    }

    const user = await User.create({
      fullName,
      email: cleanEmail,
      password,
      phone,
      role: userRole,
      isEmailVerified,
      isPhoneVerified: Boolean(isPhoneVerified),
      preferences: preferences || {},
    });

    let createdBusiness = null;

    // If registering as a Merchant and business name is provided, initialize Business & Branch
    if (user && userRole === 'MERCHANT' && businessName) {
      try {
        const rawSlug = businessName
          .toLowerCase()
          .normalize('NFD')
          .replace(/[\u0300-\u036f]/g, '')
          .replace(/[^a-z0-9]+/g, '-')
          .replace(/(^-|-$)/g, '');
        const slug = `${rawSlug || 'quan'}-${Date.now().toString().slice(-4)}`;

        createdBusiness = await Business.create({
          ownerId: user._id,
          name: businessName.trim(),
          slug,
          description: businessDescription || `Hệ thống quán ẩm thực ${businessName.trim()}`,
          categories: [businessCategory || 'RESTAURANT'],
          status: 'APPROVED',
          logoUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=400&q=80',
          coverImageUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=800&q=80',
          googleMapsUrl: googleMapsUrl ? googleMapsUrl.trim() : '',
        });

        let branchCoords = [108.2208, 16.0678];
        if (googleMapsUrl) {
          try {
            const coords = await googleMapsService.getCoordinatesFromGoogleMapsUrl(googleMapsUrl);
            if (coords?.lat && coords?.lng) {
              branchCoords = [coords.lng, coords.lat];
            }
          } catch (cErr) {
            console.warn('Merchant branch coords parse failed:', cErr.message);
          }
        }

        // Initialize default main branch
        await Branch.create({
          businessId: createdBusiness._id,
          name: `${businessName.trim()} - Chi nhánh chính`,
          address: {
            street: businessAddress?.street || 'Trụ sở chính',
            ward: businessAddress?.ward || '',
            district: businessAddress?.district || 'Hải Châu',
            city: businessAddress?.city || 'Đà Nẵng',
          },
          location: {
            type: 'Point',
            coordinates: branchCoords,
          },
          phone: phone || '0901234567',
          googleMapsUrl: googleMapsUrl ? googleMapsUrl.trim() : '',
          status: 'ACTIVE',
        });
      } catch (bizErr) {
        console.warn('Auto-create business error during merchant registration:', bizErr.message);
      }
    }

    if (user) {
      res.status(201).json({
        success: true,
        message: userRole === 'MERCHANT' ? 'Đăng ký tài khoản Chủ Doanh Nghiệp thành công!' : 'Đăng ký tài khoản thành công!',
        data: {
          _id: user._id,
          fullName: user.fullName,
          email: user.email,
          phone: user.phone,
          isEmailVerified: user.isEmailVerified,
          isPhoneVerified: user.isPhoneVerified,
          role: user.role,
          avatarUrl: user.avatarUrl,
          preferences: user.preferences,
          business: createdBusiness,
          hasBusiness: Boolean(createdBusiness),
          token: generateToken(user._id),
        },
      });
    } else {
      res.status(400).json({ success: false, message: 'Dữ liệu người dùng không hợp lệ' });
    }
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Auth user & get token
// @route   POST /api/auth/login
// @access  Public
export const loginUser = async (req, res) => {
  try {
    const { email, password, recaptchaToken } = req.body;

    // Xác minh reCAPTCHA
    const recaptchaResult = await verifyRecaptchaToken(recaptchaToken, req.ip);
    if (!recaptchaResult.success) {
      return res.status(400).json({
        success: false,
        message: recaptchaResult.message || 'Xác minh reCAPTCHA thất bại. Vui lòng thử lại.',
      });
    }

    const user = await User.findOne({ email }).select('+password');

    if (user && (await user.matchPassword(password))) {
      const userBusiness = await Business.findOne({ ownerId: user._id });
      res.json({
        success: true,
        data: {
          _id: user._id,
          fullName: user.fullName,
          email: user.email,
          phone: user.phone,
          isPhoneVerified: user.isPhoneVerified,
          role: user.role,
          status: user.status,
          avatarUrl: user.avatarUrl,
          preferences: user.preferences,
          business: userBusiness,
          hasBusiness: Boolean(userBusiness),
          token: generateToken(user._id),
        },
      });
    } else {
      res.status(401).json({ success: false, message: 'Email hoặc mật khẩu không chính xác' });
    }
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get user profile
// @route   GET /api/auth/profile
// @access  Private
export const getUserProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user._id);

    if (user) {
      const userBusiness = await Business.findOne({ ownerId: user._id });
      res.json({
        success: true,
        data: {
          ...user.toObject(),
          business: userBusiness,
          hasBusiness: Boolean(userBusiness),
        },
      });
    } else {
      res.status(404).json({ success: false, message: 'Không tìm thấy người dùng' });
    }
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update user profile
// @route   PUT /api/auth/profile
// @access  Private
export const updateUserProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user._id);

    if (user) {
      user.fullName = req.body.fullName || user.fullName;
      user.phone = req.body.phone !== undefined ? req.body.phone : user.phone;
      user.avatarUrl = req.body.avatarUrl !== undefined ? req.body.avatarUrl : user.avatarUrl;

      // Handle password change with optional verification
      if (req.body.newPassword) {
        if (user.authProvider === 'LOCAL' && req.body.currentPassword) {
          const userWithPass = await User.findById(req.user._id).select('+password');
          if (userWithPass && userWithPass.password) {
            const isMatch = await userWithPass.matchPassword(req.body.currentPassword);
            if (!isMatch) {
              return res.status(400).json({ success: false, message: 'Mật khẩu hiện tại không chính xác' });
            }
          }
        }
        user.password = req.body.newPassword;
      } else if (req.body.password) {
        user.password = req.body.password;
      }

      if (req.body.preferences) {
        user.preferences = {
          ...(user.preferences?.toObject ? user.preferences.toObject() : user.preferences),
          ...req.body.preferences,
        };
        user.markModified('preferences');
      }

      const updatedUser = await user.save();
      const userBusiness = await Business.findOne({ ownerId: user._id });

      res.json({
        success: true,
        message: 'Cập nhật thông tin tài khoản thành công',
        data: {
          _id: updatedUser._id,
          fullName: updatedUser.fullName,
          email: updatedUser.email,
          phone: updatedUser.phone,
          role: updatedUser.role,
          status: updatedUser.status,
          authProvider: updatedUser.authProvider,
          avatarUrl: updatedUser.avatarUrl,
          preferences: updatedUser.preferences,
          createdAt: updatedUser.createdAt,
          business: userBusiness,
          hasBusiness: Boolean(userBusiness),
          token: generateToken(updatedUser._id),
        },
      });
    } else {
      res.status(404).json({ success: false, message: 'Không tìm thấy người dùng' });
    }
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Auth user with Google (Firebase)
// @route   POST /api/auth/google
// @access  Public
export const googleLogin = async (req, res) => {
  try {
    const { email, fullName, avatarUrl, googleId } = req.body;

    if (!email) {
      return res.status(400).json({ success: false, message: 'Thiếu thông tin email từ Google' });
    }

    let user = await User.findOne({ email });

    if (user) {
      let modified = false;
      if (!user.googleId && googleId) {
        user.googleId = googleId;
        modified = true;
      }
      if (avatarUrl && (!user.avatarUrl || user.avatarUrl.includes('images.unsplash.com'))) {
        user.avatarUrl = avatarUrl;
        modified = true;
      }
      if (fullName && !user.fullName) {
        user.fullName = fullName;
        modified = true;
      }
      if (modified) {
        await user.save();
      }
    } else {
      user = await User.create({
        fullName: fullName || email.split('@')[0],
        email: email.toLowerCase(),
        avatarUrl: avatarUrl || 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
        authProvider: 'GOOGLE',
        googleId: googleId || '',
        role: 'USER',
        status: 'ACTIVE',
        preferences: {
          favoriteCategories: ['CAFE', 'RESTAURANT'],
          priceRange: { min: 0, max: 1000000 },
          preferredAreas: [],
        },
      });
    }

    if (user.status === 'SUSPENDED') {
      return res.status(403).json({ success: false, message: 'Tài khoản của bạn đã bị khóa' });
    }

    const userBusiness = await Business.findOne({ ownerId: user._id });
    res.json({
      success: true,
      data: {
        _id: user._id,
        fullName: user.fullName,
        email: user.email,
        phone: user.phone,
        role: user.role,
        status: user.status,
        avatarUrl: user.avatarUrl,
        preferences: user.preferences,
        authProvider: user.authProvider,
        business: userBusiness,
        hasBusiness: Boolean(userBusiness),
        token: generateToken(user._id),
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};


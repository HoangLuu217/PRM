/**
 * Service xác thực Google reCAPTCHA v2 / v3
 */
export const verifyRecaptchaToken = async (token, remoteIp = null) => {
  const secretKey = process.env.RECAPTCHA_SECRET_KEY;

  // 1. Kiểm tra bypass token cho môi trường development
  if (token === 'dev_recaptcha_bypass_token' || token?.startsWith('dev_')) {
    if (process.env.NODE_ENV === 'development') {
      console.log('[reCAPTCHA] Bỏ qua kiểm tra với development bypass token.');
      return { success: true, bypass: true };
    }
  }

  // 2. Nếu trong môi trường phát triển chưa cấu hình secret key thì cho phép bỏ qua với log cảnh báo
  if (!secretKey) {
    if (process.env.NODE_ENV === 'development') {
      console.warn('[reCAPTCHA] RECAPTCHA_SECRET_KEY chưa được cấu hình trong .env. Tự động bỏ qua kiểm tra trong môi trường development.');
      return { success: true };
    }
    return {
      success: false,
      message: 'Hệ thống chưa cấu hình reCAPTCHA Secret Key trên máy chủ.',
    };
  }

  // 3. Thiếu token
  if (!token) {
    if (process.env.NODE_ENV === 'development') {
      console.warn('[reCAPTCHA] Không nhận được token reCAPTCHA trong môi trường development. Tự động cho phép.');
      return { success: true, devBypass: true };
    }
    return {
      success: false,
      message: 'Vui lòng xác minh Bạn không phải là người máy (reCAPTCHA).',
    };
  }

  try {
    const params = new URLSearchParams({
      secret: secretKey,
      response: token,
    });

    // Chỉ gửi remoteip nếu là IP public (tránh lỗi khi gửi ::1 hoặc 127.0.0.1 lên Google API)
    const isLocalIp =
      !remoteIp ||
      remoteIp === '::1' ||
      remoteIp === '127.0.0.1' ||
      remoteIp.startsWith('::ffff:127.0.0.1') ||
      remoteIp.startsWith('192.168.') ||
      remoteIp.startsWith('10.');

    if (remoteIp && !isLocalIp) {
      params.append('remoteip', remoteIp);
    }

    const response = await fetch('https://www.google.com/recaptcha/api/siteverify', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: params.toString(),
    });

    if (!response.ok) {
      throw new Error(`Google reCAPTCHA API phản hồi mã lỗi HTTP ${response.status}`);
    }

    const data = await response.json();

    if (data.success) {
      // reCAPTCHA v3 trả về score (0.0 -> 1.0)
      if (typeof data.score === 'number' && data.score < 0.3) {
        if (process.env.NODE_ENV === 'development') {
          console.warn(`[reCAPTCHA Dev Warning] Score thấp (${data.score}) trên localhost, cho phép trong development.`);
          return { success: true, data };
        }
        return {
          success: false,
          message: 'Hệ thống phát hiện hành vi bất thường (điểm tín nhiệm reCAPTCHA quá thấp).',
        };
      }
      return { success: true, data };
    }

    const errorCodes = data['error-codes'] || [];
    console.warn('[reCAPTCHA Failed]', errorCodes);

    // Nếu đang ở môi trường development mà Google từ chối (ví dụ: domain localhost chưa được thêm trong Google Admin Console, hoặc lệch loại key v2/v3):
    if (process.env.NODE_ENV === 'development') {
      console.warn(
        `[reCAPTCHA Dev Mode] Xác minh Google không thành công (${errorCodes.join(', ')}). Tự động bỏ qua lỗi trong development để không gián đoạn quá trình làm việc.`
      );
      return { success: true, devBypass: true, errorCodes };
    }

    let friendlyMessage = 'Xác minh reCAPTCHA không thành công. Vui lòng thử lại.';
    if (errorCodes.includes('invalid-input-secret')) {
      friendlyMessage = 'reCAPTCHA Secret Key trên máy chủ không hợp lệ.';
    } else if (errorCodes.includes('invalid-input-response')) {
      friendlyMessage = 'Mã xác minh reCAPTCHA không hợp lệ (Lệch cặp Site Key / Secret Key giữa Frontend và Backend, hoặc domain chưa được đăng ký trên Google reCAPTCHA Console).';
    } else if (errorCodes.includes('timeout-or-duplicate')) {
      friendlyMessage = 'Mã xác minh reCAPTCHA đã hết hạn hoặc đã được sử dụng. Vui lòng thử lại.';
    }

    return {
      success: false,
      message: friendlyMessage,
      errorCodes,
    };
  } catch (error) {
    console.error('[reCAPTCHA Error]', error.message);
    if (process.env.NODE_ENV === 'development') {
      console.warn('[reCAPTCHA Dev Mode] Lỗi kết nối Google reCAPTCHA, tự động bỏ qua trong môi trường development.');
      return { success: true, devBypass: true };
    }
    return {
      success: false,
      message: 'Không thể kết nối đến máy chủ xác thực reCAPTCHA. Vui lòng thử lại sau.',
    };
  }
};

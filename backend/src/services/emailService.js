import nodemailer from 'nodemailer';
import { Resend } from 'resend';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const localLogoPath = path.join(__dirname, '../assets/logo.png');

let resendClient = null;

const getResendClient = () => {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) return null;
  if (!resendClient) {
    resendClient = new Resend(apiKey.trim());
  }
  return resendClient;
};

let transporter = null;

const getTransporter = () => {
  if (transporter) return transporter;

  const service = process.env.EMAIL_SERVICE;
  const host = process.env.SMTP_HOST;
  const port = parseInt(process.env.SMTP_PORT || '587', 10);
  const user = process.env.EMAIL_USER;
  const rawPass = process.env.EMAIL_APP_PASSWORD || process.env.EMAIL_PASS;
  const pass = rawPass ? rawPass.replace(/\s+/g, '') : '';
  const secure = process.env.SMTP_SECURE === 'true' || port === 465;

  if (!user || !pass) {
    console.warn('⚠️ [EMAIL CONFIG] Chưa cấu hình đầy đủ EMAIL_USER hoặc EMAIL_APP_PASSWORD trong file .env');
    return null;
  }

  const isGmail = service === 'gmail' || host?.includes('gmail') || (!host && user.includes('@gmail.com'));

  if (isGmail) {
    transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: user.trim(),
        pass: pass.trim(),
      },
    });
  } else {
    transporter = nodemailer.createTransport({
      host: host || 'smtp.gmail.com',
      port,
      secure,
      auth: {
        user: user.trim(),
        pass: pass.trim(),
      },
      tls: {
        rejectUnauthorized: false,
      },
    });
  }

  return transporter;
};

/**
 * Chuyển đổi link chia sẻ Google Drive sang link ảnh trực tiếp có thể nhúng vào email
 * Hỗ trợ các định dạng link:
 * - https://drive.google.com/file/d/FILE_ID/view?usp=sharing
 * - https://drive.google.com/open?id=FILE_ID
 */
export const resolveGoogleDriveDirectUrl = (url) => {
  if (!url) return null;
  const trimmed = url.trim();
  const fileMatch = trimmed.match(/\/file\/d\/([a-zA-Z0-9_-]+)/);
  if (fileMatch && fileMatch[1]) {
    return `https://lh3.googleusercontent.com/d/${fileMatch[1]}`;
  }
  const idMatch = trimmed.match(/[?&]id=([a-zA-Z0-9_-]+)/);
  if (idMatch && idMatch[1]) {
    return `https://lh3.googleusercontent.com/d/${idMatch[1]}`;
  }
  return trimmed;
};

/**
 * Send 6-digit OTP verification code via Gmail with branded Logo
 * @param {string} toEmail - Recipient email
 * @param {string} otpCode - 6-digit OTP code
 * @param {string} fullName - Recipient's name
 */
export const sendVerificationOtpEmail = async (toEmail, otpCode, fullName = 'Quý khách', actionTitle = '') => {
  // Xác định nguồn ảnh Logo: Ưu tiên link từ env (Google Drive / CDN), nếu không có dùng file local CID
  const configuredLogoUrl = resolveGoogleDriveDirectUrl(process.env.APP_LOGO_URL);
  const hasLocalLogo = fs.existsSync(localLogoPath);

  let logoSrc = '';
  const attachments = [];

  if (configuredLogoUrl) {
    logoSrc = configuredLogoUrl;
  } else if (hasLocalLogo) {
    logoSrc = 'cid:fconnect_logo';
    attachments.push({
      filename: 'logo.png',
      path: localLogoPath,
      cid: 'fconnect_logo',
    });
  }

  const logoHtml = logoSrc
    ? `
      <div style="margin-bottom: 16px; text-align: center;">
        <table role="presentation" border="0" cellpadding="0" cellspacing="0" style="margin: 0 auto;">
          <tr>
            <td style="background-color: #ffffff; padding: 8px; border-radius: 18px; box-shadow: 0 6px 20px rgba(0,0,0,0.12); display: inline-block;">
              <img src="${logoSrc}" alt="FConnect" width="64" height="64" style="display: block; width: 64px; height: 64px; object-fit: cover; border-radius: 12px;" />
            </td>
          </tr>
        </table>
      </div>
    `
    : '';

  const headingText = actionTitle ? `Xác Thực ${actionTitle}` : 'Xác Thực Tài Khoản Người Dùng';

  const emailHtml = `
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mã Xác Thực FConnect</title>
  </head>
  <body style="margin: 0; padding: 0; background-color: #f1f5f9; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; -webkit-font-smoothing: antialiased;">
    <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
      <tr>
        <td align="center" style="padding: 40px 12px;">
          <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 520px; background-color: #ffffff; border-radius: 24px; box-shadow: 0 16px 36px rgba(15, 23, 42, 0.08); overflow: hidden; border: 1px solid #e2e8f0;">
            
            <!-- Header Brand Banner -->
            <tr>
              <td style="background: linear-gradient(135deg, #0ea5e9 0%, #2563eb 50%, #1d4ed8 100%); padding: 36px 24px 32px 24px; text-align: center;">
                ${logoHtml}
                <h1 style="color: #ffffff; font-size: 26px; font-weight: 800; margin: 0; letter-spacing: 0.8px; text-shadow: 0 2px 4px rgba(0,0,0,0.1);">FConnect</h1>
                <p style="color: rgba(255,255,255,0.92); font-size: 13.5px; margin: 6px 0 0 0; font-weight: 500; letter-spacing: 0.3px;">Hệ Thống Ẩm Thực & Trải Nghiệm Đặt Bàn Thông Minh</p>
              </td>
            </tr>

            <!-- Email Body Content -->
            <tr>
              <td style="padding: 36px 30px;">
                <h2 style="color: #0f172a; font-size: 19px; font-weight: 700; margin-top: 0; margin-bottom: 12px; text-align: center;">${headingText}</h2>
                <p style="color: #475569; font-size: 14.5px; line-height: 1.6; margin: 0 0 20px 0;">
                  Xin chào <strong>${fullName}</strong>,<br>
                  Cảm ơn bạn đã tin tưởng và sử dụng nền tảng <strong>FConnect</strong>. Dưới đây là mã xác thực OTP 6 số để hoàn tất thao tác của bạn:
                </p>

                <!-- OTP Code Box -->
                <div style="background: linear-gradient(180deg, #f0f7ff 0%, #e0f2fe 100%); border: 2px dashed #60a5fa; border-radius: 18px; padding: 24px 16px; text-align: center; margin: 26px 0;">
                  <span style="font-size: 36px; font-weight: 800; letter-spacing: 10px; color: #1d4ed8; font-family: 'SF Mono', Consolas, Monaco, monospace; display: inline-block;">
                    ${otpCode}
                  </span>
                  <p style="color: #2563eb; font-size: 13px; font-weight: 600; margin: 10px 0 0 0;">
                    ⏳ Mã có hiệu lực trong vòng <strong>5 phút</strong>
                  </p>
                </div>

                <!-- Security Notice -->
                <div style="background-color: #fef2f2; border-left: 4px solid #ef4444; border-radius: 8px; padding: 12px 14px; margin: 24px 0 0 0;">
                  <p style="color: #991b1b; font-size: 13px; line-height: 1.5; margin: 0;">
                    🔒 <strong>Bảo mật:</strong> Tuyệt đối không chia sẻ mã này cho bất kỳ ai. FConnect không bao giờ yêu cầu cung cấp OTP qua điện thoại hay tin nhắn.
                  </p>
                </div>
              </td>
            </tr>

            <!-- Footer -->
            <tr>
              <td style="background-color: #f8fafc; padding: 24px 28px; text-align: center; border-top: 1px solid #e2e8f0;">
                <p style="color: #64748b; font-size: 12.5px; margin: 0 0 6px 0;">
                  Bạn nhận được email này vì đã thực hiện thao tác bảo mật tại FConnect.
                </p>
                <p style="color: #94a3b8; font-size: 12px; margin: 0;">
                  © ${new Date().getFullYear()} FConnect Vietnam. All rights reserved.
                </p>
              </td>
            </tr>

          </table>
        </td>
      </tr>
    </table>
  </body>
  </html>
  `;

  const fromName = process.env.EMAIL_FROM_NAME || 'FConnect Support';
  const replyTo = process.env.EMAIL_REPLY_TO || process.env.EMAIL_USER || 'hotro.fconnet@gmail.com';
  const subject = actionTitle
    ? `[FConnect] Mã OTP ${actionTitle}: ${otpCode}`
    : `[FConnect] Mã xác thực OTP tài khoản của bạn: ${otpCode}`;

  // 1. Ưu tiên gửi qua Resend REST API (HTTPS port 443 - không bị Render chặn cổng SMTP)
  const resend = getResendClient();
  if (resend) {
    const resendFrom = process.env.RESEND_FROM ||
      (process.env.EMAIL_FROM && !process.env.EMAIL_FROM.includes('@gmail.com')
        ? `"${fromName}" <${process.env.EMAIL_FROM}>`
        : `"${fromName}" <no-reply@fconnet.hoangluu.id.vn>`);

    try {
      const { data, error } = await resend.emails.send({
        from: resendFrom,
        to: toEmail,
        reply_to: replyTo,
        subject,
        html: emailHtml,
      });

      if (error) {
        console.error('❌ [RESEND API ERROR]:', error);
        if (error.statusCode === 403 && error.message?.includes('testing emails to your own email address')) {
          throw new Error(`Resend ở chế độ Sandbox (chưa verify domain) chỉ cho phép gửi đến email quản trị: ${error.message}. Để gửi đến khách hàng bất kỳ, vui lòng verify domain tại resend.com/domains.`);
        }
        throw new Error(`Lỗi Resend API: ${error.message || JSON.stringify(error)}`);
      }

      console.log(`✅ [EMAIL RESEND] Đã gửi mã OTP thực đến ${toEmail} thành công (ID: ${data?.id})`);
      return { sent: true, messageId: data?.id, provider: 'resend' };
    } catch (resendErr) {
      console.warn(`⚠️ [RESEND FAILED] ${resendErr.message}`);
      const mailTransporter = getTransporter();
      if (!mailTransporter) {
        throw resendErr;
      }
      console.log('🔄 Đang thử fallback gửi qua SMTP...');
    }
  }

  // 2. Gửi qua SMTP (Nodemailer) nếu không dùng Resend hoặc Resend fallback
  const mailTransporter = getTransporter();
  if (!mailTransporter) {
    throw new Error('Chưa cấu hình dịch vụ email (Cần RESEND_API_KEY hoặc EMAIL_USER & EMAIL_APP_PASSWORD trong file .env)');
  }

  const fromAddress = process.env.EMAIL_FROM || process.env.EMAIL_USER;
  const mailOptions = {
    from: `"${fromName}" <${fromAddress}>`,
    replyTo,
    to: toEmail,
    subject,
    html: emailHtml,
    attachments,
  };

  try {
    const info = await mailTransporter.sendMail(mailOptions);
    console.log(`✅ [EMAIL OTP THỰC TẾ] Đã gửi mã OTP thực đến ${toEmail} qua SMTP: ${info.messageId}`);
    return { sent: true, messageId: info.messageId, provider: 'smtp' };
  } catch (error) {
    console.error(`❌ [EMAIL OTP ERROR] Lỗi gửi email qua SMTP:`, error.message);
    throw new Error(`Không thể gửi email đến ${toEmail}: ${error.message}`);
  }
};

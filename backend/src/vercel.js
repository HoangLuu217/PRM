import app from './app.js';
import { connectDB } from './config/db.js';

export default async function handler(req, res) {
  try {
    if (!process.env.JWT_SECRET) {
      throw new Error('JWT_SECRET must be configured in Vercel Environment Variables');
    }

    await connectDB();
    return app(req, res);
  } catch (error) {
    console.error(`❌ Vercel request initialization failed: ${error.message}`);
    return res.status(500).json({
      success: false,
      message: 'Backend initialization failed. Check the Vercel function logs and environment variables.',
    });
  }
}

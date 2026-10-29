import http from 'http';
import dotenv from 'dotenv';
import app from './app.js';
import { connectDB } from './config/db.js';
import { initSocket } from './socket.js';

dotenv.config();

const PORT = process.env.PORT || 5000;
const httpServer = http.createServer(app);

initSocket(httpServer);

connectDB().catch((error) => {
  console.error(`❌ MongoDB startup failed: ${error.message}`);
});

httpServer.listen(PORT, () => {
  console.log(`🚀 FConnect Server & Socket.IO running in ${process.env.NODE_ENV || 'development'} mode on port ${PORT}`);
  console.log(`📍 API Health check: http://localhost:${PORT}/`);
});

export { app, httpServer };
export default app;

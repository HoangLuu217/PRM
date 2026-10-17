import jwt from 'jsonwebtoken';
import { User, Business } from './models/index.js';
import { Server } from 'socket.io';

let io = null;

export const initSocket = (httpServer) => {
  io = new Server(httpServer, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      credentials: true,
    },
    transports: ['websocket', 'polling'],
  });

  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token || socket.handshake.headers.authorization?.replace(/^Bearer /, '');
      const decoded = jwt.verify(token, process.env.JWT_SECRET || 'fconnect_super_secret_jwt_key_2026');
      const user = await User.findById(decoded.id).select('_id role status');
      if (!user || user.status !== 'ACTIVE') return next(new Error('Unauthorized'));
      socket.data.user = user;
      next();
    } catch { next(new Error('Unauthorized')); }
  });
  io.on('connection', (socket) => {
    socket.join('user:' + socket.data.user._id);

    console.log(`🔌 [Socket.IO] Client connected: ${socket.id}`);

    // Cho phép client join room của 1 quán ăn cụ thể
    socket.on('join:business', async (businessId, ack) => {
      try {
        const user = socket.data.user;
        const allowed = user.role === 'ADMIN' || await Business.exists({ _id: businessId, ownerId: user._id });
        if (!allowed) {
          if (typeof ack === 'function') ack({ success: false, message: 'Forbidden' });
          return;
        }
        await socket.join('business:' + businessId);
        if (typeof ack === 'function') ack({ success: true });
      } catch {
        if (typeof ack === 'function') ack({ success: false, message: 'Invalid business' });
      }
    });

    socket.on('leave:business', (businessId) => {
      if (businessId) {
        const room = `business:${businessId}`;
        socket.leave(room);
        console.log(`🔌 [Socket.IO] ${socket.id} left room ${room}`);
      }
    });

    socket.on('disconnect', (reason) => {
      console.log(`🔌 [Socket.IO] Client disconnected: ${socket.id} (${reason})`);
    });
  });

  return io;
};

export const getIO = () => {
  if (!io) {
    console.warn('⚠️ [Socket.IO] io has not been initialized yet');
  }
  return io;
};

// Bắn event cập nhật thông tin quán (Bật/tắt đặt bàn, mở/đóng cửa, giờ giấc, thông tin thương hiệu)
export const emitBusinessUpdate = (business) => {
  if (!io || !business) return;
  const businessId = (business._id || business.id || business).toString();

  // Phát tín hiệu tới room riêng của quán
  io.to(`business:${businessId}`).emit('business:updated', business);
  // Đồng thời phát toàn cục để trang chủ (App.jsx) cập nhật danh sách quán ngay tức khắc
  io.emit('business:updated', business);
  console.log(`⚡ [Socket.IO] Emitted business:updated for business ${businessId}`);
};

// Bắn event khi có đặt bàn mới hoặc thay đổi trạng thái đặt bàn
export const emitBookingUpdate = (businessId, booking, type = 'created') => {
  if (!io || !businessId) return;
  const bId = businessId.toString();
  const eventName = type === 'created' ? 'booking:created' : 'booking:statusUpdated';

  io.to(`business:${bId}`).emit(eventName, booking);
  const userId = booking.userId?._id || booking.userId;
  if (userId) io.to('user:' + userId).emit(eventName, { businessId: bId, booking });
  console.log(`⚡ [Socket.IO] Emitted ${eventName} for business ${bId}`);
};

// Bắn event khi quán bị xóa
export const emitBusinessDelete = (businessId) => {
  if (!io || !businessId) return;
  const bId = businessId.toString();
  io.to(`business:${bId}`).emit('business:deleted', { businessId: bId });
  io.emit('business:deleted', { businessId: bId });
  console.log(`⚡ [Socket.IO] Emitted business:deleted for business ${bId}`);
};

export default {
  initSocket,
  getIO,
  emitBusinessUpdate,
  emitBookingUpdate,
  emitBusinessDelete,
};

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

  io.on('connection', (socket) => {
    console.log(`🔌 [Socket.IO] Client connected: ${socket.id}`);

    // Cho phép client join room của 1 quán ăn cụ thể
    socket.on('join:business', (businessId) => {
      if (businessId) {
        const room = `business:${businessId}`;
        socket.join(room);
        console.log(`🔌 [Socket.IO] ${socket.id} joined room ${room}`);
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
  io.emit(eventName, { businessId: bId, booking });
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

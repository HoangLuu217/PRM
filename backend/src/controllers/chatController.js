import mongoose from 'mongoose';
import { Business, Conversation, Message, Notification, User } from '../models/index.js';
import { sendPushToUser } from '../services/pushNotificationService.js';

// @desc    Lấy danh sách các cuộc hội thoại của user hiện tại
// @route   GET /api/chat/conversations
// @access  Private
export const getConversations = async (req, res) => {
  try {
    const userId = req.user._id;

    // Tìm các business mà user là chủ sở hữu
    const myBusinesses = await Business.find({ ownerId: userId }).select('_id');
    const myBusinessIds = myBusinesses.map((b) => b._id.toString());

    let queryConditions = [];
    if (myBusinessIds.length > 0) {
      // User là chủ quán: lấy các cuộc hội thoại của quán mình
      queryConditions.push({ businessId: { $in: myBusinesses.map((b) => b._id) } });
    }
    // User cũng là khách hàng: lấy các cuộc hội thoại mà mình là customer
    queryConditions.push({ customerId: userId });

    const rawConversations = await Conversation.find({
      $or: queryConditions,
    })
      .populate('customerId', 'fullName avatarUrl phone')
      .populate('businessId', 'name logoUrl')
      .sort({ lastMessageAt: -1 });

    // Lọc và dọn dẹp các conversation không hợp lệ hoặc bị trùng lặp:
    const validConversations = [];
    const seenBusinessKeys = new Set();
    const seenCustomerKeys = new Set();

    for (const conv of rawConversations) {
      const isOwnerOfConv = conv.businessId && myBusinessIds.includes(
        (conv.businessId._id || conv.businessId).toString()
      );

      if (isOwnerOfConv) {
        // Chủ quán xem danh sách khách chat với mình:
        // Đảm bảo khách hàng hợp lệ và không trùng lặp cùng 1 khách
        if (!conv.customerId) {
          continue;
        }
        const cKey = (conv.customerId._id || conv.customerId).toString();
        if (seenCustomerKeys.has(cKey)) {
          continue;
        }
        seenCustomerKeys.add(cKey);
        validConversations.push(conv);
      } else {
        // Khách hàng xem danh sách các quán mình đã nhắn tin:
        // 1. Phải có businessId hợp lệ và đã populate được name!
        if (!conv.businessId || !conv.businessId.name) {
          // Xóa conversation lỗi (như businessId bị gán nhầm User ID) khỏi database
          await Conversation.findByIdAndDelete(conv._id).catch(() => {});
          continue;
        }

        // 2. Tránh trùng lặp 2 mục cùng 1 quán
        const bKey = conv.businessId._id.toString();
        if (seenBusinessKeys.has(bKey)) {
          // Trùng quán -> xóa bớt bản ghi cũ hơn
          await Conversation.findByIdAndDelete(conv._id).catch(() => {});
          continue;
        }
        seenBusinessKeys.add(bKey);
        validConversations.push(conv);
      }
    }

    res.status(200).json({ success: true, data: validConversations });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Lấy tin nhắn trong 1 cuộc hội thoại cụ thể
// @route   GET /api/chat/conversations/:conversationId/messages
// @access  Private
export const getMessages = async (req, res) => {
  try {
    const { conversationId } = req.params;
    const userId = req.user._id;

    let targetConvId = conversationId;

    if (mongoose.Types.ObjectId.isValid(conversationId)) {
      // 1. Kiểm tra xem conversationId này có phải là ID của Conversation không
      let conv = await Conversation.findById(conversationId);

      // 2. Nếu không tìm thấy Conversation bằng id đó,
      // nghĩa là client đang truyền businessId vào (khách chat trực tiếp từ trang chi tiết quán)
      if (!conv) {
        conv = await Conversation.findOne({
          $or: [
            { customerId: userId, businessId: conversationId },
            { customerId: conversationId, businessId: userId },
          ],
        });
      }

      if (conv) {
        targetConvId = conv._id;

        // Chuẩn hóa tin nhắn bot tự động cũ nếu từng bị lưu senderId là khách hàng
        const biz = await Business.findById(conv.businessId).select('ownerId');
        let ownerIdToSet = biz?.ownerId;
        if (!ownerIdToSet) {
          const anyOwner = await User.findOne({ role: { $in: ['MERCHANT', 'OWNER'] } });
          if (anyOwner) ownerIdToSet = anyOwner._id;
        }
        if (ownerIdToSet) {
          await Message.updateMany(
            {
              conversationId: targetConvId,
              text: { $regex: /^(Dạ|Dạ quán|Dạ cảm ơn quý khách)/i },
            },
            { senderId: ownerIdToSet }
          ).catch(() => {});
        }
      } else {
        // Khách hàng chưa từng nhắn tin với quán này: trả về mảng rỗng và conversationId null
        return res.status(200).json({ success: true, data: [], conversationId: null });
      }
    } else {
      return res.status(200).json({ success: true, data: [], conversationId: null });
    }

    const messages = await Message.find({
      conversationId: targetConvId,
      isDeleted: { $ne: true },
    })
      .populate('senderId', 'fullName avatarUrl role')
      .sort({ createdAt: 1 }); // Xếp từ cũ đến mới

    res.status(200).json({ success: true, data: messages, conversationId: targetConvId });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Gửi tin nhắn mới
// @route   POST /api/chat/messages
// @access  Private
export const sendMessage = async (req, res) => {
  try {
    const senderId = req.user._id;
    const { receiverId, text, imageUrl, isBusinessReceiver, isBotReply } = req.body;

    if (!text && !imageUrl) {
      return res.status(400).json({ success: false, message: 'Nội dung tin nhắn không được rỗng' });
    }

    // 1. Xác định Conversation dựa vào conversationId hoặc customerId & businessId
    let conversation;
    if (req.body.conversationId && mongoose.Types.ObjectId.isValid(req.body.conversationId)) {
      conversation = await Conversation.findById(req.body.conversationId);
    }

    if (!conversation) {
      let customerId, businessId;
      if (isBusinessReceiver) {
        customerId = senderId;
        businessId = receiverId || req.body.businessId;
      } else {
        customerId = receiverId;
        if (req.body.businessId) {
          businessId = req.body.businessId;
        } else {
          const biz = await Business.findOne({ ownerId: senderId });
          businessId = biz ? biz._id : null;
        }
      }

      if (customerId && businessId) {
        conversation = await Conversation.findOne({ customerId, businessId });
        if (!conversation) {
          conversation = await Conversation.create({
            customerId,
            businessId,
          });
        }
      }
    }

    if (!conversation) {
      return res.status(400).json({ success: false, message: 'Không thể xác định cuộc trò chuyện' });
    }

    // Xác định người gửi thực tế của tin nhắn
    let actualSenderId = senderId;
    if (isBotReply) {
      // Tin nhắn bot tự động đại diện cho Quán ăn / Chủ quán:
      const biz = await Business.findById(conversation.businessId).select('ownerId');
      if (biz && biz.ownerId) {
        actualSenderId = biz.ownerId;
      } else {
        const anyOwner = await User.findOne({ role: { $in: ['MERCHANT', 'OWNER'] } });
        if (anyOwner) actualSenderId = anyOwner._id;
      }
    }

    // 2. Tạo Message
    const message = await Message.create({
      conversationId: conversation._id,
      senderId: actualSenderId,
      text: text || '',
      imageUrl: imageUrl || null,
    });

    // 3. Cập nhật lastMessage cho Conversation để hiện ra ngoài danh sách
    conversation.lastMessage = text || (imageUrl ? '[Hình ảnh]' : '');
    conversation.lastMessageAt = new Date();
    await conversation.save();

    // 4. Nếu là bot trả lời tự động thì không gửi thông báo push
    if (isBotReply) {
      return res.status(201).json({ success: true, data: message });
    }

    // Nếu chủ quán thực tế đã nhắn tin phản hồi khách, tự động ẩn/xóa tin nhắn bot tự động trong cuộc hội thoại để giao diện gọn gàng
    if (!isBusinessReceiver) {
      await Message.updateMany(
        {
          conversationId: conversation._id,
          text: { $regex: /^(Dạ|Dạ quán|Dạ cảm ơn quý khách)/i },
        },
        { isDeleted: true }
      ).catch(() => {});
    }

    // 5. Xác định người nhận thông báo thực tế
    let targetNotifyUserId = receiverId;
    if (isBusinessReceiver) {
      const biz = await Business.findById(conversation.businessId).select('ownerId');
      if (biz && biz.ownerId) {
        targetNotifyUserId = biz.ownerId;
      } else {
        const anyOwner = await User.findOne({ role: { $in: ['MERCHANT', 'OWNER'] } });
        if (anyOwner) targetNotifyUserId = anyOwner._id;
      }
    } else {
      targetNotifyUserId = conversation.customerId;
    }

    // 6. Tự động bắn Notification trong app cho người nhận (kèm businessId để chủ quán luôn nhận được)
    await Notification.create({
      userId: targetNotifyUserId,
      businessId: conversation.businessId,
      type: 'NEW_MESSAGE',
      title: 'Tin nhắn mới',
      message: `Bạn có tin nhắn mới từ ${req.user.fullName || 'khách hàng'}`,
      referenceId: conversation._id,
    }).catch((err) => console.error('Notification new message error:', err));

    // 7. Gửi Push Notification trực tiếp về điện thoại (Chỉ gửi khi Chủ quán nhắn tin phản hồi khách hàng)
    if (!isBusinessReceiver) {
      sendPushToUser(
        targetNotifyUserId,
        `Tin nhắn từ ${req.user.fullName || 'Quán ăn'}`,
        text || '[Hình ảnh]',
        { conversationId: conversation._id.toString(), type: 'CHAT_MESSAGE' }
      ).catch((err) => console.error('Push error:', err));
    }

    res.status(201).json({ success: true, data: message });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Thu hồi/Xóa tin nhắn
// @route   DELETE /api/chat/messages/:messageId
// @access  Private
export const deleteMessage = async (req, res) => {
  try {
    const { messageId } = req.params;
    const userId = req.user._id;

    const message = await Message.findById(messageId);
    
    if (!message) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy tin nhắn' });
    }

    // Kiểm tra xem user hiện tại có phải là người gửi tin nhắn không
    if (message.senderId.toString() !== userId.toString()) {
      return res.status(403).json({ success: false, message: 'Bạn chỉ có thể thu hồi tin nhắn của chính mình' });
    }

    // Đánh dấu là đã xóa (Soft Delete)
    message.isDeleted = true;
    message.text = 'Tin nhắn đã bị thu hồi';
    await message.save();

    res.status(200).json({ success: true, message: 'Thu hồi tin nhắn thành công', data: message });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

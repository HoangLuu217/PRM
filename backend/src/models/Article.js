import mongoose from 'mongoose';

const articleSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: [true, 'Vui lòng nhập tiêu đề bài viết'],
      trim: true,
    },
    slug: {
      type: String,
      lowercase: true,
      trim: true,
    },
    summary: {
      type: String,
      required: [true, 'Vui lòng nhập tóm tắt ngắn'],
      trim: true,
    },
    content: {
      type: mongoose.Schema.Types.Mixed,
      required: [true, 'Vui lòng nhập nội dung bài viết'],
    },
    category: {
      type: String,
      default: 'Review Quán Hot',
    },
    coverImage: {
      type: String,
      default: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=800&q=80',
    },
    authorId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    authorName: {
      type: String,
      default: 'Chủ quán FConnect',
    },
    authorRole: {
      type: String,
      default: 'Chủ nhà hàng / Đối tác F&B',
    },
    authorAvatar: {
      type: String,
      default: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
    },
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
    },
    branchId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Branch',
    },
    tags: [
      {
        type: String,
        trim: true,
      },
    ],
    views: {
      type: Number,
      default: 0,
    },
    likes: {
      type: Number,
      default: 0,
    },
    likedBy: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
      },
    ],
    readTime: {
      type: String,
      default: '4 phút đọc',
    },
    isFeatured: {
      type: Boolean,
      default: false,
    },
    status: {
      type: String,
      enum: ['PUBLISHED', 'DRAFT', 'ARCHIVED'],
      default: 'PUBLISHED',
    },
  },
  {
    timestamps: true,
  }
);

articleSchema.index({ title: 'text', summary: 'text', content: 'text' });
articleSchema.index({ businessId: 1 });
articleSchema.index({ authorId: 1 });
articleSchema.index({ category: 1 });
articleSchema.index({ likedBy: 1 });

export const Article = mongoose.model('Article', articleSchema);

import 'package:flutter/material.dart';

enum NotificationCategory {
  booking,
  order,
  chat,
  system,
}

class NotificationItem {
  final String id;
  final String type;
  final String title;
  final String message;
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.referenceId,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: json['type']?.toString() ?? 'SYSTEM',
      title: json['title']?.toString() ?? 'Thông báo',
      message: json['message']?.toString() ?? '',
      referenceId: json['referenceId']?.toString(),
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      message: message,
      referenceId: referenceId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    final hourStr = createdAt.hour.toString().padLeft(2, '0');
    final minStr = createdAt.minute.toString().padLeft(2, '0');
    final timeOnly = '$hourStr:$minStr';

    if (diff.inSeconds < 60 && diff.inSeconds >= 0) {
      return 'Vừa xong • $timeOnly';
    } else if (diff.inMinutes < 60 && diff.inMinutes >= 0) {
      return '${diff.inMinutes}p trước • $timeOnly';
    } else if (diff.inHours < 24 && createdAt.day == now.day && createdAt.month == now.month && createdAt.year == now.year) {
      return 'Hôm nay $timeOnly';
    } else if (createdAt.year == now.year && createdAt.month == now.month && createdAt.day == now.day - 1) {
      return 'Hôm qua $timeOnly';
    } else {
      final dayStr = createdAt.day.toString().padLeft(2, '0');
      final monthStr = createdAt.month.toString().padLeft(2, '0');
      return '$dayStr/$monthStr $timeOnly';
    }
  }

  String get specificTime {
    final dayStr = createdAt.day.toString().padLeft(2, '0');
    final monthStr = createdAt.month.toString().padLeft(2, '0');
    final yearStr = createdAt.year.toString();
    final hourStr = createdAt.hour.toString().padLeft(2, '0');
    final minStr = createdAt.minute.toString().padLeft(2, '0');
    return '$hourStr:$minStr • $dayStr/$monthStr/$yearStr';
  }

  NotificationCategory get category {
    if (type.startsWith('BOOKING')) return NotificationCategory.booking;
    if (type.startsWith('ORDER')) return NotificationCategory.order;
    if (type == 'NEW_MESSAGE') return NotificationCategory.chat;
    return NotificationCategory.system;
  }

  String get categoryLabel {
    switch (category) {
      case NotificationCategory.booking:
        return 'Đặt bàn';
      case NotificationCategory.order:
        return 'Đơn hàng';
      case NotificationCategory.chat:
        return 'Tin nhắn';
      case NotificationCategory.system:
        return 'Hệ thống';
    }
  }

  IconData get icon {
    switch (type) {
      case 'BOOKING_CONFIRMED':
        return Icons.event_available_rounded;
      case 'BOOKING_CANCELLED':
      case 'BOOKING_REJECTED':
        return Icons.event_busy_rounded;
      case 'BOOKING_CHECKED_IN':
      case 'BOOKING_COMPLETED':
        return Icons.table_restaurant_rounded;
      case 'ORDER_CONFIRMED':
        return Icons.receipt_long_rounded;
      case 'ORDER_PREPARING':
        return Icons.soup_kitchen_rounded;
      case 'ORDER_READY':
        return Icons.room_service_rounded;
      case 'ORDER_SERVED':
      case 'ORDER_COMPLETED':
        return Icons.check_circle_outline_rounded;
      case 'ORDER_CANCELLED':
        return Icons.cancel_outlined;
      case 'NEW_MESSAGE':
        return Icons.forum_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color get color {
    switch (type) {
      case 'BOOKING_CONFIRMED':
      case 'ORDER_READY':
      case 'ORDER_COMPLETED':
        return const Color(0xFF10B981); // Emerald Green
      case 'ORDER_PREPARING':
        return const Color(0xFFF59E0B); // Amber / Warm Orange
      case 'NEW_MESSAGE':
        return const Color(0xFF0072FF); // Electric Blue
      case 'BOOKING_CANCELLED':
      case 'BOOKING_REJECTED':
      case 'ORDER_CANCELLED':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF6366F1); // Indigo
    }
  }

  Color get backgroundColor {
    return color.withValues(alpha: 0.12);
  }
}

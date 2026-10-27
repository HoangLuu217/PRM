import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/notification_item_model.dart';
import '../../../providers/notification_provider.dart';

class CustomerNotificationScreen extends StatefulWidget {
  const CustomerNotificationScreen({super.key});

  @override
  State<CustomerNotificationScreen> createState() => _CustomerNotificationScreenState();
}

class _CustomerNotificationScreenState extends State<CustomerNotificationScreen> {
  String _selectedFilter = 'Tất cả';

  final List<Map<String, dynamic>> _filterTabs = [
    {'label': 'Tất cả', 'icon': Icons.all_inbox_rounded},
    {'label': 'Đặt bàn', 'icon': Icons.table_restaurant_rounded},
    {'label': 'Đơn hàng', 'icon': Icons.receipt_long_rounded},
    {'label': 'Tin nhắn', 'icon': Icons.forum_rounded},
    {'label': 'Hệ thống', 'icon': Icons.campaign_outlined},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
    });
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays == 1) return 'Hôm qua';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final notiProvider = Provider.of<NotificationProvider>(context);
    final filteredList = notiProvider.getFilteredNotifications(_selectedFilter);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      appBar: _buildAppBar(notiProvider),
      body: SafeArea(
        child: Column(
          children: [
            // Thanh chuyển đổi bộ lọc thông báo
            _buildFilterTabs(notiProvider),

            // Danh sách thông báo
            Expanded(
              child: notiProvider.isLoading && notiProvider.notifications.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF0072FF)),
                    )
                  : RefreshIndicator(
                      onRefresh: notiProvider.fetchNotifications,
                      color: const Color(0xFF0072FF),
                      child: filteredList.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              itemCount: filteredList.length,
                              itemBuilder: (context, index) {
                                final item = filteredList[index];
                                return _buildNotificationCard(item, notiProvider);
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // APPBAR
  // ==========================================
  PreferredSizeWidget _buildAppBar(NotificationProvider provider) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          const Text(
            'Thông báo',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (provider.unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${provider.unreadCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        // Nút bắn Push Notification thử nghiệm
        IconButton(
          icon: const Icon(Icons.notifications_active_rounded, color: Color(0xFFF59E0B)),
          tooltip: 'Bắn thông báo thử vào máy',
          onPressed: () async {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đang gửi lệnh Push Notification qua Firebase...'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(milliseconds: 1000),
              ),
            );
            final ok = await provider.sendTestPush();
            if (mounted && ok) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🔔 Đã bắn thông báo thành công! Kiểm tra thanh trạng thái máy ảo.'),
                  backgroundColor: Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),

        // Nút đánh dấu tất cả đã đọc
        IconButton(
          icon: const Icon(Icons.done_all_rounded, color: Color(0xFF0072FF)),
          tooltip: 'Đánh dấu tất cả đã đọc',
          onPressed: provider.unreadCount > 0
              ? () {
                  provider.markAllAsRead();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã đánh dấu tất cả thông báo là đã đọc'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              : null,
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  // ==========================================
  // FILTER TABS BAR
  // ==========================================
  Widget _buildFilterTabs(NotificationProvider provider) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: _filterTabs.map((tab) {
            final label = tab['label'] as String;
            final icon = tab['icon'] as IconData;
            final isSelected = _selectedFilter == label;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 15,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 5),
                    Text(label),
                  ],
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF0072FF),
                backgroundColor: const Color(0xFFF1F5F9),
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF0072FF) : const Color(0xFFE2E8F0),
                  ),
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() => _selectedFilter = label);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ==========================================
  // NOTIFICATION CARD
  // ==========================================
  Widget _buildNotificationCard(NotificationItem item, NotificationProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: item.isRead ? Colors.white : const Color(0xFFF0F7FF), // Nhẹ nhàng highlight chưa đọc
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isRead ? const Color(0xFFE2E8F0) : const Color(0xFFBFDBFE),
          width: item.isRead ? 1 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (!item.isRead) {
              provider.markAsRead(item.id);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon tròn phân loại màu
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: item.backgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item.icon,
                    color: item.color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Nội dung thông báo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                color: const Color(0xFF0F172A),
                                fontSize: 14.5,
                                fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!item.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF0072FF),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.message,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.categoryLabel,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            _formatTimeAgo(item.createdAt),
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // EMPTY STATE
  // ==========================================
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 48,
              color: Color(0xFF0072FF),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có thông báo nào',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Các cập nhật đơn hàng, đặt bàn và tin nhắn\nsẽ hiển thị ở đây.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

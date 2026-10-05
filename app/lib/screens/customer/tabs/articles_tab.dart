import 'package:flutter/material.dart';

class ArticlesTab extends StatelessWidget {
  const ArticlesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> articles = [
      {
        'title': 'Top 10 Quán Hải Sản Tươi Sống Ngon Nức Tiếng Bờ Biển Mỹ Khê Đà Nẵng',
        'author': 'FConnect Food Critic',
        'date': 'Hôm nay',
        'image': 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=600&q=80',
        'readTime': '4 phút đọc',
      },
      {
        'title': 'Bí Quyết Nấu Mì Quảng Ếch Chuẩn Vị Xứ Quảng Của Các Đầu Bếp Lão Làng',
        'author': 'Master Chef FConnect',
        'date': 'Hôm qua',
        'image': 'https://images.unsplash.com/photo-1569058242253-92a9c755a0ec?auto=format&fit=crop&w=600&q=80',
        'readTime': '6 phút đọc',
      },
      {
        'title': 'Khám Phá Các Quán Cà Phê View Ngắm Trọn Sông Hàn & Cầu Rồng Lung Linh',
        'author': 'Reviewer Đà Nẵng',
        'date': '2 ngày trước',
        'image': 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=600&q=80',
        'readTime': '3 phút đọc',
      },
      {
        'title': 'Khám Phá Thiên Đường Ẩm Thực Chợ Cồn & Chợ Hàn: Ăn Gì Ở Đâu?',
        'author': 'FConnect Tour Guide',
        'date': '3 ngày trước',
        'image': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=600&q=80',
        'readTime': '5 phút đọc',
      },
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: Color(0xFF0072FF), size: 24),
            const SizedBox(width: 8),
            const Text(
              'Bài Viết & Cẩm Nang Ẩm Thực',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Cập nhật xu hướng ẩm thực, ưu đãi và đánh giá chuyên sâu',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        const SizedBox(height: 16),
        ...articles.map((art) => Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1.5,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  art['image']!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 160,
                    color: const Color(0xFFEFF6FF),
                    child: const Icon(Icons.restaurant, color: Color(0xFF0072FF), size: 40),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      art['title']!,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text('✍️ ${art['author']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            art['readTime']!,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF0072FF), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}

import 'package:flutter/material.dart';

class AiSommelierTab extends StatelessWidget {
  final VoidCallback? onExploreRecommendations;

  const AiSommelierTab({
    super.key,
    this.onExploreRecommendations,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0072FF).withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome, size: 44, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'Trợ Lý Ẩm Thực Thông Minh FConnect',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'AI Sommelier & Food Critic phân tích sở thích khẩu vị, ngân sách và thời tiết để đề xuất món ngon hoàn hảo nhất cho bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onExploreRecommendations,
              icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
              label: const Text(
                'Xem danh sách AI đề xuất ngay',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0072FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

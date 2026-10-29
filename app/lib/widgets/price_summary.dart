import 'package:flutter/material.dart';

class PriceSummary extends StatelessWidget {
  final double subtotal;
  final double discount;
  final double deliveryFee;
  final double total;

  const PriceSummary({
    super.key,
    required this.subtotal,
    this.discount = 0.0,
    this.deliveryFee = 0.0,
    required this.total,
  });

  String _formatPrice(double price) {
    final intPrice = price.toInt();
    return '${intPrice.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')}đ';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildRow('Tạm tính', _formatPrice(subtotal)),
          if (discount > 0) ...[
            const SizedBox(height: 8),
            _buildRow('Giảm giá', '-${_formatPrice(discount)}', color: Colors.green),
          ],
          if (deliveryFee > 0) ...[
            const SizedBox(height: 8),
            _buildRow('Phí dịch vụ', _formatPrice(deliveryFee)),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          _buildRow(
            'Tổng cộng',
            _formatPrice(total),
            isBold: true,
            fontSize: 18,
            color: Colors.deepOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 14,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? Colors.black87 : Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? (isBold ? Colors.deepOrange : Colors.black87),
          ),
        ),
      ],
    );
  }
}

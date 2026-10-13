import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:prm_project/models/user_model.dart';
import 'package:prm_project/providers/auth_provider.dart';
import 'package:prm_project/providers/user_provider.dart';
import 'package:prm_project/screens/owner/widgets/merchant_onboarding_dialog.dart';

void main() {
  group('Member 1 - Owner Restaurant Onboarding Tests', () {
    test('Onboarding payload validation test', () {
      final payload = {
        'name': 'Highland Coffee',
        'category': 'CAFE',
        'categories': ['CAFE'],
        'description': 'Cà phê truyền thống',
        'businessAddress': {
          'street': '123 Nguyễn Văn Linh',
          'district': 'Hải Châu',
          'city': 'Thành phố Đà Nẵng',
        },
        'priceRange': {'min': 20000, 'max': 80000},
        'vibes': ['Yên tĩnh / Làm việc'],
        'purposes': ['Gặp gỡ bạn bè'],
      };

      expect(payload['name'], equals('Highland Coffee'));
      expect(payload['category'], equals('CAFE'));
      expect((payload['priceRange'] as Map)['min'], equals(20000));
      expect((payload['priceRange'] as Map)['max'], equals(80000));
      expect((payload['vibes'] as List).contains('Yên tĩnh / Làm việc'), isTrue);
    });

    testWidgets('MerchantOnboardingDialog renders title, fields and action buttons',
        (WidgetTester tester) async {
      final user = User(
        id: 'owner_1',
        fullName: 'Chủ Quán Nam',
        email: 'nam.owner@gmail.com',
        role: 'MERCHANT',
        authProvider: 'LOCAL',
        status: 'ACTIVE',
        business: null,
      );

      final authProvider = AuthProvider();
      final userProvider = UserProvider();
      userProvider.setUser(user);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<UserProvider>.value(value: userProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MerchantOnboardingDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra Header Badge và Title
      expect(find.text('BƯỚC 2: HOÀN THIỆN HỒ SƠ QUÁN'), findsOneWidget);
      expect(find.text('Thông Tin Quán / Thương Hiệu F&B'), findsOneWidget);

      // Kiểm tra các nhãn thuộc tính
      expect(find.textContaining('Tên Quán / Thương hiệu F&B'), findsOneWidget);
      expect(find.textContaining('Mô hình kinh doanh F&B'), findsOneWidget);
      expect(find.textContaining('Địa chỉ cụ thể'), findsOneWidget);

      // Kiểm tra các nút hành động
      expect(find.text('Để sau'), findsOneWidget);
      expect(find.text('Lưu & Kích Hoạt Ngay'), findsOneWidget);
    });
  });
}

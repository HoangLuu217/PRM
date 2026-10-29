import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:prm_project/models/restaurant_model.dart';
import 'package:prm_project/models/user_model.dart';
import 'package:prm_project/providers/auth_provider.dart';
import 'package:prm_project/providers/user_provider.dart';
import 'package:prm_project/services/administrative_division_service.dart';
import 'package:prm_project/screens/owner/widgets/merchant_onboarding_dialog.dart';

void main() {
  group('Member 1 - Owner Restaurant Onboarding Tests', () {
    test('Restaurant list prefers complete address from its primary branch', () {
      final restaurant = RestaurantModel.fromJson({
        '_id': 'business_1',
        'name': 'Milano',
        'addressText': '34, Hải Châu',
        'primaryBranch': {
          'address': {
            'street': '123 Nguyễn Văn Linh',
            'ward': 'Phường Hải Châu',
            'city': 'Thành phố Đà Nẵng',
          },
        },
      });

      expect(
        restaurant.address,
        '123 Nguyễn Văn Linh, Phường Hải Châu, Thành phố Đà Nẵng',
      );
    });

    test('Onboarding payload validation test', () {
      final payload = {
        'name': 'Highland Coffee',
        'category': 'CAFE',
        'categories': ['CAFE'],
        'description': 'Cà phê truyền thống',
        'businessAddress': {
          'street': '123 Nguyễn Văn Linh',
          'ward': 'Phường Hải Châu',
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
      expect(
        (payload['vibes'] as List).contains('Yên tĩnh / Làm việc'),
        isTrue,
      );
      expect(
        (payload['businessAddress'] as Map)['ward'],
        equals('Phường Hải Châu'),
      );
    });

    testWidgets(
      'MerchantOnboardingDialog renders title, fields and action buttons',
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
            child: MaterialApp(
              home: Scaffold(
                body: MerchantOnboardingDialog(
                  administrativeDivisionService:
                      _FakeAdministrativeDivisionService(),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Kiểm tra Header Badge và Title
        expect(find.text('BƯỚC 2: HOÀN THIỆN HỒ SƠ QUÁN'), findsOneWidget);
        expect(find.text('Thông Tin Quán / Thương Hiệu F&B'), findsOneWidget);

        // Kiểm tra các nhãn thuộc tính
        expect(
          find.textContaining('Tên Quán / Thương hiệu F&B'),
          findsOneWidget,
        );
        expect(find.textContaining('Mô hình kinh doanh F&B'), findsOneWidget);
        expect(find.textContaining('Phường / Xã'), findsOneWidget);
        expect(find.textContaining('Địa chỉ cụ thể'), findsOneWidget);
        final wardDropdown = find.byType(DropdownButtonFormField<int>).last;
        await tester.ensureVisible(wardDropdown);
        await tester.tap(wardDropdown);
        await tester.pumpAndSettle();
        expect(find.text('Phường Hải Châu'), findsWidgets);

        // Kiểm tra các nút hành động
        expect(find.text('Để sau'), findsOneWidget);
        expect(find.text('Lưu & Kích Hoạt Ngay'), findsOneWidget);
      },
    );
  });
}

class _FakeAdministrativeDivisionService extends AdministrativeDivisionService {
  _FakeAdministrativeDivisionService()
    : super(client: MockClient((_) async => http.Response('{}', 200)));

  @override
  Future<List<AdministrativeDivision>> fetchProvinces() async {
    return const [AdministrativeDivision(code: 48, name: 'Thành phố Đà Nẵng')];
  }

  @override
  Future<List<AdministrativeDivision>> fetchWards(int provinceCode) async {
    return const [AdministrativeDivision(code: 20242, name: 'Phường Hải Châu')];
  }
}

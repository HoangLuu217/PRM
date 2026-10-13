import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:prm_project/providers/auth_provider.dart';
import 'package:prm_project/providers/user_provider.dart';
import 'package:prm_project/screens/auth/login_screen.dart';

void main() {
  testWidgets('Member 1 - Login Screen renders correctly with email, password fields and buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('FConnect'), findsWidgets);
    expect(find.text('Đăng Nhập'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Đăng nhập với Google'), findsOneWidget);
    expect(find.text('Đăng ký ngay'), findsOneWidget);
  });
}

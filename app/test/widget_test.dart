import 'package:flutter_test/flutter_test.dart';
import 'package:prm_project/main.dart';
import 'package:prm_project/screens/auth/splash_screen.dart';

void main() {
  testWidgets('App smoke test - initializes and renders SplashScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  });
}

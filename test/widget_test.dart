// اختبار دخان بسيط: يتأكد إن التطبيق يبني بدون Exception ويوصل لأول شاشة
// (تسجيل دخول الوالد) بحالة "لا حساب محفوظ".

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hamoudi_blocks/app.dart';

void main() {
  testWidgets('App boots and shows the parent sign-in screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const HamoudiBlocksApp());
    await tester.pumpAndSettle();

    expect(find.text('بلوك حمودي'), findsOneWidget);
    expect(find.text('إنشاء الحساب'), findsOneWidget);
  });
}

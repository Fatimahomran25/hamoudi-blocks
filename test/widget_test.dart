// A simple smoke test: confirms the app builds without an exception and
// reaches the first screen (parent sign-in) in the "no saved account" state.

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

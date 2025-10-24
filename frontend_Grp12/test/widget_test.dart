// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('App boots and shows AURA header on login screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AuraApp());

    // Wait for any animations/frames
    await tester.pumpAndSettle();

    // Verify that the login screen shows the AURA header text
    expect(find.text('AURA'), findsOneWidget);
  });
}

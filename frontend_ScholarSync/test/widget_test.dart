// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:scholarsync/main.dart';

void main() {
  testWidgets('App boots and shows ScholarSync header on login screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ScholarSyncApp());

    // Wait for any animations/frames
    await tester.pumpAndSettle();

    // Verify that the login screen shows the ScholarSync header text
    expect(find.text('ScholarSync'), findsOneWidget);
  });
}

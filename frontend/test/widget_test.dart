import 'package:flutter_test/flutter_test.dart';

import 'package:facility_service_management/main.dart';

void main() {
  testWidgets('app shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FacilityServiceApp());

    expect(find.text('MY VOICE'), findsOneWidget);
    expect(find.text('User'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Service'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:usedphone/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const UsedPhoneApp());
    expect(find.text('Activate License'), findsOneWidget);
  });
}
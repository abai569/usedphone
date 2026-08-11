import 'package:flutter_test/flutter_test.dart';
import 'package:usedphone/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const UsedPhoneApp());
    await tester.pumpAndSettle();
    expect(find.text('授权激活'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:usedphone/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const UsedPhoneApp());
    await tester.pumpAndSettle();
    expect(find.text('智能识别机型'), findsOneWidget);
    expect(find.text('手动识别机型'), findsOneWidget);
    expect(find.text('老旧机兜底估价'), findsOneWidget);
    expect(find.text('授权管理'), findsOneWidget);
    expect(find.text('关于软件'), findsOneWidget);
  });
}

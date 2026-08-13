import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usedphone/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const UsedPhoneApp());
    await tester.pumpAndSettle();
    expect(find.text('智能识别机型'), findsOneWidget);
    expect(find.text('手动识别机型'), findsOneWidget);
    expect(find.text('老旧机兜底估价'), findsOneWidget);
    expect(find.text('授权管理'), findsOneWidget);
    expect(find.text('关于软件'), findsOneWidget);
  });

  testWidgets('authorization dialog uses requested labels', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const UsedPhoneApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('授权管理'));
    await tester.pumpAndSettle();

    expect(find.textContaining('激活状态：未授权'), findsOneWidget);
    expect(find.textContaining('授权类型：月'), findsOneWidget);
    expect(find.textContaining('有效期至：-'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == '粘贴激活码',
      ),
      findsOneWidget,
    );
    expect(find.text('关闭'), findsOneWidget);
    expect(find.text('确认'), findsOneWidget);
  });
}

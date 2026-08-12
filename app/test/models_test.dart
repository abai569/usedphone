import 'package:flutter_test/flutter_test.dart';
import 'package:usedphone/models.dart';

void main() {
  test('RecognizeResult parses disabled recognition status', () {
    final result = RecognizeResult.fromJson({
      'status': 'disabled',
      'recognized': false,
      'suggestion': null,
    });

    expect(result.status, 'disabled');
    expect(result.recognized, isFalse);
  });

  test('RecognizeResult parses model candidate without storage', () {
    final result = RecognizeResult.fromJson({
      'status': 'candidate',
      'recognized': true,
      'suggestion': {
        'brand': 'Xiaomi',
        'model': '小米 17',
        'storages': [256, 512],
      },
    });

    expect(result.status, 'candidate');
    expect(result.suggestion?['model'], '小米 17');
    expect(result.suggestion?['storages'], [256, 512]);
  });

  test('recognition notice includes generic reference price', () {
    final device = Device(
      id: 1,
      brand: 'Xiaomi',
      model: 'K40 Pro',
      storage: 0,
      launchYear: 2021,
      basePrice: 680,
    );

    expect(
      recognitionNoticeMessage('小米', device, hasMultipleMatches: false),
      '小米 K40 Pro\n容量：未识别\n回收参考价：¥680\n价格类型：通用机型参考价',
    );
  });
}

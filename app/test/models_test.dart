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
}

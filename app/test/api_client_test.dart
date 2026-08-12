import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:usedphone/api_client.dart';

void main() {
  test('recognize sends both phone photos and parses candidate status', () async {
    final httpClient = MockClient((request) async {
      expect(request.url.path, '/recognize');
      expect(request.headers['Authorization'], 'Bearer license-token');
      expect(request.headers['content-type'], startsWith('multipart/form-data;'));
      final body = latin1.decode(request.bodyBytes);
      expect(body, contains('name="front_photo"; filename="front.jpg"'));
      expect(body, contains('name="back_photo"; filename="back.jpg"'));
      expect(body, contains('front-image'));
      expect(body, contains('back-image'));
      return Response(
        jsonEncode({
          'status': 'candidate',
          'recognized': false,
          'suggestion': {
            'brand': 'Apple',
            'model': 'iPhone 15',
            'storages': [128, 256],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiClient(baseUrl: 'https://example.test', client: httpClient)
      ..setLicenseToken('license-token');

    final result = await api.recognize(
      utf8.encode('front-image'),
      'front.jpg',
      utf8.encode('back-image'),
      'back.jpg',
    );

    expect(result.status, 'candidate');
    expect(result.suggestion?['model'], 'iPhone 15');
  });

  test('recognize converts a non-JSON error response to a request exception', () async {
    final api = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) async => Response('<html>Bad Gateway</html>', 502)),
    );

    expect(
      api.recognize([1], 'front.jpg', [2], 'back.jpg'),
      throwsA(
        allOf(
          isA<Exception>(),
          isNot(isA<FormatException>()),
          predicate((error) => error.toString().contains('Failed to recognize')),
        ),
      ),
    );
  });

  test('fallbackAppraise sends state and parses capped estimate', () async {
    final httpClient = MockClient((request) async {
      expect(request.url.path, '/fallback-appraise');
      expect(request.headers['Authorization'], 'Bearer license-token');
      expect(jsonDecode(request.body), {'state': 'no_power'});
      return Response(
        jsonEncode({
          'result': {'min': 10, 'mid': 45, 'max': 80},
          'method': 'old_phone_fallback',
          'cap': 200,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiClient(baseUrl: 'https://example.test', client: httpClient)
      ..setLicenseToken('license-token');

    final result = await api.fallbackAppraise('no_power');

    expect(result.min, 10);
    expect(result.mid, 45);
    expect(result.max, 80);
  });
}

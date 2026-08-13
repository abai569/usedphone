import 'dart:convert';
import 'package:http/http.dart';
import 'models.dart';

class ApiClient {
  final String baseUrl;
  final Client _client;
  String? _licenseToken;

  ApiClient({required this.baseUrl, Client? client})
      : _client = client ?? Client();

  void setLicenseToken(String? token) {
    _licenseToken = token;
  }

  Map<String, String> get _authHeaders => {
        if (_licenseToken != null) 'Authorization': 'Bearer $_licenseToken',
      };

  Future<ActivationResult> activate(String code, String deviceKey) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/activate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code, 'device_key': deviceKey}),
    );

    if (response.statusCode == 200) {
      return ActivationResult.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body)['error'] ?? 'unknown_error';
      return ActivationResult(status: 'error', error: error);
    }
  }

  Future<List<Device>> listDevices({String? brand, int? storage}) async {
    final queryParams = <String, String>{};
    if (brand != null) queryParams['brand'] = brand;
    if (storage != null) queryParams['storage'] = storage.toString();

    final uri = Uri.parse('$baseUrl/devices').replace(queryParameters: queryParams);
    final response = await _client.get(uri, headers: _authHeaders);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = data['items'] as List<dynamic>;
      return items.map((item) => Device.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load devices');
    }
  }

  Future<RecognizeResult> recognize(
    List<int> frontImageBytes,
    String frontFilename,
    List<int> backImageBytes,
    String backFilename, {
    List<int>? settingsImageBytes,
    String settingsFilename = 'settings.jpg',
  }) async {
    final request = MultipartRequest('POST', Uri.parse('$baseUrl/recognize'))
      ..headers.addAll(_authHeaders);
    request.files.add(MultipartFile.fromBytes(
      'front_photo',
      frontImageBytes,
      filename: frontFilename,
    ));
    request.files.add(MultipartFile.fromBytes(
      'back_photo',
      backImageBytes,
      filename: backFilename,
    ));
    if (settingsImageBytes != null && settingsImageBytes.isNotEmpty) {
      request.files.add(MultipartFile.fromBytes(
        'settings_photo',
        settingsImageBytes,
        filename: settingsFilename,
      ));
    }

    final streamedResponse = await _client.send(request);
    final response = await Response.fromStream(streamedResponse);

    Map<String, dynamic>? data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      data = null;
    }
    if (data != null && (response.statusCode == 200 || data['status'] != null)) {
      return RecognizeResult.fromJson(data);
    }
    throw Exception('Failed to recognize');
  }

  Future<AppraisalResult> appraise({
    required int deviceId,
    required int storage,
    required String appearance,
    required List<String> functionalIssues,
    required String accessory,
    required String deviceKey,
    double margin = 0.0,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/appraise'),
      headers: {'Content-Type': 'application/json', ..._authHeaders},
      body: jsonEncode({
        'device_id': deviceId,
        'storage': storage,
        'appearance': appearance,
        'functional_issues': functionalIssues,
        'accessory': accessory,
        'device_key': deviceKey,
        'margin': margin,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return AppraisalResult.fromJson(data['result']);
    } else {
      throw Exception('Failed to appraise');
    }
  }

  Future<AppraisalResult> fallbackAppraise(String state) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/fallback-appraise'),
      headers: {'Content-Type': 'application/json', ..._authHeaders},
      body: jsonEncode({'state': state}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to appraise old phone');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AppraisalResult.fromJson(data['result']);
  }

  void close() {
    _client.close();
  }
}

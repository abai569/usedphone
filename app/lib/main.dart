import 'package:flutter/material.dart';
import 'api_client.dart';
import 'screens/activate_screen.dart';
import 'screens/capture_screen.dart';

void main() {
  runApp(const UsedPhoneApp());
}

class UsedPhoneApp extends StatefulWidget {
  final ApiClient? apiClient;
  final String baseUrl;

  const UsedPhoneApp({
    super.key,
    this.apiClient,
    this.baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8070',
    ),
  });

  @override
  State<UsedPhoneApp> createState() => _UsedPhoneAppState();
}

class _UsedPhoneAppState extends State<UsedPhoneApp> {
  @override
  Widget build(BuildContext context) {
    final apiClient = widget.apiClient ?? ApiClient(baseUrl: widget.baseUrl);
    return MaterialApp(
          title: 'UsedPhone',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            useMaterial3: true,
          ),
          initialRoute: '/activate',
          routes: {
            '/activate': (context) => ActivateScreen(apiClient: apiClient),
            '/capture': (context) => CaptureScreen(apiClient: apiClient),
          },
    );
  }
}

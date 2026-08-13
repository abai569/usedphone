import 'package:flutter/material.dart';
import 'api_client.dart';
import 'screens/activate_screen.dart';
import 'screens/capture_screen.dart';
import 'screens/home_screen.dart';

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
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      useMaterial3: true,
    );
    return MaterialApp(
      title: 'UsedPhone',
      theme: baseTheme.copyWith(
        inputDecorationTheme: const InputDecorationTheme(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(64, 52),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(64, 52),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(64, 48),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          minTileHeight: 60,
          titleTextStyle: TextStyle(fontSize: 18, color: Colors.black87),
          subtitleTextStyle: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      ),
      initialRoute: '/home',
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.15,
        maxScaleFactor: 1.8,
        child: child!,
      ),
      routes: {
        '/activate': (context) => ActivateScreen(apiClient: apiClient),
        '/capture': (context) => CaptureScreen(apiClient: apiClient),
        '/home': (context) => HomeScreen(apiClient: apiClient),
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_client.dart';

class ActivateScreen extends StatefulWidget {
  final ApiClient apiClient;

  const ActivateScreen({super.key, required this.apiClient});

  @override
  State<ActivateScreen> createState() => _ActivateScreenState();
}

class _ActivateScreenState extends State<ActivateScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _expiresAt;

  @override
  void initState() {
    super.initState();
    _checkActivation();
  }

  Future<void> _checkActivation() async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAt = prefs.getString('expires_at');
    if (expiresAt != null) {
      final expiry = DateTime.tryParse(expiresAt);
      if (expiry != null && expiry.isAfter(DateTime.now())) {
        widget.apiClient.setLicenseToken(prefs.getString('license_token'));
        setState(() => _expiresAt = expiresAt);
        _goToCapture();
      }
    }
  }

  Future<void> _activate() async {
    if (_codeController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter activation code');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      var deviceKey = prefs.getString('device_key');
      if (deviceKey == null) {
        deviceKey = DateTime.now().millisecondsSinceEpoch.toString();
        await prefs.setString('device_key', deviceKey);
      }

      final result = await widget.apiClient.activate(
        _codeController.text.trim(),
        deviceKey,
      );

      if (result.isActive) {
        await prefs.setString('expires_at', result.expiresAt!);
        await prefs.setString('license_token', result.token!);
        widget.apiClient.setLicenseToken(result.token);
        _goToCapture();
      } else {
        setState(() => _error = result.error ?? 'Activation failed');
      }
    } catch (e) {
      setState(() => _error = 'Network error');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _goToCapture() {
    Navigator.pushReplacementNamed(context, '/capture');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activate License')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Enter Activation Code',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: 'Activation Code',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 16),
            if (_expiresAt != null)
              Text('Valid until: ${_expiresAt!.substring(0, 10)}'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _activate,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Activate'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

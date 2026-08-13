import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_client.dart';
import '../app_dialog.dart';

class ActivateScreen extends StatefulWidget {
  final ApiClient apiClient;

  const ActivateScreen({super.key, required this.apiClient});

  @override
  State<ActivateScreen> createState() => _ActivateScreenState();
}

class _ActivateScreenState extends State<ActivateScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _expiresAt;

  @override
  void initState() {
    super.initState();
    _checkActivation();
  }

  Future<void> _checkActivation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiresAt = prefs.getString('expires_at');
      final licenseToken = prefs.getString('license_token');
      if (!mounted || expiresAt == null || licenseToken == null) return;
      final expiry = DateTime.tryParse(expiresAt);
      if (expiry != null && expiry.isAfter(DateTime.now())) {
        widget.apiClient.setLicenseToken(licenseToken);
        setState(() => _expiresAt = expiresAt);
        _goToCapture();
      }
    } catch (_) {
      // Start in the activation form when local storage is unavailable.
    }
  }

  Future<void> _activate() async {
    if (_codeController.text.trim().isEmpty) {
      await showAppMessage(context, title: '请输入激活码', message: '激活码不能为空。');
      return;
    }

    setState(() {
      _loading = true;
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
      if (!mounted) return;

      if (result.isActive && result.expiresAt != null && result.token != null) {
        await prefs.setString('expires_at', result.expiresAt!);
        await prefs.setString('license_token', result.token!);
        widget.apiClient.setLicenseToken(result.token);
        _goToCapture();
      } else if (result.isActive) {
        await showAppMessage(context, title: '激活失败', message: '服务器返回的激活信息不完整。');
      } else {
        await showAppMessage(
          context,
          title: '激活失败',
          message: _activationError(result.error),
          icon: Icons.error_outline,
          color: Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;
      await showAppMessage(
        context,
        title: '网络连接失败',
        message: '请检查网络后重试。',
        icon: Icons.error_outline,
        color: Colors.red,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToCapture() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  String _activationError(String? error) {
    return switch (error) {
      'invalid_code' => '激活码不存在',
      'expired' => '激活码已过期',
      'already_bound' => '激活码已绑定其他设备',
      _ => '激活失败，请重试',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('授权激活')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '请输入激活码',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: '激活码',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_expiresAt != null)
              Text('有效期至：${_expiresAt!.substring(0, 10)}'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _activate,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('立即激活'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../app_dialog.dart';
import 'capture_screen.dart';

class HomeScreen extends StatefulWidget {
  final ApiClient apiClient;

  const HomeScreen({super.key, required this.apiClient});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _authorized = false;
  String? _expiresAt;

  @override
  void initState() {
    super.initState();
    _loadAuthorization();
  }

  Future<void> _loadAuthorization() async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAt = prefs.getString('expires_at');
    final token = prefs.getString('license_token');
    final expiry = expiresAt == null ? null : DateTime.tryParse(expiresAt);
    if (!mounted) return;
    if (token != null && expiry != null && expiry.isAfter(DateTime.now())) {
      widget.apiClient.setLicenseToken(token);
    }
    setState(() {
      _authorized = token != null && expiry != null && expiry.isAfter(DateTime.now());
      _expiresAt = expiresAt;
    });
  }

  void _openCapture({required bool smart}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CaptureScreen(apiClient: widget.apiClient, smartOnly: smart, manualOnly: !smart),
      ),
    );
  }

  Future<void> _showAbout() async {
    await showAppMessage(context, title: '关于软件', message: '二手手机估价\n版本：1.2.0');
  }

  Future<void> _showAuthorization() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('授权管理', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_authorized ? '授权状态：已授权\n有效期至：${_expiresAt?.substring(0, 10) ?? '-'}' : '当前未授权'),
            const SizedBox(height: 16),
            TextField(controller: controller, decoration: const InputDecoration(labelText: '重新授权码', border: OutlineInputBorder())),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
          FilledButton(
            onPressed: () async {
              final code = controller.text.trim();
              if (code.isEmpty) {
                await showAppMessage(context, title: '请输入激活码', message: '激活码不能为空。');
                return;
              }
              final prefs = await SharedPreferences.getInstance();
              var deviceKey = prefs.getString('device_key');
              if (deviceKey == null) {
                deviceKey = DateTime.now().millisecondsSinceEpoch.toString();
                await prefs.setString('device_key', deviceKey);
              }
              try {
                final result = await widget.apiClient.activate(code, deviceKey);
                if (!context.mounted) return;
                if (!result.isActive || result.token == null || result.expiresAt == null) {
                  await showAppMessage(context, title: '授权失败', message: '激活码无效或已过期。', icon: Icons.error_outline, color: Colors.red);
                  return;
                }
                await prefs.setString('license_token', result.token!);
                await prefs.setString('expires_at', result.expiresAt!);
                widget.apiClient.setLicenseToken(result.token);
                Navigator.pop(context);
                await _loadAuthorization();
              } catch (_) {
                if (context.mounted) await showAppMessage(context, title: '授权失败', message: '网络连接失败，请稍后重试。', icon: Icons.error_outline, color: Colors.red);
              }
            },
            child: const Text('重新授权'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('二手手机估价')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _entry('智能识别机型', Icons.auto_awesome, _authorized ? () => _openCapture(smart: true) : null),
          _entry('手动识别机型', Icons.search, _authorized ? () => _openCapture(smart: false) : null),
          _entry('老旧机兜底估价', Icons.recycling, _authorized ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => CaptureScreen(apiClient: widget.apiClient, fallbackOnly: true))) : null),
          _entry('授权管理', Icons.verified_user, _showAuthorization),
          _entry('关于软件', Icons.info_outline, _showAbout),
        ],
      ),
    );
  }

  Widget _entry(String title, IconData icon, VoidCallback? onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(height: 64, child: ElevatedButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(title))),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
  String? _licenseType;

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
      _licenseType = prefs.getString('license_type');
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
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    await showAppMessage(
      context,
      title: '关于软件',
      message: '二手手机估价\n版本：${packageInfo.version}',
      actionLabel: '关闭',
      squareAction: true,
    );
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Text(
              '激活状态：${_authorized ? '已授权' : '未授权'}\n'
              '授权类型：${_licenseType == 'year' ? '年' : '月'}\n'
              '有效期至：${_expiresAt?.substring(0, 10) ?? '-'}',
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: '粘贴激活码',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.end,
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
                if (result.licenseType != null) await prefs.setString('license_type', result.licenseType!);
                widget.apiClient.setLicenseToken(result.token);
                if (!context.mounted) return;
                Navigator.pop(context);
                await _loadAuthorization();
              } catch (_) {
                if (context.mounted) await showAppMessage(context, title: '授权失败', message: '网络连接失败，请稍后重试。', icon: Icons.error_outline, color: Colors.red);
              }
            },
            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showFallback() async {
    const states = <String, String>{
      'working': '可开机，基本功能正常',
      'working_faulty': '可开机，但碎屏或有明显故障',
      'no_power': '无法开机，外观基本完整',
      'severe_damage': '严重破损、进水或拆修',
    };
    String? selected;
    final state = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('选择旧机状态', textAlign: TextAlign.center),
          content: DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '旧机状态',
              border: OutlineInputBorder(),
            ),
            items: states.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) => setDialogState(() => selected = value),
          ),
          actionsAlignment: MainAxisAlignment.end,
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            FilledButton(
              onPressed: selected == null ? null : () => Navigator.pop(context, selected),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    if (state == null || !mounted) return;
    try {
      final result = await widget.apiClient.fallbackAppraise(state);
      if (!mounted) return;
      await showAppMessage(
        context,
        title: '老旧机兜底估价',
        message: '回收参考价：¥${result.mid.toStringAsFixed(0)}\n价格范围：¥${result.min.toStringAsFixed(0)} - ¥${result.max.toStringAsFixed(0)}',
      );
    } catch (_) {
      if (mounted) await showAppMessage(context, title: '估价失败', message: '请检查网络后重试。', icon: Icons.error_outline, color: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('二手手机估价')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
        children: [
          _entry('智能识别机型', Icons.auto_awesome, _authorized ? () => _openCapture(smart: true) : null),
          _entry('手动识别机型', Icons.search, _authorized ? () => _openCapture(smart: false) : null),
          _entry('老旧机兜底估价', Icons.recycling, _authorized ? _showFallback : null),
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

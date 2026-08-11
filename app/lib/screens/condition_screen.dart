import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_client.dart';
import '../models.dart';
import 'result_screen.dart';

class ConditionScreen extends StatefulWidget {
  final ApiClient apiClient;
  final Device device;
  final File? frontImage;
  final File? backImage;

  const ConditionScreen({
    super.key,
    required this.apiClient,
    required this.device,
    this.frontImage,
    this.backImage,
  });

  @override
  State<ConditionScreen> createState() => _ConditionScreenState();
}

class _ConditionScreenState extends State<ConditionScreen> {
  String _appearance = 'good';
  final Set<String> _functionalIssues = {};
  String _accessory = 'complete';
  bool _loading = false;

  static const _appearances = {
    'excellent': '近乎全新',
    'good': '轻微使用',
    'fair': '明显划痕',
    'poor': '磕碰严重',
    'junk': '战斗成色',
  };

  static const _functionalOptions = {
    'non_original_screen': '更换过非原装屏',
    'screen_cracked': '屏幕破裂',
    'screen_burn_in': '烧屏、亮点或显示异常',
    'no_power': '无法正常开机',
    'liquid_damage': '进液或泡水',
    'repaired': '有拆修记录',
  };

  static const _accessories = {
    'complete': '包装、充电器、发票齐全',
    'partial': '部分配件',
    'none': '无配件',
  };

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceKey = prefs.getString('device_key') ?? '';

      final result = await widget.apiClient.appraise(
        deviceId: widget.device.id,
        storage: widget.device.storage,
        appearance: _appearance,
        functionalIssues: _functionalIssues.toList(),
        accessory: _accessory,
        deviceKey: deviceKey,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(result: result, device: widget.device),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('估价失败，请检查网络后重试')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('选择手机成色')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('外观成色',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _appearances.entries.map((e) {
                return ChoiceChip(
                  label: Text(e.value),
                  selected: _appearance == e.key,
                  onSelected: (_) => setState(() => _appearance = e.key),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text('功能和维修情况（可多选）',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._functionalOptions.entries.map((e) {
              return CheckboxListTile(
                title: Text(e.value),
                value: _functionalIssues.contains(e.key),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _functionalIssues.add(e.key);
                    } else {
                      _functionalIssues.remove(e.key);
                    }
                  });
                },
              );
            }),
            const SizedBox(height: 24),
            const Text('配件情况',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _accessory,
              onChanged: (v) {
                if (v != null) setState(() => _accessory = v);
              },
              child: Column(
                children: _accessories.entries.map((e) {
                  return RadioListTile<String>(
                    title: Text(e.value),
                    value: e.key,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('开始估价'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

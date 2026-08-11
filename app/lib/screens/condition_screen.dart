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
    'excellent': 'Excellent',
    'good': 'Good',
    'fair': 'Fair',
    'poor': 'Poor',
    'junk': 'Junk',
  };

  static const _functionalOptions = {
    'non_original_screen': 'Non-original screen',
    'screen_cracked': 'Screen cracked',
    'screen_burn_in': 'Screen burn-in',
    'no_power': 'Cannot power on',
    'liquid_damage': 'Liquid damage',
    'repaired': 'Previously repaired',
  };

  static const _accessories = {
    'complete': 'Complete (box + charger + invoice)',
    'partial': 'Partial',
    'none': 'None',
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
        const SnackBar(content: Text('Appraisal failed')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Condition')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Appearance',
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
            const Text('Functional Issues',
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
            const Text('Accessories',
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
                    : const Text('Appraise'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
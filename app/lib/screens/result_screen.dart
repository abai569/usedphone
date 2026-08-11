import 'package:flutter/material.dart';
import '../models.dart';

class ResultScreen extends StatelessWidget {
  final AppraisalResult result;
  final Device device;

  const ResultScreen({super.key, required this.result, required this.device});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('估价结果')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${device.brand} ${device.model}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text('${device.storage}GB',
                style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 32),
            const Text('建议收机价格',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildPriceRow('保守价', result.min, Colors.orange),
            const SizedBox(height: 8),
            _buildPriceRow('参考价', result.mid, Colors.green, large: true),
            const SizedBox(height: 8),
            _buildPriceRow('最高价', result.max, Colors.blue),
            const SizedBox(height: 32),
            const Text(
              '此价格仅供收机参考，请结合实机检测、当地行情和利润空间调整。',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: const Text('继续估下一台'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, double price, Color color,
      {bool large = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: large ? 20 : 16,
                fontWeight: FontWeight.bold,
                color: color)),
        Text('¥${price.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: large ? 32 : 20,
                fontWeight: FontWeight.bold,
                color: color)),
      ],
    );
  }
}

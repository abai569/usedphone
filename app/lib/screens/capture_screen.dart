import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api_client.dart';
import '../models.dart';
import 'condition_screen.dart';

class CaptureScreen extends StatefulWidget {
  final ApiClient apiClient;

  const CaptureScreen({super.key, required this.apiClient});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _picker = ImagePicker();
  File? _frontImage;
  File? _backImage;
  Device? _selectedDevice;
  bool _loading = false;
  List<Device> _devices = [];

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await widget.apiClient.listDevices();
      setState(() => _devices = devices);
    } catch (e) {
      // ignore
    }
  }

  Future<void> _pickFront() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file != null) setState(() => _frontImage = File(file.path));
  }

  Future<void> _pickBack() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file != null) setState(() => _backImage = File(file.path));
  }

  Future<void> _recognize() async {
    if (_frontImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take front photo first')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final bytes = await _frontImage!.readAsBytes();
      final result = await widget.apiClient.recognize(bytes, 'front.jpg');
      if (result.recognized && result.suggestion != null) {
        final match = _devices.firstWhere(
          (d) => d.id == result.suggestion!['device_id'],
          orElse: () => _devices.first,
        );
        setState(() => _selectedDevice = match);
      }
    } catch (e) {
      // stub: manual selection required
    } finally {
      setState(() => _loading = false);
    }
  }

  void _next() {
    if (_selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a device')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConditionScreen(
          apiClient: widget.apiClient,
          device: _selectedDevice!,
          frontImage: _frontImage,
          backImage: _backImage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capture Photos')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _PhotoBox(
                    label: 'Front',
                    image: _frontImage,
                    onTap: _pickFront,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _PhotoBox(
                    label: 'Back',
                    image: _backImage,
                    onTap: _pickBack,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _recognize,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Auto Recognize'),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Or Select Manually:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButton<Device>(
              value: _selectedDevice,
              isExpanded: true,
              hint: const Text('Select device'),
              items: _devices.map((d) {
                return DropdownMenuItem(
                  value: d,
                  child: Text('${d.brand} ${d.model} ${d.storage}GB'),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedDevice = v),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _next,
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoBox extends StatelessWidget {
  final String label;
  final File? image;
  final VoidCallback onTap;

  const _PhotoBox({required this.label, this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(image!, fit: BoxFit.cover),
              )
            : Center(child: Text('Tap to take\n$label photo',
                textAlign: TextAlign.center)),
      ),
    );
  }
}
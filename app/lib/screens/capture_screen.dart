import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _brandNames = {
    'Apple': '苹果',
    'Huawei': '华为',
    'Honor': '荣耀',
    'Xiaomi': '小米',
    'OPPO': 'OPPO',
    'vivo': 'vivo',
    'Samsung': '三星',
    'OnePlus': '一加',
    'realme': '真我',
    'Meizu': '魅族',
  };

  final _picker = ImagePicker();
  final _searchController = TextEditingController();
  File? _frontImage;
  File? _backImage;
  bool _loading = false;
  List<Device> _devices = [];
  String? _selectedBrand;
  String? _selectedModel;
  int? _selectedStorage;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  List<String> get _brands => _devices.map((d) => d.brand).toSet().toList()
    ..sort((a, b) => (_brandNames[a] ?? a).compareTo(_brandNames[b] ?? b));

  List<String> get _models {
    final query = _searchController.text.trim().toLowerCase();
    final models = _devices
        .where((d) => d.brand == _selectedBrand)
        .map((d) => d.model)
        .toSet()
        .where((model) => query.isEmpty || model.toLowerCase().contains(query))
        .toList()
      ..sort();
    return models;
  }

  List<int> get _storages {
    final storages = _devices
        .where((d) => d.brand == _selectedBrand && d.model == _selectedModel)
        .map((d) => d.storage)
        .toSet()
        .toList()
      ..sort();
    return storages;
  }

  Device? get _selectedDevice {
    for (final device in _devices) {
      if (device.brand == _selectedBrand &&
          device.model == _selectedModel &&
          device.storage == _selectedStorage) {
        return device;
      }
    }
    return null;
  }

  Future<void> _loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('device_cache');
    if (cached != null) {
      try {
        final devices = (jsonDecode(cached) as List)
            .map((item) => Device.fromJson(item as Map<String, dynamic>))
            .toList();
        if (mounted) _applyDevices(devices, prefs.getInt('recent_device_id'));
      } catch (_) {}
    }

    try {
      final devices = await widget.apiClient.listDevices();
      await prefs.setString(
        'device_cache',
        jsonEncode(devices.map((device) => device.toJson()).toList()),
      );
      if (mounted) _applyDevices(devices, prefs.getInt('recent_device_id'));
    } catch (_) {
      if (mounted && _devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('机型库加载失败，请检查网络')),
        );
      }
    }
  }

  void _applyDevices(List<Device> devices, int? recentId) {
    Device? recent;
    for (final device in devices) {
      if (device.id == recentId) recent = device;
    }
    setState(() {
      _devices = devices;
      if (recent != null) {
        _selectedBrand = recent.brand;
        _selectedModel = recent.model;
        _selectedStorage = recent.storage;
      }
    });
  }

  Future<void> _pickFront() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file != null && mounted) setState(() => _frontImage = File(file.path));
  }

  Future<void> _pickBack() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file != null && mounted) setState(() => _backImage = File(file.path));
  }

  Future<void> _recognize() async {
    if (_frontImage == null || _backImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先拍摄手机正面和背面')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await widget.apiClient.recognize(
        await _frontImage!.readAsBytes(),
        'front.jpg',
      );
      if (!mounted) return;
      if (result.recognized && result.suggestion != null) {
        final id = result.suggestion!['device_id'];
        final matches = _devices.where((device) => device.id == id);
        if (matches.isNotEmpty) {
          final match = matches.first;
          setState(() {
            _selectedBrand = match.brand;
            _selectedModel = match.model;
            _selectedStorage = match.storage;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已识别：${_brandNames[match.brand] ?? match.brand} ${match.model} ${match.storage}GB')),
          );
          return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂未识别成功，请手动选择机型')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('智能识别暂不可用，请手动选择机型')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _next() async {
    final device = _selectedDevice;
    if (device == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择品牌、型号和容量')),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('recent_device_id', device.id);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConditionScreen(
          apiClient: widget.apiClient,
          device: device,
          frontImage: _frontImage,
          backImage: _backImage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('二手手机估价')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _PhotoBox(label: '正面', image: _frontImage, onTap: _pickFront)),
              const SizedBox(width: 16),
              Expanded(child: _PhotoBox(label: '背面', image: _backImage, onTap: _pickBack)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _recognize,
              icon: const Icon(Icons.auto_awesome),
              label: Text(_loading ? '正在识别...' : '智能识别机型'),
            ),
          ),
          const SizedBox(height: 24),
          const Text('手动选择机型', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedBrand,
            decoration: const InputDecoration(labelText: '品牌', border: OutlineInputBorder()),
            items: _brands.map((brand) => DropdownMenuItem(value: brand, child: Text(_brandNames[brand] ?? brand))).toList(),
            onChanged: (brand) => setState(() {
              _selectedBrand = brand;
              _selectedModel = null;
              _selectedStorage = null;
              _searchController.clear();
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            enabled: _selectedBrand != null,
            decoration: const InputDecoration(
              labelText: '搜索型号',
              hintText: '例如：Mate 60、iPhone 15、K70',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {
              _selectedModel = null;
              _selectedStorage = null;
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(Object.hash(_selectedBrand, _searchController.text)),
            initialValue: _models.contains(_selectedModel) ? _selectedModel : null,
            decoration: const InputDecoration(labelText: '型号', border: OutlineInputBorder()),
            items: _models.map((model) => DropdownMenuItem(value: model, child: Text(model))).toList(),
            onChanged: (model) => setState(() {
              _selectedModel = model;
              _selectedStorage = null;
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey(Object.hash(_selectedBrand, _selectedModel)),
            initialValue: _storages.contains(_selectedStorage) ? _selectedStorage : null,
            decoration: const InputDecoration(labelText: '容量', border: OutlineInputBorder()),
            items: _storages.map((storage) => DropdownMenuItem(value: storage, child: Text('${storage}GB'))).toList(),
            onChanged: (storage) => setState(() => _selectedStorage = storage),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(onPressed: _next, child: const Text('下一步：选择成色')),
          ),
        ],
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
          borderRadius: BorderRadius.circular(12),
        ),
        child: image != null
            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(image!, fit: BoxFit.cover))
            : Center(child: Text('点击拍摄手机$label', textAlign: TextAlign.center)),
      ),
    );
  }
}

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
    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50, maxWidth: 1200);
    if (file != null && mounted) setState(() => _frontImage = File(file.path));
  }

  Future<void> _pickBack() async {
    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50, maxWidth: 1200);
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
        await _backImage!.readAsBytes(),
        'back.jpg',
      );
      if (!mounted) return;
      if (result.status == 'candidate' && result.suggestion != null) {
        final brand = result.suggestion!['brand'];
        final model = result.suggestion!['model'];
        final matches = _devices.where((device) => device.brand == brand && device.model == model);
        if (matches.isNotEmpty) {
          final match = matches.first;
          final matchingDevices = matches.toList();
          setState(() {
            _selectedBrand = match.brand;
            _selectedModel = match.model;
            _selectedStorage = matchingDevices.length == 1 ? match.storage : null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                matchingDevices.length == 1
                    ? '已识别：${_brandNames[match.brand] ?? match.brand} ${match.model} ${match.storage}GB'
                    : '已识别：${_brandNames[match.brand] ?? match.brand} ${match.model}，请选择容量',
              ),
            ),
          );
          return;
        }
      }
      if (result.status == 'disabled') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('智能识别尚未配置，请手动选择机型')),
        );
        return;
      }
      if (result.status == 'unmatched' && result.suggestion != null) {
        final brand = result.suggestion!['brand'] ?? '';
        final models = (result.suggestion!['models'] as List<dynamic>? ?? const []).join('、');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('识别到 $brand $models，但价格库暂无该机型')),
        );
        return;
      }
      if (result.status == 'unavailable') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('智能识别服务暂不可用，请稍后重试')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法确认具体型号，请手动选择或拍摄机身型号标签')),
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

  Future<void> _fallbackAppraise() async {
    const states = <String, String>{
      'working': '可开机，基本功能正常',
      'working_faulty': '可开机，但碎屏或有明显故障',
      'no_power': '无法开机，外观基本完整',
      'severe_damage': '严重破损、进水或拆修',
    };
    final state = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('选择旧机状态', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('仅用于无法确认机型或没有可靠行情的设备'),
            ),
            ...states.entries.map(
              (entry) => ListTile(
                title: Text(entry.value),
                onTap: () => Navigator.pop(context, entry.key),
              ),
            ),
          ],
        ),
      ),
    );
    if (state == null || !mounted) return;
    setState(() => _loading = true);
    try {
      final result = await widget.apiClient.fallbackAppraise(state);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('旧机兜底估价'),
          content: Text(
            '${states[state]}\n\n建议收购范围：¥${result.min.toStringAsFixed(0)} - ¥${result.max.toStringAsFixed(0)}\n'
            '参考中位价：¥${result.mid.toStringAsFixed(0)}\n\n'
            '该报价仅用于无可靠型号或行情的旧机，最高不超过 200 元。',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('旧机兜底估价暂不可用，请稍后重试')),
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

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出激活'),
        content: const Text('退出后需要重新输入激活码才能继续使用。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('license_token');
    await prefs.remove('expires_at');
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/activate');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('二手手机估价'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '退出激活',
            onPressed: _logout,
          ),
        ],
      ),
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
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loading ? null : _fallbackAppraise,
            icon: const Icon(Icons.recycling),
            label: const Text('老旧机/无法开机兜底估价'),
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

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../app_dialog.dart';
import '../models.dart';
import 'condition_screen.dart';

class CaptureScreen extends StatefulWidget {
  final ApiClient apiClient;
  final bool smartOnly;
  final bool manualOnly;
  final bool fallbackOnly;

  const CaptureScreen({super.key, required this.apiClient, this.smartOnly = false, this.manualOnly = false, this.fallbackOnly = false});

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
  final _scrollController = ScrollController();
  final _manualSelectionKey = GlobalKey();
  File? _frontImage;
  File? _backImage;
  bool _loading = false;
  bool _recognizing = false;
  List<Device> _devices = [];
  String? _selectedBrand;
  String? _selectedModel;
  int? _selectedStorage;
  String? _selectedSearchResult;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<String> get _brands =>
      _devices.map((d) => d.brand).toSet().toList()
        ..sort((a, b) => (_brandNames[a] ?? a).compareTo(_brandNames[b] ?? b));

  List<String> get _models {
    final models =
        _devices
            .where((d) => d.brand == _selectedBrand)
            .map((d) => d.model)
            .toSet()
            .toList()
          ..sort();
    return models;
  }

  String _normalizeSearchText(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[\s\-_（）()]'), '');

  List<({String brand, String model})> get _modelSearchResults {
    final query = _normalizeSearchText(_searchController.text.trim());
    if (query.isEmpty) return const [];
    final results = <String, ({String brand, String model})>{};
    for (final device in _devices) {
      final brandName = _brandNames[device.brand] ?? device.brand;
      final searchable = _normalizeSearchText(
        '${device.brand} $brandName ${device.model}',
      );
      if (searchable.contains(query)) {
        results['${device.brand}\u0000${device.model}'] = (
          brand: device.brand,
          model: device.model,
        );
      }
    }
    final matches = results.values.toList()
      ..sort((a, b) {
        final brandOrder = (_brandNames[a.brand] ?? a.brand).compareTo(
          _brandNames[b.brand] ?? b.brand,
        );
        return brandOrder != 0 ? brandOrder : a.model.compareTo(b.model);
      });
    return matches;
  }

  void _selectSearchResult(String? value) {
    if (value == null) return;
    final parts = value.split('\u0000');
    if (parts.length != 2) return;
    final brand = parts[0];
    final model = parts[1];
    final storages = _devices
        .where((device) => device.brand == brand && device.model == model)
        .map((device) => device.storage)
        .toSet()
        .toList();
    setState(() {
      _selectedSearchResult = value;
      _selectedBrand = brand;
      _selectedModel = model;
      _selectedStorage = storages.length == 1 ? storages.single : null;
    });
  }

  List<int> get _storages {
    final storages =
        _devices
            .where(
              (d) => d.brand == _selectedBrand && d.model == _selectedModel,
            )
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
        await showAppMessage(
          context,
          title: '机型库加载失败',
          message: '请检查网络后重试。',
          icon: Icons.error_outline,
          color: Colors.red,
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
    final source = await _pickImageSource();
    if (source == null) return;
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 40,
      maxWidth: 800,
    );
    if (file != null && mounted) setState(() => _frontImage = File(file.path));
  }

  Future<void> _pickBack() async {
    final source = await _pickImageSource();
    if (source == null) return;
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 40,
      maxWidth: 800,
    );
    if (file != null && mounted) setState(() => _backImage = File(file.path));
  }

  Future<ImageSource?> _pickImageSource() async {
    return showDialog<ImageSource>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SafeArea(
        child: AlertDialog(
          title: const Text('选择照片来源', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('拍照'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('从相册选择'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _recognize() async {
    if (_frontImage == null || _backImage == null) {
      await showAppMessage(
        context,
        title: '还缺少照片',
        message: '请先拍摄手机正面和背面。',
      );
      return;
    }

           setState(() {
      _loading = true;
      _recognizing = true;
    });
    try {
      final result = await widget.apiClient.recognize(
        await _frontImage!.readAsBytes(),
        'front.jpg',
        await _backImage!.readAsBytes(),
        'back.jpg',
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _recognizing = false;
      });
      if (result.status == 'candidate' && result.suggestion != null) {
        final brand = result.suggestion!['brand'];
        final model = result.suggestion!['model'];
        final matches = _devices.where(
          (device) => device.brand == brand && device.model == model,
        );
        if (matches.isNotEmpty) {
          final match = matches.first;
          final matchingDevices = matches.toList();
          setState(() {
            _selectedBrand = match.brand;
            _selectedModel = match.model;
             _selectedStorage = matchingDevices.length == 1
                 ? match.storage
                 : null;
           });
           if (widget.smartOnly) {
             final appearance = result.suggestion?['appearance'] as String? ?? 'good';
             final smartDevice = matchingDevices.firstWhere(
               (device) => device.storage == 0,
               orElse: () => match,
             );
             await _smartAppraise(smartDevice, appearance);
             return;
           }
           await _showRecognitionNotice(
            icon: Icons.check_circle,
            color: Colors.green,
            title: '识别成功',
            message: recognitionNoticeMessage(
              _brandNames[match.brand] ?? match.brand,
              match,
              hasMultipleMatches: matchingDevices.length > 1,
            ),
          );
          return;
        }
      }
      if (result.status == 'disabled') {
        await _showRecognitionNotice(
          icon: Icons.info,
          color: Colors.orange,
          title: '请手动选择',
          message: '智能识别尚未配置，请手动选择机型。',
        );
        return;
      }
      if (result.status == 'unmatched' && result.suggestion != null) {
        final brand = result.suggestion!['brand'] ?? '';
        final models =
            (result.suggestion!['models'] as List<dynamic>? ?? const []).join(
              '、',
            );
        await _showRecognitionNotice(
          icon: Icons.warning_amber_rounded,
          color: Colors.orange,
          title: '暂无匹配价格',
          message: '识别到 $brand $models\n价格库暂无该机型，请手动选择。',
        );
        return;
      }
      if (result.status == 'ambiguous' && result.suggestion != null) {
        final brand = result.suggestion!['brand'] ?? '';
        final selectedModel = await _chooseRecognizedModel(
          brand,
          result.suggestion!['models'] as List<dynamic>? ?? const [],
        );
        if (selectedModel == null || !mounted) return;
        final matchingDevices = _devices
            .where((device) => device.brand == brand && device.model == selectedModel)
            .toList();
        if (matchingDevices.isEmpty) return;
        final selected = matchingDevices.firstWhere(
          (device) => device.storage == 0,
          orElse: () => matchingDevices.first,
        );
        setState(() {
          _selectedBrand = brand;
          _selectedModel = selectedModel;
          _selectedStorage = selected.storage;
        });
        if (widget.smartOnly) {
          final appearance = result.suggestion?['appearance'] as String? ?? 'good';
          await _smartAppraise(selected, appearance);
        } else {
          await _next();
        }
        return;
      }
      if (result.status == 'unavailable') {
        await _showRecognitionNotice(
          icon: Icons.error_outline,
          color: Colors.red,
          title: '识别失败',
          message: '智能识别服务暂不可用，请稍后重试。',
        );
        return;
      }
      await _showRecognitionNotice(
        icon: Icons.help_outline,
        color: Colors.orange,
        title: '无法确认型号',
        message: '请手动选择，或重新拍摄清晰的机身型号标签。',
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _recognizing = false;
        });
        await _showRecognitionNotice(
          icon: Icons.error_outline,
          color: Colors.red,
          title: '识别失败',
          message: '智能识别暂不可用，请手动选择机型。',
        );
      }
    } finally {
      if (mounted && (_loading || _recognizing)) {
        setState(() {
          _loading = false;
          _recognizing = false;
        });
      }
    }
  }

  Future<void> _smartAppraise(Device device, String appearance) async {
    setState(() => _loading = true);
    try {
      final result = await widget.apiClient.appraise(
        deviceId: device.id,
        storage: device.storage,
        appearance: appearance,
        functionalIssues: const ['no_power'],
        accessory: 'none',
        deviceKey: (await SharedPreferences.getInstance()).getString('device_key') ?? '',
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('AI 智能估价', textAlign: TextAlign.center),
          content: Text('机型：${_brandNames[device.brand] ?? device.brand} ${device.model}\n\n回收参考价：¥${result.mid.toStringAsFixed(0)}', textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('确定'))],
        ),
      );
    } catch (_) {
      if (mounted) await showAppMessage(context, title: '估价失败', message: '请检查网络后重试。', icon: Icons.error_outline, color: Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showRecognitionNotice({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(icon, color: color, size: 56),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 19, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    final selectionContext = _manualSelectionKey.currentContext;
    if (selectionContext != null && selectionContext.mounted) {
      await Scrollable.ensureVisible(
        selectionContext,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    }
  }

  Future<void> _next() async {
    final device = _selectedDevice;
    if (device == null) {
      await showAppMessage(
        context,
        title: '信息不完整',
        message: '请选择品牌、型号和容量。',
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

  Future<String?> _chooseRecognizedModel(
    String brand,
    List<dynamic> models,
  ) async {
    String? selected;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.help_outline, color: Colors.orange, size: 56),
          title: const Text('请确认具体型号', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '识别到 ${_brandNames[brand] ?? brand} 系列\n外观无法区分具体版本，请选择型号。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '候选型号',
                  border: OutlineInputBorder(),
                ),
                items: models
                    .map(
                      (model) => DropdownMenuItem<String>(
                        value: model.toString(),
                        child: Text(model.toString()),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setDialogState(() => selected = value),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(context, selected),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_recognizing,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('二手手机估价'),
        ),
        body: Stack(
          children: [
            AbsorbPointer(
              absorbing: _recognizing,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                children: [
                  if (widget.smartOnly) ...[
                    Text(
                      '拍照后识别机型',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                  ],
                   if (!widget.manualOnly && !widget.fallbackOnly) Row(
                    children: [
                      Expanded(
                        child: _PhotoBox(
                          label: '正面',
                          image: _frontImage,
                          onTap: _pickFront,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _PhotoBox(
                          label: '背面',
                          image: _backImage,
                          onTap: _pickBack,
                        ),
                      ),
                    ],
                  ),
                  if (!widget.manualOnly && !widget.fallbackOnly)
                    const SizedBox(height: 16),
                   if (!widget.manualOnly && !widget.fallbackOnly) SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _recognize,
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(_loading ? '正在识别...' : '智能识别机型'),
                    ),
                  ),
                  if (widget.manualOnly) ...[
                    Text(
                    key: _manualSelectionKey,
                    '手动选择机型',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.manualOnly) TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: '直接搜索型号',
                      hintText: '例如：K40、Mate 60、iPhone 15',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {
                      _selectedSearchResult = null;
                      _selectedBrand = null;
                      _selectedModel = null;
                      _selectedStorage = null;
                    }),
                  ),
                   if (widget.manualOnly && _searchController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_searchController.text),
                      initialValue:
                          _modelSearchResults.any(
                            (result) =>
                                '${result.brand}\u0000${result.model}' ==
                                _selectedSearchResult,
                          )
                          ? _selectedSearchResult
                          : null,
                      menuMaxHeight: 320,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _modelSearchResults.isEmpty
                            ? '没有找到匹配机型'
                            : '搜索结果（${_modelSearchResults.length}）',
                        border: const OutlineInputBorder(),
                      ),
                      items: _modelSearchResults
                          .map(
                            (result) => DropdownMenuItem(
                              value: '${result.brand}\u0000${result.model}',
                              child: Text(
                                '${_brandNames[result.brand] ?? result.brand} · ${result.model}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _selectSearchResult,
                    ),
                  ],
                    if (widget.manualOnly) const SizedBox(height: 12),
                    if (widget.manualOnly) DropdownButtonFormField<String>(
                    initialValue: _selectedBrand,
                    menuMaxHeight: 320,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '品牌',
                      border: OutlineInputBorder(),
                    ),
                    items: _brands
                        .map(
                          (brand) => DropdownMenuItem(
                            value: brand,
                            child: Text(
                              _brandNames[brand] ?? brand,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (brand) => setState(() {
                      _selectedBrand = brand;
                      _selectedModel = null;
                      _selectedStorage = null;
                      _selectedSearchResult = null;
                      _searchController.clear();
                    }),
                  ),
                   if (widget.manualOnly) const SizedBox(height: 12),
                   if (widget.manualOnly) DropdownButtonFormField<String>(
                    key: ValueKey(_selectedBrand),
                    initialValue: _models.contains(_selectedModel)
                        ? _selectedModel
                        : null,
                    menuMaxHeight: 320,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '型号',
                      border: OutlineInputBorder(),
                    ),
                    items: _models
                        .map(
                          (model) => DropdownMenuItem(
                            value: model,
                            child: Text(model, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (model) => setState(() {
                      _selectedModel = model;
                      _selectedStorage = null;
                    }),
                  ),
                    if (widget.manualOnly) const SizedBox(height: 12),
                    if (widget.manualOnly) DropdownButtonFormField<int>(
                    key: ValueKey(Object.hash(_selectedBrand, _selectedModel)),
                    initialValue: _storages.contains(_selectedStorage)
                        ? _selectedStorage
                        : null,
                    menuMaxHeight: 320,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '容量',
                      border: OutlineInputBorder(),
                    ),
                    items: _storages
                        .map(
                          (storage) => DropdownMenuItem(
                            value: storage,
                            child: Text('${storage}GB'),
                          ),
                        )
                        .toList(),
                    onChanged: (storage) =>
                        setState(() => _selectedStorage = storage),
                  ),
                    if (widget.manualOnly) const SizedBox(height: 24),
                    if (widget.manualOnly) SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _next,
                      child: const Text('下一步：选择成色'),
                    ),
                  ),
                ],
              ),
            ),
            if (_recognizing)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: Card(
                      margin: const EdgeInsets.all(32),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 28,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            SizedBox(
                              width: 52,
                              height: 52,
                              child: CircularProgressIndicator(strokeWidth: 5),
                            ),
                            SizedBox(height: 22),
                            Text(
                              '正在识别手机',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              '请稍候，识别完成前不能进行其他操作',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
          borderRadius: BorderRadius.circular(12),
        ),
        child: image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(image!, fit: BoxFit.cover),
              )
            : Center(child: Text('点击拍摄手机$label', textAlign: TextAlign.center)),
      ),
    );
  }
}

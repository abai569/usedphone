class Device {
  final int id;
  final String brand;
  final String model;
  final int storage;
  final int launchYear;
  final double basePrice;

  Device({
    required this.id,
    required this.brand,
    required this.model,
    required this.storage,
    required this.launchYear,
    required this.basePrice,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as int,
      brand: json['brand'] as String,
      model: json['model'] as String,
      storage: json['storage'] as int,
      launchYear: json['launch_year'] as int,
      basePrice: (json['base_price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand': brand,
        'model': model,
        'storage': storage,
        'launch_year': launchYear,
        'base_price': basePrice,
      };
}

class AppraisalResult {
  final double min;
  final double mid;
  final double max;

  AppraisalResult({required this.min, required this.mid, required this.max});

  factory AppraisalResult.fromJson(Map<String, dynamic> json) {
    return AppraisalResult(
      min: (json['min'] as num).toDouble(),
      mid: (json['mid'] as num).toDouble(),
      max: (json['max'] as num).toDouble(),
    );
  }
}

class ActivationResult {
  final String status;
  final String? expiresAt;
  final String? token;
  final String? error;

  ActivationResult({required this.status, this.expiresAt, this.token, this.error});

  factory ActivationResult.fromJson(Map<String, dynamic> json) {
    return ActivationResult(
      status: json['status'] as String? ?? 'inactive',
      expiresAt: json['expires_at'] as String?,
      token: json['token'] as String?,
      error: json['error'] as String?,
    );
  }

  bool get isActive => status == 'active';
}

class RecognizeResult {
  final String status;
  final bool recognized;
  final Map<String, dynamic>? suggestion;

  RecognizeResult({required this.status, required this.recognized, this.suggestion});

  factory RecognizeResult.fromJson(Map<String, dynamic> json) {
    final recognized = json['recognized'] as bool? ?? false;
    return RecognizeResult(
      status: json['status'] as String? ?? (recognized ? 'exact' : 'unknown'),
      recognized: recognized,
      suggestion: json['suggestion'] as Map<String, dynamic>?,
    );
  }
}

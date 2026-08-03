/// Fee Estimate Model
class FeeEstimate {
  final String blockchain;
  final FeeSpeed? speed;
  final double feeInNative;
  final double feeInUsd;
  final String? estimatedTime;
  final Map<String, dynamic>? details;
  final DateTime fetchedAt;
  final bool isManual;

  const FeeEstimate({
    required this.blockchain,
    this.speed,
    required this.feeInNative,
    required this.feeInUsd,
    this.estimatedTime,
    this.details,
    required this.fetchedAt,
    this.isManual = false,
  });

  factory FeeEstimate.manual({
    required String blockchain,
    required double feeInNative,
    required double feeInUsd,
  }) =>
      FeeEstimate(
        blockchain: blockchain,
        feeInNative: feeInNative,
        feeInUsd: feeInUsd,
        fetchedAt: DateTime.now(),
        isManual: true,
      );

  FeeEstimate copyWith({
    String? blockchain,
    FeeSpeed? speed,
    double? feeInNative,
    double? feeInUsd,
    String? estimatedTime,
    Map<String, dynamic>? details,
    DateTime? fetchedAt,
    bool? isManual,
  }) =>
      FeeEstimate(
        blockchain: blockchain ?? this.blockchain,
        speed: speed ?? this.speed,
        feeInNative: feeInNative ?? this.feeInNative,
        feeInUsd: feeInUsd ?? this.feeInUsd,
        estimatedTime: estimatedTime ?? this.estimatedTime,
        details: details ?? this.details,
        fetchedAt: fetchedAt ?? this.fetchedAt,
        isManual: isManual ?? this.isManual,
      );

  Map<String, dynamic> toJson() => {
        'blockchain': blockchain,
        'speed': speed?.name,
        'feeInNative': feeInNative,
        'feeInUsd': feeInUsd,
        'estimatedTime': estimatedTime,
        'details': details,
        'fetchedAt': fetchedAt.toIso8601String(),
        'isManual': isManual,
      };

  factory FeeEstimate.fromJson(Map<String, dynamic> json) => FeeEstimate(
        blockchain: json['blockchain'] as String,
        speed: json['speed'] != null
            ? FeeSpeed.values.firstWhere((e) => e.name == json['speed'])
            : null,
        feeInNative: (json['feeInNative'] as num).toDouble(),
        feeInUsd: (json['feeInUsd'] as num).toDouble(),
        estimatedTime: json['estimatedTime'] as String?,
        details: json['details'] as Map<String, dynamic>?,
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
        isManual: json['isManual'] as bool? ?? false,
      );
}

enum FeeSpeed { slow, normal, fast }

extension FeeSpeedExtension on FeeSpeed {
  String get displayName {
    switch (this) {
      case FeeSpeed.slow:   return 'Slow';
      case FeeSpeed.normal: return 'Normal';
      case FeeSpeed.fast:   return 'Fast';
    }
  }
}

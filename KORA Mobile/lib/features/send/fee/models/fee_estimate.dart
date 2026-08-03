/// Fee Estimate Model
/// Represents fee estimation for a blockchain transaction
class FeeEstimate {
  /// Blockchain identifier (e.g., 'bitcoin', 'ethereum')
  final String blockchain;
  
  /// Fee speed option (slow, normal, fast) - null if not supported
  final FeeSpeed? speed;
  
  /// Fee amount in native token (e.g., BTC, ETH, SOL)
  final double feeInNative;
  
  /// Fee amount in USD (for display)
  final double feeInUsd;
  
  /// Estimated confirmation time (e.g., "~10 min", "~30 sec")
  final String? estimatedTime;
  
  /// Additional details specific to blockchain
  /// For Bitcoin: sat/vB
  /// For Ethereum: gas price in Gwei, gas limit
  /// For Tron: bandwidth + energy costs
  final Map<String, dynamic>? details;
  
  /// Timestamp when this fee was fetched
  final DateTime fetchedAt;
  
  /// Whether this is a fallback/manual fee
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

  /// Create a manual fee estimate (when API fails)
  factory FeeEstimate.manual({
    required String blockchain,
    required double feeInNative,
    required double feeInUsd,
  }) {
    return FeeEstimate(
      blockchain: blockchain,
      feeInNative: feeInNative,
      feeInUsd: feeInUsd,
      fetchedAt: DateTime.now(),
      isManual: true,
    );
  }

  /// Copy with method for updating fields
  FeeEstimate copyWith({
    String? blockchain,
    FeeSpeed? speed,
    double? feeInNative,
    double? feeInUsd,
    String? estimatedTime,
    Map<String, dynamic>? details,
    DateTime? fetchedAt,
    bool? isManual,
  }) {
    return FeeEstimate(
      blockchain: blockchain ?? this.blockchain,
      speed: speed ?? this.speed,
      feeInNative: feeInNative ?? this.feeInNative,
      feeInUsd: feeInUsd ?? this.feeInUsd,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      details: details ?? this.details,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      isManual: isManual ?? this.isManual,
    );
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'blockchain': blockchain,
      'speed': speed?.name,
      'feeInNative': feeInNative,
      'feeInUsd': feeInUsd,
      'estimatedTime': estimatedTime,
      'details': details,
      'fetchedAt': fetchedAt.toIso8601String(),
      'isManual': isManual,
    };
  }

  /// Create from JSON (for cache retrieval)
  factory FeeEstimate.fromJson(Map<String, dynamic> json) {
    return FeeEstimate(
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

  @override
  String toString() {
    return 'FeeEstimate(blockchain: $blockchain, speed: ${speed?.name}, '
           'feeInNative: $feeInNative, feeInUsd: \$$feeInUsd, '
           'estimatedTime: $estimatedTime, isManual: $isManual)';
  }
}

/// Fee speed options for blockchains that support variable fees
enum FeeSpeed {
  slow,    // Lowest fee, longer confirmation
  normal,  // Medium fee, medium confirmation
  fast,    // Highest fee, fastest confirmation
}

extension FeeSpeedExtension on FeeSpeed {
  String get displayName {
    switch (this) {
      case FeeSpeed.slow:
        return 'Slow';
      case FeeSpeed.normal:
        return 'Normal';
      case FeeSpeed.fast:
        return 'Fast';
    }
  }
}

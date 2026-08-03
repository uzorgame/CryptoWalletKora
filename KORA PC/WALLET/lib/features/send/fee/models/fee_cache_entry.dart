import 'fee_estimate.dart';

class FeeCacheEntry {
  final FeeEstimate feeEstimate;
  final DateTime cachedAt;
  final Duration cacheDuration;

  /// The longest a fee may be reused, whatever the entry says.
  ///
  /// Ninety seconds, not a day. A network fee is a live quote — gas moves within a block — and
  /// a day-old figure shown next to a SIGN AND SEND button is a number the user is being asked
  /// to agree to that has nothing to do with what they will pay. The cache exists to spare a
  /// request while the form is being filled in, not to survive the session.
  static const maxAge = Duration(seconds: 90);

  const FeeCacheEntry({
    required this.feeEstimate,
    required this.cachedAt,
    this.cacheDuration = maxAge,
  });

  /// Capped at [maxAge] rather than trusted.
  ///
  /// Entries written by earlier versions carry `cacheDuration: 24h` in their own JSON, so
  /// changing only the default would have left real machines serving a fee cached seventeen
  /// hours earlier — one was, on the machine this was tested on. An entry's stored lifetime
  /// can shorten the window but never extend it.
  Duration get _effective => cacheDuration < maxAge ? cacheDuration : maxAge;

  bool get isValid => DateTime.now().isBefore(cachedAt.add(_effective));

  Duration get timeUntilExpiry {
    final remaining = cachedAt.add(_effective).difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  factory FeeCacheEntry.create(FeeEstimate feeEstimate) =>
      FeeCacheEntry(feeEstimate: feeEstimate, cachedAt: DateTime.now());

  Map<String, dynamic> toJson() => {
        'feeEstimate': feeEstimate.toJson(),
        'cachedAt': cachedAt.toIso8601String(),
        'cacheDuration': cacheDuration.inMilliseconds,
      };

  factory FeeCacheEntry.fromJson(Map<String, dynamic> json) => FeeCacheEntry(
        feeEstimate: FeeEstimate.fromJson(json['feeEstimate'] as Map<String, dynamic>),
        cachedAt: DateTime.parse(json['cachedAt'] as String),
        cacheDuration: Duration(milliseconds: json['cacheDuration'] as int? ?? 90000),
      );
}

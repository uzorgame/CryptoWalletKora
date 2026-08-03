// One movement of one asset, as an explorer reported it.
//
// A model, so it lives with the other models rather than inside the service that happens to
// build it. Every screen passes these around, and none of them should have to import a
// network client in order to name the type it is holding.

enum TxDirection { incoming, outgoing, self }

class TxRecord {
  final String hash;
  final String from;
  final String to;
  final double amount;
  final String symbol;
  final DateTime timestamp;
  final TxDirection direction;
  final bool confirmed;
  final double? feePaid;
  final String blockchain;

  const TxRecord({
    required this.hash,
    required this.from,
    required this.to,
    required this.amount,
    required this.symbol,
    required this.timestamp,
    required this.direction,
    required this.confirmed,
    required this.blockchain,
    this.feePaid,
  });

  String get shortHash =>
      hash.length > 16 ? '${hash.substring(0, 8)}…${hash.substring(hash.length - 6)}' : hash;

  String get shortFrom =>
      from.length > 14 ? '${from.substring(0, 6)}…${from.substring(from.length - 4)}' : from;

  String get shortTo =>
      to.length > 14 ? '${to.substring(0, 6)}…${to.substring(to.length - 4)}' : to;
}

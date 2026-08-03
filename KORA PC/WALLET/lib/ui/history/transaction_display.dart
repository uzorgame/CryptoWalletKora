import '../../core/services/tx_history_service.dart';

/// Presentation helpers over the record the history service actually produces.
///
/// `TxRecord`, not the freezed `Transaction` model. The model looked canonical and is used by
/// nothing: every path that fetches history — every chain — returns `TxRecord`. Building the
/// history screens on the other one would have meant a conversion layer between the app and
/// itself, which is exactly the kind of seam that quietly disagrees with reality.
extension TxRecordDisplay on TxRecord {
  bool get incoming => direction == TxDirection.incoming;

  /// A transfer between the user's own addresses is neither a gain nor a loss, and showing it
  /// as either would misstate the history.
  bool get isSelfTransfer => direction == TxDirection.self;

  /// The other party. Which end that is depends on which way the value went.
  String get counterparty => incoming ? from : to;
}

import 'package:kora/core/blockchain/bitcoin/bitcoin_service.dart';

/// Bitcoin Transaction Builder
/// Створює та підписує Bitcoin транзакції з UTXO
class BitcoinTransactionBuilder {
  final List<UTXO> _inputs = [];
  final List<TransactionOutput> _outputs = [];
  
  BitcoinTransactionBuilder();
  
  /// Add input UTXO
  void addInput(UTXO utxo) {
    _inputs.add(utxo);
  }
  
  /// Add multiple inputs
  void addInputs(List<UTXO> utxos) {
    _inputs.addAll(utxos);
  }
  
  /// Add output
  void addOutput(String address, int amount) {
    _outputs.add(TransactionOutput(address: address, amount: amount));
  }
  
  /// Calculate total input value
  int get totalInput {
    return _inputs.fold(0, (sum, utxo) => sum + utxo.value);
  }
  
  /// Calculate total output value
  int get totalOutput {
    return _outputs.fold(0, (sum, output) => sum + output.amount);
  }
  
  /// Build transaction for sending
  /// Returns change amount if any
  /// Fee must be provided by the caller (from new Fee system)
  BitcoinTransactionResult build({
    required String changeAddress,
    required int fee,
  }) {
    final change = totalInput - totalOutput - fee;
    
    if (change < 0) {
      throw BitcoinTransactionException(
        'Insufficient funds. Need ${-change} more satoshis',
      );
    }
    
    // Add change output if significant (> dust limit)
    final dustLimit = 546; // satoshis
    if (change > dustLimit) {
      addOutput(changeAddress, change);
    }
    
    return BitcoinTransactionResult(
      inputs: List.from(_inputs),
      outputs: List.from(_outputs),
      fee: fee,
      change: change > dustLimit ? change : 0,
    );
  }
  
  /// Clear all inputs and outputs
  void clear() {
    _inputs.clear();
    _outputs.clear();
  }
}

/// Transaction Output
class TransactionOutput {
  final String address;
  final int amount; // satoshis
  
  TransactionOutput({
    required this.address,
    required this.amount,
  });
  
  @override
  String toString() => 'Output($address: $amount sats)';
}

/// Bitcoin Transaction Result
class BitcoinTransactionResult {
  final List<UTXO> inputs;
  final List<TransactionOutput> outputs;
  final int fee;
  final int change;
  
  BitcoinTransactionResult({
    required this.inputs,
    required this.outputs,
    required this.fee,
    required this.change,
  });
  
  /// Get total input value
  int get totalInput => inputs.fold(0, (sum, utxo) => sum + utxo.value);
  
  /// Get total output value
  int get totalOutput => outputs.fold(0, (sum, output) => sum + output.amount);
  
  /// Get transaction summary
  String getSummary() {
    return '''
Transaction Summary:
- Inputs: ${inputs.length} (${totalInput} sats)
- Outputs: ${outputs.length} (${totalOutput} sats)
- Fee: $fee sats
- Change: $change sats
''';
  }
  
  @override
  String toString() => getSummary();
}

/// Bitcoin Transaction Exception
class BitcoinTransactionException implements Exception {
  final String message;
  BitcoinTransactionException(this.message);
  
  @override
  String toString() => 'BitcoinTransactionException: $message';
}

/// UTXO Selection Strategies
enum UTXOSelectionStrategy {
  /// Select smallest UTXOs first (minimize change)
  smallest,
  
  /// Select largest UTXOs first (minimize inputs)
  largest,
  
  /// Greedy selection (first fit)
  greedy,
  
  /// Branch and bound (optimal)
  branchAndBound,
}


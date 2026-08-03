
/// Tron Transaction Builder
/// Створює та підписує Tron транзакції
class TronTransactionBuilder {
  String? _ownerAddress;
  String? _toAddress;
  int? _amount;
  String? _contractAddress;
  String? _functionSelector;
  String? _parameter;
  
  /// Set owner address (from)
  void setOwnerAddress(String address) {
    _ownerAddress = address;
  }
  
  /// Set recipient address (to)
  void setToAddress(String address) {
    _toAddress = address;
  }
  
  /// Set amount (in sun for TRX, or token amount for TRC20)
  void setAmount(int amount) {
    _amount = amount;
  }
  
  /// Set contract address (for TRC20 transfers)
  void setContractAddress(String address) {
    _contractAddress = address;
  }
  
  /// Set function selector (for smart contract calls)
  void setFunctionSelector(String selector) {
    _functionSelector = selector;
  }
  
  /// Set parameter (for smart contract calls)
  void setParameter(String parameter) {
    _parameter = parameter;
  }
  
  /// Build TRX transfer transaction
  TronTransaction buildTransferTRX() {
    if (_ownerAddress == null || _toAddress == null || _amount == null) {
      throw TronTransactionException('Missing required fields for TRX transfer');
    }
    
    return TronTransaction(
      type: TronTransactionType.transfer,
      ownerAddress: _ownerAddress!,
      toAddress: _toAddress!,
      amount: _amount!,
    );
  }
  
  /// Build TRC20 transfer transaction
  TronTransaction buildTransferTRC20() {
    if (_ownerAddress == null || _contractAddress == null || _toAddress == null || _amount == null) {
      throw TronTransactionException('Missing required fields for TRC20 transfer');
    }
    
    return TronTransaction(
      type: TronTransactionType.trc20Transfer,
      ownerAddress: _ownerAddress!,
      toAddress: _toAddress!,
      amount: _amount!,
      contractAddress: _contractAddress,
    );
  }
  
  /// Build smart contract call transaction
  TronTransaction buildContractCall() {
    if (_ownerAddress == null || _contractAddress == null || _functionSelector == null) {
      throw TronTransactionException('Missing required fields for contract call');
    }
    
    return TronTransaction(
      type: TronTransactionType.contractCall,
      ownerAddress: _ownerAddress!,
      contractAddress: _contractAddress,
      functionSelector: _functionSelector,
      parameter: _parameter,
    );
  }
  
  /// Clear all fields
  void clear() {
    _ownerAddress = null;
    _toAddress = null;
    _amount = null;
    _contractAddress = null;
    _functionSelector = null;
    _parameter = null;
  }
}

/// Tron Transaction
class TronTransaction {
  final TronTransactionType type;
  final String ownerAddress;
  final String? toAddress;
  final int? amount;
  final String? contractAddress;
  final String? functionSelector;
  final String? parameter;
  final String? signature;
  final String? txId;
  
  TronTransaction({
    required this.type,
    required this.ownerAddress,
    this.toAddress,
    this.amount,
    this.contractAddress,
    this.functionSelector,
    this.parameter,
    this.signature,
    this.txId,
  });
  
  /// Get transaction type name
  String get typeName {
    switch (type) {
      case TronTransactionType.transfer:
        return 'TRX Transfer';
      case TronTransactionType.trc20Transfer:
        return 'TRC20 Transfer';
      case TronTransactionType.contractCall:
        return 'Contract Call';
    }
  }
  
  /// Get estimated bandwidth usage
  int get estimatedBandwidth {
    switch (type) {
      case TronTransactionType.transfer:
        return 268; // Simple TRX transfer
      case TronTransactionType.trc20Transfer:
        return 345; // TRC20 transfer
      case TronTransactionType.contractCall:
        return 400; // Contract call (varies)
    }
  }
  
  /// Get estimated energy usage
  int get estimatedEnergy {
    switch (type) {
      case TronTransactionType.transfer:
        return 0; // TRX transfer uses no energy
      case TronTransactionType.trc20Transfer:
        return 31000; // TRC20 transfer
      case TronTransactionType.contractCall:
        return 50000; // Contract call (varies)
    }
  }
  
  /// Serialize transaction to JSON
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'type': type.toString(),
      'owner_address': ownerAddress,
    };
    
    if (toAddress != null) json['to_address'] = toAddress;
    if (amount != null) json['amount'] = amount;
    if (contractAddress != null) json['contract_address'] = contractAddress;
    if (functionSelector != null) json['function_selector'] = functionSelector;
    if (parameter != null) json['parameter'] = parameter;
    if (signature != null) json['signature'] = signature;
    if (txId != null) json['txID'] = txId;
    
    return json;
  }
  
  /// Create transaction from JSON
  factory TronTransaction.fromJson(Map<String, dynamic> json) {
    return TronTransaction(
      type: _parseTransactionType(json['type']),
      ownerAddress: json['owner_address'],
      toAddress: json['to_address'],
      amount: json['amount'],
      contractAddress: json['contract_address'],
      functionSelector: json['function_selector'],
      parameter: json['parameter'],
      signature: json['signature'],
      txId: json['txID'],
    );
  }
  
  static TronTransactionType _parseTransactionType(String type) {
    if (type.contains('transfer')) return TronTransactionType.transfer;
    if (type.contains('trc20')) return TronTransactionType.trc20Transfer;
    return TronTransactionType.contractCall;
  }
  
  /// Get transaction summary
  String getSummary() {
    final buffer = StringBuffer();
    buffer.writeln('Tron Transaction:');
    buffer.writeln('- Type: $typeName');
    buffer.writeln('- From: $ownerAddress');
    if (toAddress != null) buffer.writeln('- To: $toAddress');
    if (amount != null) buffer.writeln('- Amount: $amount sun');
    if (contractAddress != null) buffer.writeln('- Contract: $contractAddress');
    buffer.writeln('- Bandwidth: $estimatedBandwidth');
    buffer.writeln('- Energy: $estimatedEnergy');
    if (txId != null) buffer.writeln('- TxID: $txId');
    
    return buffer.toString();
  }
  
  @override
  String toString() => getSummary();
}

/// Tron Transaction Types
enum TronTransactionType {
  /// Simple TRX transfer
  transfer,
  
  /// TRC20 token transfer
  trc20Transfer,
  
  /// Smart contract call
  contractCall,
}

/// TRC20 Transfer Helper
class TRC20TransferHelper {
  /// Build TRC20 transfer transaction
  static TronTransaction buildTransfer({
    required String from,
    required String to,
    required String contractAddress,
    required int amount,
  }) {
    final builder = TronTransactionBuilder();
    builder.setOwnerAddress(from);
    builder.setToAddress(to);
    builder.setContractAddress(contractAddress);
    builder.setAmount(amount);
    
    return builder.buildTransferTRC20();
  }
  
  /// Encode transfer function call
  static String encodeTransferCall(String toAddress, int amount) {
    // TRC20 transfer function signature: transfer(address,uint256)
    // Function selector: a9059cbb
    // Parameter: address (32 bytes) + amount (32 bytes)
    
    final addressHex = _encodeAddress(toAddress);
    final amountHex = _encodeUint256(amount);
    
    return 'a9059cbb$addressHex$amountHex';
  }
  
  /// Encode address to 32 bytes hex
  static String _encodeAddress(String address) {
    // Remove 'T' prefix and convert to hex
    final hex = address.substring(1);
    return hex.padLeft(64, '0');
  }
  
  /// Encode uint256 to 32 bytes hex
  static String _encodeUint256(int value) {
    final hex = value.toRadixString(16);
    return hex.padLeft(64, '0');
  }
}

/// Tron Transaction Utils
class TronTransactionUtils {
  /// Calculate transaction fee in TRX
  /// Tron uses bandwidth and energy instead of gas fees
  static double calculateFee({
    required int bandwidth,
    required int energy,
    required bool hasBandwidth,
    required bool hasEnergy,
  }) {
    double fee = 0.0;
    
    // If no free bandwidth, burn TRX (1000 sun per bandwidth point)
    if (!hasBandwidth) {
      fee += (bandwidth * 1000) / 1000000; // Convert sun to TRX
    }
    
    // If no free energy, burn TRX (420 sun per energy point)
    if (!hasEnergy) {
      fee += (energy * 420) / 1000000; // Convert sun to TRX
    }
    
    return fee;
  }
  
  /// Estimate total cost for transaction
  static double estimateTotalCost({
    required TronTransaction transaction,
    required bool hasBandwidth,
    required bool hasEnergy,
  }) {
    final fee = calculateFee(
      bandwidth: transaction.estimatedBandwidth,
      energy: transaction.estimatedEnergy,
      hasBandwidth: hasBandwidth,
      hasEnergy: hasEnergy,
    );
    
    final amountInTrx = (transaction.amount ?? 0) / 1000000;
    
    return amountInTrx + fee;
  }
}

/// Tron Transaction Exception
class TronTransactionException implements Exception {
  final String message;
  TronTransactionException(this.message);
  
  @override
  String toString() => 'TronTransactionException: $message';
}

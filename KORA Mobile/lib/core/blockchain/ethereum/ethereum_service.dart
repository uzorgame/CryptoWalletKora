import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';

/// Ethereum Service for blockchain interactions
class EthereumService {
  late final Web3Client _client;
  final String _rpcUrl;
  final int _chainId;

  EthereumService({
    required String rpcUrl,
    required int chainId,
  })  : _rpcUrl = rpcUrl,
        _chainId = chainId {
    _client = Web3Client(_rpcUrl, Client());
  }

  /// Get ETH balance
  Future<EtherAmount> getBalance(String address) async {
    return await _client.getBalance(EthereumAddress.fromHex(address));
  }

  /// Get ETH balance as double
  Future<double> getBalanceInEther(String address) async {
    final balance = await getBalance(address);
    return balance.getValueInUnit(EtherUnit.ether);
  }

  /// Get ERC20 token balance
  Future<BigInt> getTokenBalance({
    required String tokenAddress,
    required String walletAddress,
  }) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(_erc20ABI, 'ERC20'),
      EthereumAddress.fromHex(tokenAddress),
    );

    final balanceFunction = contract.function('balanceOf');
    final result = await _client.call(
      contract: contract,
      function: balanceFunction,
      params: [EthereumAddress.fromHex(walletAddress)],
    );

    return result.first as BigInt;
  }

  /// Get token decimals
  Future<int> getTokenDecimals(String tokenAddress) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(_erc20ABI, 'ERC20'),
      EthereumAddress.fromHex(tokenAddress),
    );

    final decimalsFunction = contract.function('decimals');
    final result = await _client.call(
      contract: contract,
      function: decimalsFunction,
      params: [],
    );

    return (result.first as BigInt).toInt();
  }

  /// Get token symbol
  Future<String> getTokenSymbol(String tokenAddress) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(_erc20ABI, 'ERC20'),
      EthereumAddress.fromHex(tokenAddress),
    );

    final symbolFunction = contract.function('symbol');
    final result = await _client.call(
      contract: contract,
      function: symbolFunction,
      params: [],
    );

    return result.first as String;
  }

  /// Get token name
  Future<String> getTokenName(String tokenAddress) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(_erc20ABI, 'ERC20'),
      EthereumAddress.fromHex(tokenAddress),
    );

    final nameFunction = contract.function('name');
    final result = await _client.call(
      contract: contract,
      function: nameFunction,
      params: [],
    );

    return result.first as String;
  }

  /// Send ETH
  Future<String> sendETH({
    required EthPrivateKey from,
    required String to,
    required EtherAmount amount,
    EtherAmount? gasPrice,
    int? maxGas,
  }) async {
    // Always supply gasPrice + maxGas so web3dart never calls estimateGas.
    // estimateGas can fail with "gas required exceeds allowance" when the
    // amount is close to the full balance (e.g. MAX send).
    final gp        = gasPrice ?? await _client.getGasPrice();
    final gasLimit  = maxGas ?? 21000;
    final gasCost   = gp.getInWei * BigInt.from(gasLimit);

    // Clamp value to (balance – gasCost) so gas-price drift between fee
    // estimation and actual send never causes "insufficient funds" errors.
    final balance    = await _client.getBalance(from.address);
    final maxSendable = balance.getInWei - gasCost;
    final actualValue = amount.getInWei > maxSendable && maxSendable > BigInt.zero
        ? EtherAmount.inWei(maxSendable)
        : amount;

    final transaction = Transaction(
      to: EthereumAddress.fromHex(to),
      value: actualValue,
      gasPrice: gp,
      maxGas: gasLimit,
    );

    return await _client.sendTransaction(
      from,
      transaction,
      chainId: _chainId,
    );
  }

  /// Send ERC20 token
  Future<String> sendToken({
    required EthPrivateKey from,
    required String tokenAddress,
    required String to,
    required BigInt amount,
    EtherAmount? gasPrice,
    int? maxGas,
  }) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(_erc20ABI, 'ERC20'),
      EthereumAddress.fromHex(tokenAddress),
    );

    final transferFunction = contract.function('transfer');

    // Explicitly set gasPrice + maxGas so web3dart never calls estimateGas.
    // estimateGas fails with "gas required exceeds allowance" when the ETH
    // balance is insufficient for gas (even though the token amount is fine).
    final gp       = gasPrice ?? await _client.getGasPrice();
    final gasLimit = maxGas ?? 65000; // standard ERC-20 transfer gas

    return await _client.sendTransaction(
      from,
      Transaction.callContract(
        contract: contract,
        function: transferFunction,
        parameters: [EthereumAddress.fromHex(to), amount],
        gasPrice: gp,
        maxGas: gasLimit,
      ),
      chainId: _chainId,
    );
  }

  /// Get transaction receipt
  Future<TransactionReceipt?> getTransactionReceipt(String txHash) async {
    return await _client.getTransactionReceipt(txHash);
  }

  /// Get transaction by hash
  Future<TransactionInformation?> getTransaction(String txHash) async {
    return await _client.getTransactionByHash(txHash);
  }

  /// Get current block number
  Future<int> getBlockNumber() async {
    return await _client.getBlockNumber();
  }

  /// Wait for transaction confirmation
  Future<TransactionReceipt> waitForTransaction(
    String txHash, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final startTime = DateTime.now();

    while (true) {
      final receipt = await getTransactionReceipt(txHash);

      if (receipt != null) {
        return receipt;
      }

      if (DateTime.now().difference(startTime) > timeout) {
        throw TimeoutException('Transaction confirmation timeout');
      }

      await Future.delayed(const Duration(seconds: 2));
    }
  }

  /// Dispose client
  void dispose() {
    _client.dispose();
  }

  // ERC20 ABI (minimal)
  static const String _erc20ABI = '''
[
  {
    "constant": true,
    "inputs": [],
    "name": "name",
    "outputs": [{"name": "", "type": "string"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "symbol",
    "outputs": [{"name": "", "type": "string"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "decimals",
    "outputs": [{"name": "", "type": "uint8"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [{"name": "_owner", "type": "address"}],
    "name": "balanceOf",
    "outputs": [{"name": "balance", "type": "uint256"}],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {"name": "_to", "type": "address"},
      {"name": "_value", "type": "uint256"}
    ],
    "name": "transfer",
    "outputs": [{"name": "", "type": "bool"}],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {"name": "_spender", "type": "address"},
      {"name": "_value", "type": "uint256"}
    ],
    "name": "approve",
    "outputs": [{"name": "", "type": "bool"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [
      {"name": "_owner", "type": "address"},
      {"name": "_spender", "type": "address"}
    ],
    "name": "allowance",
    "outputs": [{"name": "", "type": "uint256"}],
    "type": "function"
  }
]
''';
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}

import 'package:kora/core/blockchain/solana/solana_service.dart';

/// SPL Token Helper
/// Provides methods for interacting with SPL tokens on Solana
class SPLToken {
  final String mintAddress;
  final SolanaService service;
  
  SPLToken({
    required this.mintAddress,
    required this.service,
  });
  
  /// Get token account address for owner
  Future<String?> getTokenAccountAddress(String ownerAddress) async {
    try {
      final accounts = await service.getTokenAccountsByOwner(
        ownerAddress,
        mintAddress,
      );
      
      if (accounts.isEmpty) return null;
      
      return accounts.first['pubkey'] as String;
    } catch (e) {
      return null;
    }
  }
  
  /// Get token balance
  Future<double> getBalance(String tokenAccountAddress) async {
    return await service.getTokenBalance(tokenAccountAddress);
  }
  
  /// Get token balance for owner
  Future<double> getBalanceForOwner(String ownerAddress) async {
    final tokenAccount = await getTokenAccountAddress(ownerAddress);
    if (tokenAccount == null) return 0.0;
    
    return await getBalance(tokenAccount);
  }
  
  /// Get token metadata
  Future<SPLTokenMetadata?> getMetadata() async {
    try {
      // Get token account info
      final accountInfo = await service.getAccountInfo(mintAddress);
      if (accountInfo == null) return null;
      
      // Parse token metadata
      // In production, implement proper metadata parsing
      return SPLTokenMetadata(
        mintAddress: mintAddress,
        name: 'Unknown Token',
        symbol: 'UNKNOWN',
        decimals: 9,
        supply: 0,
      );
    } catch (e) {
      return null;
    }
  }
}

/// SPL Token Metadata
class SPLTokenMetadata {
  final String mintAddress;
  final String name;
  final String symbol;
  final int decimals;
  final int supply;
  final String? logoUri;
  
  SPLTokenMetadata({
    required this.mintAddress,
    required this.name,
    required this.symbol,
    required this.decimals,
    required this.supply,
    this.logoUri,
  });
  
  @override
  String toString() {
    return 'SPLToken($symbol: $name, decimals: $decimals)';
  }
}

/// Popular SPL Tokens (Mainnet)
class PopularSPLTokens {
  // Stablecoins
  static const String usdc = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
  static const String usdt = 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB';
  
  // Wrapped Tokens
  static const String weth = '7vfCXTUXx5WJV5JADk17DUJ4ksgau7utNKj4b963voxs';
  static const String wbtc = '9n4nbM75f5Ui33ZbPYXn59EwSgE8CGsHtAeTH5YFeJ9E';
  
  // DeFi Tokens
  static const String ray = '4k3Dyjzvzp8eMZWUXbBCjEvwSkkk59S5iCNLY3QrkX6R';
  static const String srm = 'SRMuApVNdxXokk5GT7XD5cUUgXMBCoAz2LHeuAoKWRt';
  
  /// Get token info by symbol
  static String? getAddressBySymbol(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'USDC':
        return usdc;
      case 'USDT':
        return usdt;
      case 'WETH':
        return weth;
      case 'WBTC':
        return wbtc;
      case 'RAY':
        return ray;
      case 'SRM':
        return srm;
      default:
        return null;
    }
  }
}

/// SPL Token Utils
class SPLTokenUtils {
  /// Convert token amount to human-readable format
  static String formatTokenAmount(int amount, int decimals) {
    final divisor = BigInt.from(10).pow(decimals);
    final wholePart = amount ~/ divisor.toInt();
    final fractionalPart = amount % divisor.toInt();
    
    if (fractionalPart == 0) {
      return wholePart.toString();
    }
    
    final fractionalStr = fractionalPart.toString().padLeft(decimals, '0');
    final trimmed = fractionalStr.replaceAll(RegExp(r'0+$'), '');
    
    if (trimmed.isEmpty) {
      return wholePart.toString();
    }
    
    return '$wholePart.$trimmed';
  }
  
  /// Convert human-readable amount to token amount
  static int parseTokenAmount(String amount, int decimals) {
    final parts = amount.split('.');
    final wholePart = int.parse(parts[0]);
    
    if (parts.length == 1) {
      return wholePart * BigInt.from(10).pow(decimals).toInt();
    }
    
    final fractionalPart = parts[1].padRight(decimals, '0').substring(0, decimals);
    final fractional = int.parse(fractionalPart);
    
    return wholePart * BigInt.from(10).pow(decimals).toInt() + fractional;
  }
  
  /// Derive associated token account address
  /// Simplified version - in production use proper derivation
  static String deriveAssociatedTokenAddress({
    required String ownerAddress,
    required String mintAddress,
  }) {
    // Simplified derivation
    // In production, implement proper PDA derivation
    return '$ownerAddress-$mintAddress';
  }
}

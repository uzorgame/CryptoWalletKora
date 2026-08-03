import 'package:kora_windows/core/config/api_config.dart';

/// Application Constants
class AppConstants {
  static const String appName = 'Kora Wallet';
  static const Duration networkTimeout = Duration(seconds: 30);
  
  /// Cache duration for on-chain balances (5 minutes)
  static const Duration balanceCacheExpiration = Duration(minutes: 5);
  
  /// Cache duration for transaction history (10 minutes)
  static const Duration historyCacheExpiration = Duration(minutes: 10);
}

/// API Keys Configuration
/// Use --dart-define to pass keys during build
class APIKeys {
  /// MetaMask Developer API Key (Infura Alternative)
  /// Отримати: https://developer.metamask.io/
  /// Email: KoraWalletUI@gmail.com
  /// 
  /// Використання:
  /// flutter run --dart-define=METAMASK_API_KEY=your_key
  static const String metamaskKey = String.fromEnvironment(
    'METAMASK_API_KEY',
    defaultValue: '',
  );
  
  /// Etherscan API Keys (separate for each chain)
  /// Отримати: https://etherscan.io/
  /// Username: KoraU
  /// Email: KoraWalletUI@gmail.com
  
  /// Ethereum API Key
  /// Використання: flutter run --dart-define=ETHERSCAN_ETH_KEY=your_key
  static const String etherscanEthKey = String.fromEnvironment(
    'ETHERSCAN_ETH_KEY',
    defaultValue: '',
  );
  
  /// BSC API Key
  /// Використання: flutter run --dart-define=ETHERSCAN_BSC_KEY=your_key
  static const String etherscanBscKey = String.fromEnvironment(
    'ETHERSCAN_BSC_KEY',
    defaultValue: '',
  );
  
  
  /// Legacy Etherscan API Key (fallback for other chains)
  /// Використання: flutter run --dart-define=ETHERSCAN_API_KEY=your_key
  static const String etherscanKey = String.fromEnvironment(
    'ETHERSCAN_API_KEY',
    defaultValue: '',
  );
  
  /// Get chain-specific Etherscan API key
  static String getEtherscanKey(String blockchain) {
    return switch (blockchain) {
      'ethereum' => etherscanEthKey.isNotEmpty ? etherscanEthKey : etherscanKey,
      'bsc'      => etherscanBscKey.isNotEmpty ? etherscanBscKey : etherscanKey,
      _          => etherscanKey,
    };
  }
  
  /// BlockCypher API Token (Bitcoin)
  /// Отримати: https://accounts.blockcypher.com/
  /// Email: KoraWalletUI@gmail.com
  /// 
  /// Використання:
  /// flutter run --dart-define=BLOCKCYPHER_TOKEN=your_token
  static const String blockcypherToken = String.fromEnvironment(
    'BLOCKCYPHER_TOKEN',
    defaultValue: '',
  );
  
  /// TronGrid API Key (Tron)
  /// Отримати: https://www.trongrid.io/
  /// Email: KoraWalletUI@gmail.com
  /// 
  /// Використання:
  /// flutter run --dart-define=TRONGRID_API_KEY=your_key
  static const String trongridKey = String.fromEnvironment(
    'TRONGRID_API_KEY',
    defaultValue: '',
  );
  
  /// CoinGecko API (не потрібен ключ для безкоштовного плану)
  static const String coingeckoKey = String.fromEnvironment(
    'COINGECKO_API_KEY',
    defaultValue: '', // Не потрібен
  );

}

/// CoinGecko API Endpoints
class CoinGeckoEndpoints {
  static const String baseUrl = APIConfig.coingeckoBaseUrl;
  
  // Simple Price
  static String simplePrice(String ids, String vsCurrencies) =>
    '$baseUrl/simple/price?ids=$ids&vs_currencies=$vsCurrencies&include_24hr_change=true';
  
  // Market Chart
  static String marketChart(String coinId, int days) =>
    '$baseUrl/coins/$coinId/market_chart?vs_currency=usd&days=$days';
  
  // Search
  static String search(String query) =>
    '$baseUrl/search?query=$query';
  
  // Trending
  static const String trending = '$baseUrl/search/trending';
}


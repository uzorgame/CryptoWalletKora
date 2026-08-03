// Keys that must not be published.
//
// This file is listed in .gitignore. A clone starts without it — copy api_secrets.example.dart
// over it and fill in your own keys. Everything else in api_config.dart is an endpoint, which
// is public by nature; only the values here are not.

class ApiSecrets {
  /// Solana history and RPC, from https://dashboard.helius.dev — the free tier is enough.
  ///
  /// Left empty, the Solana client falls back to the public mainnet endpoint, which works but
  /// is rate-limited hard enough that transaction history will often come back empty.
  static const String heliusApiKey = '';
}

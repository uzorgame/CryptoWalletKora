import 'package:kora/core/config/api_config.dart';

/// CDN fallback URL.
/// Priority: CoinGecko override (newer tokens) → cryptocurrency-icons GitHub repo.
String coinIconUrl(String symbol) {
  // Symbol renames for cryptocurrency-icons filenames
  const _symbolRenames = <String, String>{
  };
  // Newer tokens absent from cryptocurrency-icons → point to CoinGecko CDN
  const _coingecko = <String, String>{};
  final lower = symbol.toLowerCase();
  if (_coingecko.containsKey(lower)) return _coingecko[lower]!;
  final slug = _symbolRenames[lower] ?? lower;
  return '${APIConfig.cryptoIconsCdnBase}/$slug.png';
}

/// Circular coin icon.

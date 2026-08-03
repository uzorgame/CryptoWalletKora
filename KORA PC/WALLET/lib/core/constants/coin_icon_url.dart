import 'package:kora_windows/core/config/api_config.dart';

/// Where a coin's artwork lives.
///
/// The interface no longer draws coin artwork — the redesign is typographic, and a symbol set
/// in the right face carries an asset better than a fifteen-pixel logo does. This function
/// survives only because `Asset.iconUrl` is a persisted field: every wallet record already on
/// disk carries these strings, and the value has to keep being produced for records written
/// from now on to look like the ones written before.
///
/// It is a pure string function. What it replaced also bundled eleven PNGs, mapped symbols to
/// local asset paths, preloaded them into the image cache at startup, and pulled in
/// `cached_network_image` — which quietly wrote a cache index into the wallet's own data
/// directory, alongside the keys.
String coinIconUrl(String symbol) {
  const overrides = <String, String>{
    'eurc': 'https://assets.coingecko.com/coins/images/26045/standard/euro-coin.png',
  };
  final lower = symbol.toLowerCase();
  return overrides[lower] ?? '${APIConfig.cryptoIconsCdnBase}/$lower.png';
}

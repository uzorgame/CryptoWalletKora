import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kora/core/config/api_config.dart';
import 'package:kora/core/theme/app_theme.dart';

// ─── Local asset path lookup ──────────────────────────────────────────────────

/// Maps a ticker symbol to a local asset path inside assets/crypto_icons/.
/// Returns null if the icon is not bundled locally (falls back to CDN).
String? _localAssetPath(String symbol) {
  const _localIcons = <String>{
    'btc', 'eth', 'sol', 'bnb', 'trx', 'ltc',
    'usdt', 'usdc', 'dai',
    'bch', 'etc',
  };
  // Symbol aliases for filenames that differ from the ticker
  const _overrides = <String, String>{
  };
  final slug = _overrides[symbol.toLowerCase()] ?? symbol.toLowerCase();
  return _localIcons.contains(slug)
      ? 'assets/crypto_icons/$slug.png'
      : null;
}

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

// ─── Preloader ───────────────────────────────────────────────────────────────

/// Call once from the splash screen to warm the image cache for all
/// bundled local icons so they appear instantly throughout the app.
Future<void> preloadCoinIcons(BuildContext context) async {
  const _allLocal = <String>[
    'btc', 'eth', 'sol', 'bnb', 'trx', 'ltc',
    'usdt', 'usdc', 'dai',
    'bch', 'etc',
  ];
  await Future.wait([
    for (final sym in _allLocal)
      precacheImage(AssetImage('assets/crypto_icons/$sym.png'), context)
          .catchError((_) {}),
  ]);
}

// ─── CoinIcon widget ──────────────────────────────────────────────────────────

/// Circular coin icon.
/// Priority: local PNG asset → cached network image → letter avatar.
class CoinIcon extends StatelessWidget {
  const CoinIcon({
    super.key,
    required this.symbol,
    this.size = 40,
    this.iconUrl,
  });

  final String symbol;
  final double size;
  final String? iconUrl;

  @override
  Widget build(BuildContext context) {
    final color  = AppColors.coinColor(symbol);
    final letter = symbol.isNotEmpty ? symbol[0].toUpperCase() : '?';

    // 1️⃣  Try local bundled asset
    final localPath = _localAssetPath(symbol);
    if (localPath != null) {
      return _circleImage(AssetImage(localPath));
    }

    // 2️⃣  Try network image (custom iconUrl or CDN)
    final url = (iconUrl?.isNotEmpty == true) ? iconUrl! : coinIconUrl(symbol);
    return SizedBox(
      width: size,
      height: size,
      child: CachedNetworkImage(
        imageUrl: url,
        imageBuilder: (_, img) => _circleImage(img),
        placeholder: (_, __) => _letterAvatar(color, letter),
        errorWidget: (_, __, ___) => _letterAvatar(color, letter),
      ),
    );
  }

  Widget _circleImage(ImageProvider img) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          image: DecorationImage(image: img, fit: BoxFit.cover),
        ),
      );

  Widget _letterAvatar(Color color, String letter) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
        ),
        child: Center(
          child: Text(
            letter,
            style: TextStyle(
              color: color,
              fontSize: size * 0.42,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
}

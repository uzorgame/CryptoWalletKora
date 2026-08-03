import '../../core/models/asset.dart';

/// How a chain is named on screen.
///
/// `Asset.blockchain` is an internal key — `ethereum`, `bsc`, `tron`. The wallet has to show
/// two other things: the transfer standard a user checks before pasting an address (ERC20,
/// TRC20, BEP20) and the network's proper name. Getting this wrong is not cosmetic — a
/// correct address on the wrong chain loses the funds.
class ChainDisplay {
  const ChainDisplay(this.tag, this.network);

  /// The short standard shown on a row.
  final String tag;

  /// The full network name, for places with room to say it properly.
  final String network;

  static const _byBlockchain = <String, ChainDisplay>{
    'bitcoin': ChainDisplay('BTC', 'Bitcoin'),
    'litecoin': ChainDisplay('LTC', 'Litecoin'),
    'bitcoincash': ChainDisplay('BCH', 'Bitcoin Cash'),
    'bitcoin_cash': ChainDisplay('BCH', 'Bitcoin Cash'),
    'ethereum': ChainDisplay('ERC20', 'Ethereum'),
    'ethereum_classic': ChainDisplay('ETC', 'Ethereum Classic'),
    'ethereumclassic': ChainDisplay('ETC', 'Ethereum Classic'),
    'bsc': ChainDisplay('BEP20', 'BNB Smart Chain'),
    'binance': ChainDisplay('BEP20', 'BNB Smart Chain'),
    'tron': ChainDisplay('TRC20', 'Tron'),
    'solana': ChainDisplay('SOL', 'Solana'),
    'polygon': ChainDisplay('POL', 'Polygon'),
  };

  /// An unknown chain shows its own key rather than a guess. A wrong network name beside an
  /// address is worse than an unfamiliar one.
  static ChainDisplay of(String blockchain) {
    final key = blockchain.toLowerCase().replaceAll('-', '_');
    return _byBlockchain[key] ??
        ChainDisplay(blockchain.toUpperCase(), _titleCase(blockchain));
  }

  static String _titleCase(String value) => value
      .split(RegExp(r'[_\s-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

extension AssetChain on Asset {
  ChainDisplay get chain => ChainDisplay.of(blockchain);

  /// A native coin lives on its own chain; a token borrows one, and the standard is what the
  /// user has to match when they paste an address.
  String get chainTag => type == AssetType.native ? chain.network.toUpperCase().split(' ').first : chain.tag;
}

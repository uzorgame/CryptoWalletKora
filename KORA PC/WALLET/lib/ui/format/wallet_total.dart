import '../../core/models/wallet.dart';

extension WalletTotal on Wallet {
  /// What this wallet holds, in USD — or null if it has never been synced.
  ///
  /// Every `Wallet` persists its own assets, each carrying `balanceInUsd`, so this needs no
  /// network call and no key, for the open wallet and the closed ones alike. The switcher
  /// previously showed a dash for every wallet but the open one, which reads as "empty"
  /// rather than "not loaded".
  ///
  /// Null and zero are kept apart deliberately: a wallet with no assets yet is unknown, and
  /// showing it as $0.00 would state something about someone's money that has not been
  /// checked. That distinction is what the dash was originally for.
  ///
  /// Hidden coins are counted. Whether a coin appears on the portfolio is a display choice;
  /// money in it is still money, and a wallet total that quietly omitted some would be wrong.
  double? get storedValueUsd => assets.isEmpty
      ? null
      : assets.fold<double>(0, (sum, asset) => sum + asset.balanceInUsd);
}

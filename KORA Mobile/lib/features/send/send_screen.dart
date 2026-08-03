import 'package:flutter/material.dart';
import 'package:kora/features/send/chain_labels.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/config/api_config.dart';
import 'package:kora/core/crypto/key_manager.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/widgets/chips/coin_icon.dart';
import 'package:kora/features/address_book/address_book_screen.dart';
import 'package:kora/features/scan/qr_scanner_screen.dart';
// ─── Executor imports ─────────────────────────────────────────────────────────
import 'package:kora/features/send/executors/registry.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:kora/features/send/tx_success_screen.dart';
import 'package:kora/core/utils/page_transitions.dart';
// ─── Fee imports ──────────────────────────────────────────────────────────────
import 'package:kora/features/send/fee/models/fee_estimate.dart';
import 'package:kora/features/send/fee/bitcoin_fee/bitcoin_fee_provider.dart';
import 'package:kora/features/send/fee/ethereum_fee/ethereum_fee_provider.dart';
import 'package:kora/features/send/fee/solana_fee/solana_fee_provider.dart';
import 'package:kora/features/send/fee/tron_fee/tron_fee_provider.dart';
import 'package:kora/features/send/fee/litecoin_fee/litecoin_fee_provider.dart';
import 'package:kora/features/send/fee/bitcoin_cash_fee/bitcoin_cash_fee_provider.dart';
import 'package:kora/features/send/fee/bsc_fee/bsc_fee_provider.dart';
import 'package:kora/features/send/fee/ethereum_classic_fee/ethereum_classic_fee_provider.dart';
import 'package:kora/core/services/tx_history_service.dart';
import 'package:kora/features/send/review/review_sheet.dart';
import 'package:kora/features/send/fee/fee_widget.dart';
import 'package:kora/features/send/fee/fee_speed_selector.dart';
import 'package:kora/features/send/widgets/asset_badge.dart';
import 'package:kora/features/send/widgets/net_chip.dart';
import 'package:kora/features/send/widgets/unsupported_banner.dart';
import 'package:kora/features/send/widgets/section_label.dart';

// ─── Chain helpers ─────────────────────────────────────────────────────────────

bool _isEvm(String b)           => APIConfig.evmChains.contains(b);
bool _isTron(String b)          => b == 'tron';
bool _isSolana(String b)        => b == 'solana';
bool _isUtxo(String b)    => APIConfig.utxoChains.contains(b);

bool _sendSupported(Asset a) =>
    _isEvm(a.blockchain) || _isTron(a.blockchain) || _isSolana(a.blockchain) ||
    _isUtxo(a.blockchain);

// ─── SendScreen ───────────────────────────────────────────────────────────────

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key, required this.assets, this.initialAddress});
  final List<Asset> assets;
  final String? initialAddress;

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> with ThemeAwareMixin {
  final _toCtrl           = TextEditingController();
  final _amountCtrl       = TextEditingController();
  final _pickerSearchCtrl = TextEditingController();
  Asset?    _asset;
  bool      _loading      = false;
  String?   _addrErr;
  String?   _amountErr;
  String    _pickerQuery  = '';
  FeeSpeed  _selectedSpeed = FeeSpeed.normal;

  static const _speedSupportedChains = {
    'bitcoin', 'litecoin', 'bitcoin_cash',
  };

  /// Solana rent exemption for a system account (0 bytes data) = 890,880 lamports.
  /// The sender's account must retain at least this much after a transfer.
  static const _solRentExemption = 0.00089088;

  bool _supportsSpeedSelector(String blockchain) =>
      _speedSupportedChains.contains(blockchain);

  void _selectSpeed(FeeSpeed speed) {
    if (_selectedSpeed == speed || _asset == null) return;
    setState(() => _selectedSpeed = speed);
    _fetchFeeForAsset(_asset!);
    // Re-validate amount after provider has a chance to update
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkAmountAgainstFee();
    });
  }

  List<Asset> get _pickerFiltered {
    if (_pickerQuery.isEmpty) return widget.assets;
    final q = _pickerQuery.toLowerCase();
    return widget.assets.where((a) =>
        a.name.toLowerCase().contains(q) ||
        a.symbol.toLowerCase().contains(q) ||
        netLabel(a.blockchain).toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    // Auto-select only when coming from AssetDetailScreen (single asset)
    if (widget.assets.length == 1) {
      _asset = widget.assets.first;
      // Fetch fee for selected asset
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchFeeForAsset(_asset!);
      });
    }
    if (widget.initialAddress != null) {
      _toCtrl.text = widget.initialAddress!;
    }
    _toCtrl.addListener(_onAddrChanged);
    _amountCtrl.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _amountCtrl.dispose();
    _pickerSearchCtrl.dispose();
    super.dispose();
  }

  void _onAmountChanged() => _checkAmountAgainstFee();

  void _checkAmountAgainstFee() {
    final asset = _asset;
    if (asset == null || asset.type != AssetType.native) {
      if (_amountErr != null) setState(() => _amountErr = null);
      return;
    }
    final amt = double.tryParse(_amountCtrl.text.trim());
    if (amt == null || amt <= 0) {
      if (_amountErr != null) setState(() => _amountErr = null);
      return;
    }
    final fee = _readCurrentFee();
    if (fee == null || fee.feeInNative <= 0) {
      if (_amountErr != null) setState(() => _amountErr = null);
      return;
    }
    final sufficient = amt + fee.feeInNative <= asset.balanceAsDouble;
    final err = sufficient ? null : 'Insufficient funds at this fee. Tap MAX to update.';
    if (err != _amountErr) setState(() => _amountErr = err);
  }

  void _onAddrChanged() {
    if (_asset == null) return;
    final addr = _toCtrl.text.trim();
    final err = addr.isEmpty
        ? 'Enter recipient address'
        : getExecutor(_asset!.blockchain)?.validateAddress(addr);
    if (err != _addrErr) setState(() => _addrErr = err);
  }

  void _fetchFeeForAsset(Asset asset) {
    final blockchain = asset.blockchain;
    final spd = _selectedSpeed;
    debugPrint('[FEE] Fetching fee for $blockchain (speed: ${spd.name})');

    switch (blockchain) {
      case 'bitcoin':
        ref.read(bitcoinFeeProvider(spd).notifier).fetchFee(forceRefresh: true);
      case 'ethereum':
        ref.read(ethereumFeeProvider(EthereumFeeParams(blockchain: 'ethereum', speed: FeeSpeed.normal, isToken: asset.type == AssetType.token)).notifier).fetchFee(forceRefresh: true);
      case 'bsc':
        ref.read(bscFeeProvider(FeeSpeed.normal).notifier).fetchFee(forceRefresh: true, isToken: asset.type == AssetType.token);
      case 'ethereum_classic':
        ref.read(ethereumClassicFeeProvider(FeeSpeed.normal).notifier).fetchFee(forceRefresh: true);
      case 'solana':
        ref.read(solanaFeeProvider(null).notifier).fetchFee(forceRefresh: true);
      case 'tron':
        ref.read(tronFeeProvider.notifier).fetchFee(forceRefresh: true, isToken: asset.type == AssetType.token);
      case 'litecoin':
        ref.read(litecoinFeeProvider(spd).notifier).fetchFee(forceRefresh: true);
      case 'bitcoin_cash':
        ref.read(bitcoinCashFeeProvider(spd).notifier).fetchFee(forceRefresh: true);
      default:
        debugPrint('[FEE] No fee provider for $blockchain');
    }
  }

  void _applyMax() {
    final assetRaw = _asset;
    if (assetRaw == null) return;
    // Use live balance from provider (reflects optimistic updates after sends)
    final asset = ref.read(currentWalletProvider).value?.assets
        .firstWhere((a) => a.id == assetRaw.id, orElse: () => assetRaw)
        ?? assetRaw;
    final bal = asset.balanceAsDouble;
    if (asset.type == AssetType.native) {
      final fee = _readCurrentFee();
      if (fee != null && fee.feeInNative > 0) {
        final reserve = fee.feeInNative +
            (asset.blockchain == 'solana' ? _solRentExemption : 0.0);
        final max = (bal - reserve).clamp(0.0, double.infinity);
        _amountCtrl.text = _fmt(max, asset.decimals);
        if (_amountErr != null) setState(() => _amountErr = null);
        return;
      }
    }
    _amountCtrl.text = _fmt(bal, asset.decimals);
    if (_amountErr != null) setState(() => _amountErr = null);
  }

  double _maxSendable(Asset asset) {
    if (asset.type == AssetType.native) {
      final fee = _readCurrentFee();
      if (fee != null && fee.feeInNative > 0) {
        final reserve = fee.feeInNative +
            (asset.blockchain == 'solana' ? _solRentExemption : 0.0);
        return (asset.balanceAsDouble - reserve).clamp(0.0, double.infinity);
      }
    }
    return asset.balanceAsDouble;
  }

  static String _fmt(double v, int decimals) {
    if (v <= 0) return '0';
    final cap = decimals.clamp(0, 8);
    final s   = v.toStringAsFixed(cap);
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  Future<void> _scanQr() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const QrScannerScreen()),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() { _toCtrl.text = result; _onAddrChanged(); });
    }
  }

  Future<void> _openAddressBook() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => AddressBookScreen(filterBlockchain: _asset?.blockchain),
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() { _toCtrl.text = result; _onAddrChanged(); });
    }
  }

  FeeEstimate? _readCurrentFee() {
    final asset = _asset;
    if (asset == null) return null;
    final spd = _selectedSpeed;
    const normal = FeeSpeed.normal;
    return switch (asset.blockchain) {
      'bitcoin'           => ref.read(bitcoinFeeProvider(spd)).valueOrNull,
      'ethereum'          => ref.read(ethereumFeeProvider(EthereumFeeParams(blockchain: 'ethereum', speed: normal, isToken: asset.type == AssetType.token))).valueOrNull,
      'bsc'               => ref.read(bscFeeProvider(normal)).valueOrNull,
      'ethereum_classic'  => ref.read(ethereumClassicFeeProvider(normal)).valueOrNull,
      'solana'            => ref.read(solanaFeeProvider(null)).valueOrNull,
      'tron'              => ref.read(tronFeeProvider).valueOrNull,
      'litecoin'          => ref.read(litecoinFeeProvider(spd)).valueOrNull,
      'bitcoin_cash'      => ref.read(bitcoinCashFeeProvider(spd)).valueOrNull,
      _                   => null,
    };
  }

  void _review() {
    final asset = _asset;
    if (asset == null) return;
    final to  = _toCtrl.text.trim();
    final err = to.isEmpty
        ? 'Enter recipient address'
        : getExecutor(asset.blockchain)?.validateAddress(to);
    if (err != null) { setState(() => _addrErr = err); return; }
    final amtStr = _amountCtrl.text.trim();
    final amt    = double.tryParse(amtStr);
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    final liveAssetForCheck = ref.read(currentWalletProvider).value?.assets
        .firstWhere((a) => a.id == asset.id, orElse: () => asset) ?? asset;
    if (amt > liveAssetForCheck.balanceAsDouble) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Amount exceeds available balance')));
      return;
    }
    // For token sends: check native coin balance covers gas fee
    if (asset.type == AssetType.token) {
      final fee = _readCurrentFee();
      if (fee != null && fee.feeInNative > 0) {
        final wallet = ref.read(currentWalletProvider).value;
        final native = wallet?.assets.firstWhere(
          (a) => a.blockchain == asset.blockchain && a.type == AssetType.native,
          orElse: () => asset,
        );
        final nativeBal = (native?.type == AssetType.native)
            ? (double.tryParse(native!.balance) ?? 0.0)
            : 0.0;
        if (nativeBal < fee.feeInNative) {
          final sym = _gasSymbol(asset.blockchain);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Insufficient $sym for gas fee (need ${fee.feeInNative.toStringAsFixed(8)} $sym)'),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 4),
          ));
          return;
        }
      }
    }
    if (_amountErr != null) return; // insufficient at current fee — error shown inline
    final feeEstimate = _readCurrentFee();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ReviewSheet(
        asset: asset, to: to, amount: amtStr,
        feeEstimate: feeEstimate,
        onConfirm: (pin) async {
          final (hash, err) = await _execute(pin, asset, to, amtStr, feeEstimate);
          return (hash, err);
        },
        onSuccess: (txHash) => Navigator.of(context).pushReplacement(
          PushPageRoute(page: TxSuccessScreen(
            asset: asset,
            toAddress: to,
            amount: amtStr,
            txHash: txHash,
            feeEstimate: feeEstimate,
          )),
        ),
      ),
    );
  }

  // Returns (txHash, errorMessage):
  //   (hash,  null ) → success
  //   (null,  null ) → wrong PIN
  //   (null, 'msg' ) → executor/network error
  Future<(String?, String?)> _execute(
    String pin, Asset asset, String to, String amountStr, [
    FeeEstimate? feeOverride,
  ]) async {
    final walletState = ref.read(currentWalletProvider);
    final walletId = walletState.value?.id ?? '';
    debugPrint('[SEND][_execute] blockchain=${asset.blockchain} assetId=${asset.id}');
    debugPrint('[SEND][_execute] walletState=${walletState.runtimeType} walletId="$walletId" pinLen=${pin.length}');

    final mnemonic = await KeyManager.getSeedPhrase(pin, walletId: walletId);
    debugPrint('[SEND][_execute] getSeedPhrase → ${mnemonic != null ? 'OK (${mnemonic.split(' ').length} words)' : 'NULL (wrong PIN or walletId not found)'}');
    if (mnemonic == null) return (null, null); // wrong PIN

    final executor = getExecutorWithFee(asset.blockchain, feeOverride);
    if (executor == null) {
      debugPrint('[SEND][_execute] ERROR: no executor for ${asset.blockchain}');
      return (null, 'Blockchain ${asset.blockchain} is not supported');
    }

    debugPrint('[SEND][_execute] calling executor.execute to=$to amount=$amountStr');
    try {
      final txHash = await executor.execute(
        mnemonic: mnemonic,
        asset: asset,
        toAddress: to,
        amount: amountStr,
      );
      debugPrint('[SEND][_execute] SUCCESS txHash=$txHash');
      // Optimistic TX in cache with confirmed:false → shows "Processing" until blockchain confirms
      try {
        final newRecord = TxRecord(
          hash:       txHash,
          from:       '',
          to:         to,
          amount:     double.tryParse(amountStr) ?? 0,
          symbol:     asset.symbol,
          timestamp:  DateTime.now(),
          direction:  TxDirection.outgoing,
          confirmed:  false,
          blockchain: asset.blockchain,
          feePaid:    feeOverride?.feeInNative,
        );
        final existing = getCachedHistory(asset) ?? [];
        if (!existing.any((r) => r.hash == txHash)) {
          setCachedHistory(asset, [newRecord, ...existing]);
        }
        await PendingTxStore.save(asset.id, newRecord);
      } catch (_) {}
      // Optimistic balance: subtract sent amount + fee locally, schedule real refresh in 4 min
      try {
        final sentAmt = double.tryParse(amountStr) ?? 0.0;
        final isNative = asset.type == AssetType.native;
        final fee = isNative ? (feeOverride?.feeInNative ?? 0.0) : 0.0;
        final currentBal = double.tryParse(asset.balance) ?? 0.0;
        final newBal = (currentBal - sentAmt - fee).clamp(0.0, double.maxFinite);
        final decimals = asset.decimals.clamp(0, 10);
        await ref.read(currentWalletProvider.notifier)
            .applyOptimisticBalance(asset.id, newBal.toStringAsFixed(decimals));
      } catch (_) {}
      return (txHash, null);
    } catch (e, st) {
      debugPrint('[SEND][_execute] EXECUTOR ERROR: $e');
      debugPrint('[SEND][_execute] STACK: $st');
      return (null, _cleanError('$e'));
    }
  }

  static String _gasSymbol(String blockchain) => switch (blockchain) {
    'bsc'               => 'BNB',
    'ethereum_classic'  => 'ETC',
    _                   => 'ETH',
  };

  static String _cleanError(String raw) {
    // Strip 'Exception: ' prefix that Dart adds
    final s = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
    if (s.isEmpty) return 'Transaction failed';
    // Translate cryptic gas/funds RPC errors to user-friendly messages
    final lower = s.toLowerCase();
    if (lower.contains('gas required exceeds allowance') ||
        lower.contains('insufficient funds for gas') ||
        lower.contains('gas * price + value')) {
      return 'Insufficient funds for gas fee. Please top up your wallet.';
    }
    // Capitalise first letter
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final multiAsset = widget.assets.length > 1;

    // ── Step 1: asset picker (only when opened from home with multiple assets) ──
    if (_asset == null && multiAsset) {
      return _buildPickerScaffold(context);
    }

    // ── Step 2: send form ──────────────────────────────────────────────────────
    final asset     = _asset!;
    // Live balance from provider reflects optimistic updates after sends
    final _liveBalance = ref.watch(currentWalletProvider).value?.assets
        .firstWhere((a) => a.id == asset.id, orElse: () => asset)
        .balance ?? asset.balance;
    final liveAsset = _liveBalance != asset.balance
        ? asset.copyWith(balance: _liveBalance)
        : asset;
    final supported = _sendSupported(asset);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Send'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (multiAsset) {
              // Go back to picker step
              setState(() { _asset = null; _addrErr = null; });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Selected asset badge (always locked in form step)
            AssetBadge(asset: liveAsset),
            const SizedBox(height: 16),

            if (!supported) ...[
              UnsupportedBanner(asset.symbol),
              const Spacer(),
            ] else ...[
              Row(children: [
                const Expanded(child: SizedBox.shrink()),
                AnimatedTap(
                  onTap: _openAddressBook,
                  child: Text('Address Book',
                      style: TextStyle(color: AppColors.accent, fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 6),
              TextField(
                controller: _toCtrl,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: _fieldDeco(
                  '${asset.symbol} Address',
                  error: _addrErr,
                ).copyWith(
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.qr_code_scanner_rounded,
                            color: AppColors.textSecondary, size: 20),
                        onPressed: _scanQr,
                        tooltip: 'Scan QR',
                      ),
                      IconButton(
                        icon: Icon(Icons.book_outlined,
                            color: AppColors.textSecondary, size: 20),
                        onPressed: _openAddressBook,
                        tooltip: 'Address Book',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SectionLabel('Amount'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    style: TextStyle(color: AppColors.textPrimary),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _fieldDeco('0.00').copyWith(
                      suffixText: asset.symbol,
                      suffixStyle: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedTap(
                  onTap: _applyMax,
                  pressScale: 0.9,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Text('MAX',
                        style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Builder(builder: (_) {
                final maxSend = _maxSendable(liveAsset);
                final hasFeeDeduction = liveAsset.type == AssetType.native &&
                    maxSend < liveAsset.balanceAsDouble;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasFeeDeduction
                          ? 'Available: ${_fmt(maxSend, liveAsset.decimals)} ${liveAsset.symbol} (after fee)'
                          : 'Balance: ${liveAsset.formattedBalance}',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    if (_amountErr != null) ...[  
                      const SizedBox(height: 4),
                      Text(_amountErr!,
                          style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ],
                  ],
                );
              }),
              const SizedBox(height: 24),
              // Fee display + speed selector
              FeeWidget(blockchain: asset.blockchain, selectedSpeed: _selectedSpeed, isToken: asset.type == AssetType.token),
              if (_supportsSpeedSelector(asset.blockchain)) ...[
                const SizedBox(height: 10),
                FeeSpeedSelector(
                  selected: _selectedSpeed,
                  onSelect: _selectSpeed,
                ),
              ],
              const Spacer(),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : () { _review(); },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: AppColors.background,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: AppColors.background, strokeWidth: 2),
                    )
                    : Text('Review Transaction',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildPickerScaffold(BuildContext context) {
    final _searchCtrl = _pickerSearchCtrl;
    final filtered    = _pickerFiltered;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Send'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _pickerQuery = v),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search asset…',
              hintStyle: TextStyle(color: AppColors.textTertiary),
              prefixIcon: Icon(Icons.search_rounded,
                  color: AppColors.textTertiary, size: 20),
              suffixIcon: _pickerQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: AppColors.textTertiary, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _pickerQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: AppColors.textSecondary, width: 1.2)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _pickerQuery.isEmpty
                  ? 'My assets'
                  : 'Results (${filtered.length})',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('No assets found',
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 15)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final a = filtered[i];
                    return AnimatedTap(
                      onTap: () {
                        setState(() {
                          _asset = a;
                          _addrErr = null;
                        });
                        // Fetch fee when asset is selected
                        _fetchFeeForAsset(a);
                      },
                      pressScale: 0.97,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        child: Row(children: [
                          CoinIcon(
                              symbol: a.symbol,
                              iconUrl: a.iconUrl,
                              size: 46),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(a.symbol,
                                      style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 5),
                                  Row(children: [
                                    NetChip(a.blockchain),
                                  ]),
                                ]),
                          ),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(a.formattedBalance,
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 3),
                                Text(a.formattedUsdValue,
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12)),
                              ]),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded,
                              color: AppColors.textTertiary, size: 14),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  InputDecoration _fieldDeco(String hint, {String? error}) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: AppColors.textTertiary),
    errorText: error,
    errorStyle: TextStyle(color: AppColors.negative, fontSize: 11),
    filled: true,
    fillColor: AppColors.surface,
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: error != null ? AppColors.negative : AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.textSecondary, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.negative)),
  );
}

// ─── Review bottom sheet ──────────────────────────────────────────────────────

// ─── Fee speed selector ───────────────────────────────────────────────────────

// ─── PIN numpad (for send/review) ─────────────────────────────────────────────

// ─── Shared helpers + widgets ─────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────

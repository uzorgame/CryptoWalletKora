import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/config/api_config.dart';
import 'package:kora/core/services/biometric_service.dart';
import 'package:kora/core/services/storage_service.dart';
import 'package:kora/core/crypto/key_manager.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/widgets/coin_icon.dart';
import 'package:kora/features/address_book/address_book_screen.dart';
import 'package:kora/features/scan/qr_scanner_screen.dart';
// ─── Executor imports ─────────────────────────────────────────────────────────
import 'package:kora/features/send/executors/evm_executor.dart';
import 'package:kora/features/send/executors/tron_executor.dart';
import 'package:kora/features/send/executors/solana_executor.dart';
import 'package:kora/features/send/executors/utxo_executor.dart';
import 'package:kora/features/send/services/transaction_executor.dart';
import 'package:kora/core/widgets/animated_tap.dart';
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
        _netLabel(a.blockchain).toLowerCase().contains(q)).toList();
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
        : _getExecutor(_asset!.blockchain)?.validateAddress(addr);
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

  TransactionExecutor? _getExecutor(String blockchain) {
    return switch (blockchain) {
      // EVM chains
      'ethereum' || 'bsc' ||
      'ethereum_classic' => EvmExecutor(),
      
      // TRON
      'tron' => TronExecutor(),
      
      // Bitcoin-like
      'bitcoin' || 'litecoin' || 'bitcoin_cash' => UtxoExecutor(blockchain, null),
      
      // Solana
      'solana' => SolanaExecutor(),
      
      _ => null,
    };
  }

  TransactionExecutor? _getExecutorWithFee(String blockchain, FeeEstimate? fee) {
    final satPerVByte = (fee?.details?['satPerVByte'] as num?)?.toInt();
    return switch (blockchain) {
      'bitcoin' || 'litecoin' || 'bitcoin_cash' => UtxoExecutor(blockchain, satPerVByte),
      _ => _getExecutor(blockchain),
    };
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
        : _getExecutor(asset.blockchain)?.validateAddress(to);
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
      builder: (_) => _ReviewSheet(
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

    final executor = _getExecutorWithFee(asset.blockchain, feeOverride);
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
            _AssetBadge(asset: liveAsset),
            const SizedBox(height: 16),

            if (!supported) ...[
              _UnsupportedBanner(asset.symbol),
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
              _SectionLabel('Amount'),
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
              _FeeWidget(blockchain: asset.blockchain, selectedSpeed: _selectedSpeed, isToken: asset.type == AssetType.token),
              if (_supportsSpeedSelector(asset.blockchain)) ...[
                const SizedBox(height: 10),
                _FeeSpeedSelector(
                  selected: _selectedSpeed,
                  onSelect: _selectSpeed,
                ),
              ],
              const Spacer(),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : () { debugPrint('[TAP] Review Transaction: ${_asset?.symbol} → ${_toCtrl.text.trim()} amount=${_amountCtrl.text.trim()} (send_screen.dart)'); _review(); },
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
                                    _NetChip(a.blockchain),
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

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({
    required this.asset,
    required this.to,
    required this.amount,
    required this.onConfirm,
    required this.onSuccess,
    this.feeEstimate,
  });
  final Asset asset;
  final String to;
  final String amount;
  final FeeEstimate? feeEstimate;
  final Future<(String?, String?)> Function(String pin) onConfirm;
  final void Function(String txHash) onSuccess;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  String  _pin             = '';
  bool    _loading         = false;
  String? _error;
  bool    _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final enabled = await StorageService.readBool(StorageService.KEY_BIOMETRIC_ENABLED) ?? false;
    if (!mounted) return;
    setState(() => _biometricEnabled = enabled);
    if (enabled) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    final result = await BiometricService.authenticate(
      reason: 'Confirm transaction in Kora Wallet',
      biometricOnly: false,
    );
    if (!mounted) return;
    if (result.isSuccess) {
      final pin = await KeyManager.getPinForBiometric();
      if (!mounted) return;
      if (pin != null) {
        await _executeWithPin(pin);
      } else {
        setState(() {
          _loading = false;
          _error = 'Biometric PIN not set up. Please enter PIN manually.';
        });
      }
    } else if (result == BiometricResult.cancelled) {
      setState(() { _loading = false; });
    } else {
      setState(() { _loading = false; _error = result.message; });
    }
  }

  void _onDigit(String d) {
    if (_pin.length >= 6 || _loading) return;
    HapticFeedback.lightImpact();
    setState(() { _pin += d; _error = null; });
    if (_pin.length == 6) _executeWithPin(_pin);
  }

  void _onBackspace() {
    if (_pin.isEmpty || _loading) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _executeWithPin(String pin) async {
    setState(() { _loading = true; _error = null; });
    debugPrint('[TAP] Confirm & Send: ${widget.asset.symbol} to=${widget.to} amount=${widget.amount} (send_screen.dart)');
    final (txHash, errMsg) = await widget.onConfirm(pin);
    if (mounted) {
      if (txHash != null) {
        Navigator.of(context).pop();
        widget.onSuccess(txHash);
      } else {
        setState(() {
          _loading = false;
          _pin = '';
          _error = errMsg ?? 'Incorrect PIN. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.asset;
    final short = widget.to.length > 20
        ? '${widget.to.substring(0, 10)}…${widget.to.substring(widget.to.length - 8)}'
        : widget.to;

    // Format fee for display
    String feeText = '';
    if (widget.feeEstimate != null) {
      final fee = widget.feeEstimate!;
      final sym = _feeSymbol(a.blockchain);
      String native;
      if (fee.feeInNative >= 1) {
        native = fee.feeInNative.toStringAsFixed(2);
      } else if (fee.feeInNative >= 0.001) {
        native = fee.feeInNative.toStringAsFixed(4);
      } else {
        native = fee.feeInNative.toStringAsFixed(8)
            .replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      }
      feeText = '$native $sym';
      if (fee.feeInUsd > 0) {
        final String usd;
        if (fee.feeInUsd >= 0.01) {
          usd = '\$${fee.feeInUsd.toStringAsFixed(2)}';
        } else if (fee.feeInUsd >= 0.0001) {
          usd = '\$${fee.feeInUsd.toStringAsFixed(4)}';
        } else {
          usd = '\$${fee.feeInUsd.toStringAsFixed(6)}'
              .replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
        }
        feeText += '  ($usd)';
      }
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        Center(child: Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: AppColors.border, borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 20),
        Text('Review Transaction',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),

        // ── Static transaction summary ────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(children: [
            _ReviewRow('Asset',  '${a.symbol}  ·  ${_netLabel(a.blockchain)}'),
            _ReviewRow('To',     short),
            _ReviewRow('Amount', '${widget.amount} ${a.symbol}',
                last: feeText.isEmpty),
            if (feeText.isNotEmpty)
              _ReviewRow('Network Fee', feeText, last: true),
          ]),
        ),
        const SizedBox(height: 12),

        // Warning
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.25), width: 0.5),
          ),
          child: Row(children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Transactions are irreversible. Verify the address before confirming.',
              style: TextStyle(color: AppColors.warning, fontSize: 11, height: 1.4),
            )),
          ]),
        ),
        const SizedBox(height: 24),

        // ── Auth section ──────────────────────────────────────────────────
        Text(
          _biometricEnabled ? 'Confirm with biometrics or PIN' : 'Enter PIN to confirm',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 20),

        // PIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) {
            final filled = i < _pin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 14, height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? AppColors.textPrimary : Colors.transparent,
                border: Border.all(
                  color: filled ? AppColors.textPrimary : AppColors.textTertiary,
                  width: 1.5,
                ),
              ),
            );
          }),
        ),

        // Error or spacer
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: TextStyle(color: AppColors.negative, fontSize: 12),
              textAlign: TextAlign.center),
        ] else
          const SizedBox(height: 28),

        const SizedBox(height: 8),

        // PIN numpad
        _SendNumpad(
          onDigit: _onDigit,
          onBackspace: _onBackspace,
          onBiometric: _biometricEnabled ? _tryBiometric : null,
          loading: _loading,
        ),
      ]),
    );
  }
}

String _feeSymbol(String blockchain) => const {
  'bitcoin': 'BTC', 'ethereum': 'ETH', 'bsc': 'BNB',
  'ethereum_classic': 'ETC', 'solana': 'SOL', 'tron': 'TRX',
  'litecoin': 'LTC', 'bitcoin_cash': 'BCH',
}[blockchain] ?? '';

// ─── Fee speed selector ───────────────────────────────────────────────────────

class _FeeSpeedSelector extends StatelessWidget {
  const _FeeSpeedSelector({required this.selected, required this.onSelect});
  final FeeSpeed selected;
  final void Function(FeeSpeed) onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(children: FeeSpeed.values.map((spd) {
      final isSelected = spd == selected;
      final label = switch (spd) {
        FeeSpeed.slow   => 'Slow',
        FeeSpeed.normal => 'Normal',
        FeeSpeed.fast   => 'Fast',
      };
      return Expanded(
        child: GestureDetector(
          onTap: () => onSelect(spd),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: EdgeInsets.only(
              left: spd == FeeSpeed.slow ? 0 : 4,
              right: spd == FeeSpeed.fast ? 0 : 4,
            ),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.textPrimary : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.textPrimary : AppColors.border,
                width: 0.5,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? AppColors.background : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      );
    }).toList());
  }
}

// ─── PIN numpad (for send/review) ─────────────────────────────────────────────

class _SendNumpad extends StatelessWidget {
  const _SendNumpad({
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
    this.loading = false,
  });
  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _buildRow(['1', '2', '3']),
      const SizedBox(height: 12),
      _buildRow(['4', '5', '6']),
      const SizedBox(height: 12),
      _buildRow(['7', '8', '9']),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        SizedBox(
          width: 72, height: 72,
          child: onBiometric != null
              ? _SendNumBtn(
                  onTap: loading ? null : onBiometric,
                  child: Icon(Icons.fingerprint_rounded,
                      color: AppColors.textSecondary, size: 28),
                )
              : const SizedBox.shrink(),
        ),
        _SendNumBtn(label: '0', onTap: loading ? null : () => onDigit('0')),
        SizedBox(
          width: 72, height: 72,
          child: _SendNumBtn(
            onTap: loading ? null : onBackspace,
            child: loading
                ? SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: AppColors.textPrimary, strokeWidth: 2))
                : Icon(Icons.backspace_outlined,
                    color: AppColors.textSecondary, size: 22),
          ),
        ),
      ]),
    ]);
  }

  Widget _buildRow(List<String> digits) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: digits
        .map((d) => _SendNumBtn(label: d, onTap: loading ? null : () => onDigit(d)))
        .toList(),
  );
}

class _SendNumBtn extends StatelessWidget {
  const _SendNumBtn({this.label, this.child, this.onTap});
  final String? label;
  final Widget? child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AnimatedTap(
    onTap: onTap,
    pressScale: 0.88,
    pressOpacity: 0.65,
    child: Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
      ),
      child: Center(
        child: label != null
            ? Text(label!,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w400))
            : child,
      ),
    ),
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value, {this.last = false});
  final String label, value;
  final bool last;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: BoxDecoration(border: last ? null
        : Border(bottom: BorderSide(color: AppColors.separator, width: 0.5))),
    child: Row(children: [
      Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const Spacer(),
      Flexible(child: Text(value, textAlign: TextAlign.right,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );
}

// ─── Shared helpers + widgets ─────────────────────────────────────────────────

String _netLabel(String b) => const {
  'ethereum': 'Ethereum',    'bsc': 'BNB Smart Chain',
  'tron': 'Tron',
  'solana': 'Solana',        'bitcoin': 'Bitcoin',     'dogecoin': 'Dogecoin',
  'litecoin': 'Litecoin',
}[b] ?? b;

class _AssetBadge extends StatelessWidget {
  const _AssetBadge({required this.asset});
  final Asset asset;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5)),
    child: Row(children: [
      CoinIcon(symbol: asset.symbol, iconUrl: asset.iconUrl, size: 36),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(asset.symbol,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        _NetChip(asset.blockchain),
      ])),
      Text(asset.formattedBalance,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    ]),
  );
}

class _NetChip extends StatelessWidget {
  const _NetChip(this.blockchain);
  final String blockchain;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(5)),
    child: Text(_netLabel(blockchain),
        style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w600)),
  );
}

class _FeeWidget extends ConsumerWidget {
  const _FeeWidget({required this.blockchain, this.selectedSpeed = FeeSpeed.normal, this.isToken = false});
  final String blockchain;
  final FeeSpeed selectedSpeed;
  final bool isToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<FeeEstimate?>? feeState;
    final spd = selectedSpeed;

    switch (blockchain) {
      case 'bitcoin':
        feeState = ref.watch(bitcoinFeeProvider(spd));
      case 'ethereum':
        feeState = ref.watch(ethereumFeeProvider(EthereumFeeParams(blockchain: 'ethereum', speed: FeeSpeed.normal, isToken: isToken)));
      case 'bsc':
        feeState = ref.watch(bscFeeProvider(FeeSpeed.normal));
      case 'ethereum_classic':
        feeState = ref.watch(ethereumClassicFeeProvider(FeeSpeed.normal));
      case 'solana':
        feeState = ref.watch(solanaFeeProvider(null));
      case 'tron':
        feeState = ref.watch(tronFeeProvider);
      case 'litecoin':
        feeState = ref.watch(litecoinFeeProvider(spd));
      case 'bitcoin_cash':
        feeState = ref.watch(bitcoinCashFeeProvider(spd));
      default:
        return const SizedBox.shrink();
    }

    return feeState?.when(
      data: (fee) {
        if (fee == null) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withOpacity(0.5), width: 0.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Text('Network Fee: Unable to fetch',
                    style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 4),
              Text('All fee APIs unavailable. Check connection.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontStyle: FontStyle.italic)),
            ]),
          );
        }
        
        final symbol = _getBlockchainSymbol(blockchain);
        
        // Format native fee - smart precision based on magnitude
        String feeNative;
        if (fee.feeInNative >= 1) {
          feeNative = fee.feeInNative.toStringAsFixed(2);
        } else if (fee.feeInNative >= 0.001) {
          feeNative = fee.feeInNative.toStringAsFixed(4);
        } else {
          feeNative = fee.feeInNative.toStringAsFixed(8)
              .replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
        }

        // Format USD - enough decimals to always show a non-zero value
        String feeUsd = '';
        if (fee.feeInUsd > 0) {
          if (fee.feeInUsd >= 1) {
            feeUsd = '\$${fee.feeInUsd.toStringAsFixed(2)}';
          } else if (fee.feeInUsd >= 0.01) {
            feeUsd = '\$${fee.feeInUsd.toStringAsFixed(3)}';
          } else if (fee.feeInUsd >= 0.0001) {
            feeUsd = '\$${fee.feeInUsd.toStringAsFixed(4)}';
          } else {
            feeUsd = '\$${fee.feeInUsd.toStringAsFixed(6)}'
                .replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
          }
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(children: [
            Icon(Icons.local_gas_station_outlined, color: AppColors.textSecondary, size: 16),
            const SizedBox(width: 8),
            Text('Network Fee:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$feeNative $symbol',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
              if (feeUsd.isNotEmpty)
                Text(feeUsd,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ]),
          ]),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(children: [
          SizedBox(width: 12, height: 12, 
            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.textSecondary)),
          const SizedBox(width: 10),
          Text('Loading fee...', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ]),
      ),
      error: (error, __) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withOpacity(0.5), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Network Fee: Unable to fetch',
                  style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text(
              'API Error: ${error.toString().replaceAll('Exception: ', '').replaceAll('FeeApiException [${blockchain}]: ', '')}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Please check connection or try again later',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    ) ?? const SizedBox.shrink();
  }

  String _getBlockchainSymbol(String blockchain) {
    return switch (blockchain) {
      'bitcoin' => 'BTC',
      'ethereum' => 'ETH',
      'bsc' => 'BNB',
      'ethereum_classic' => 'ETC',
      'solana' => 'SOL',
      'tron' => 'TRX',
      'litecoin' => 'LTC',
      'bitcoin_cash' => 'BCH',
      _ => '',
    };
  }
}

class _UnsupportedBanner extends StatelessWidget {
  const _UnsupportedBanner(this.symbol);
  final String symbol;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3), width: 0.5)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.construction_rounded, color: AppColors.warning, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(
        'Sending $symbol is not yet supported in this release. '
        'Support for more chains will be added in a future update.',
        style: TextStyle(color: AppColors.warning, fontSize: 12, height: 1.4),
      )),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(color: AppColors.textSecondary,
          fontSize: 13, fontWeight: FontWeight.w500));
}


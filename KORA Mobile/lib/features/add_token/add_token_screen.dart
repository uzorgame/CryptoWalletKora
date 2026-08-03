import 'package:flutter/material.dart';
import 'package:kora/core/widgets/animated_tap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/constants/token_catalog.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/widgets/coin_icon.dart';

// ─── Chains with full address derivation ─────────────────────────────────────
const _supportedChains = {
  'bitcoin', 'ethereum', 'bsc',
  'solana', 'tron', 'litecoin',
  'ethereum_classic',
  'bitcoin_cash',
};

// ─── Network options shown in the filter bar ──────────────────────────────────

class _NetworkOption {
  const _NetworkOption({
    required this.id,
    required this.label,
    required this.iconSymbol,
  });
  final String? id;       // null = All
  final String label;
  final String iconSymbol;
}

const _networks = <_NetworkOption>[
  _NetworkOption(id: null,        label: 'All',       iconSymbol: ''),
  _NetworkOption(id: 'ethereum',  label: 'Ethereum',  iconSymbol: 'ETH'),
  _NetworkOption(id: 'bsc',       label: 'BSC',       iconSymbol: 'BNB'),
  _NetworkOption(id: 'tron',      label: 'Tron',      iconSymbol: 'TRX'),
  _NetworkOption(id: 'solana',    label: 'Solana',    iconSymbol: 'SOL'),
  _NetworkOption(id: 'bitcoin',   label: 'Bitcoin',   iconSymbol: 'BTC'),
  _NetworkOption(id: 'litecoin',  label: 'Litecoin',  iconSymbol: 'LTC'),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class AddTokenScreen extends ConsumerStatefulWidget {
  const AddTokenScreen({super.key});

  @override
  ConsumerState<AddTokenScreen> createState() => _AddTokenScreenState();
}

class _AddTokenScreenState extends ConsumerState<AddTokenScreen> with ThemeAwareMixin {
  final _searchCtrl = TextEditingController();
  final _networkScrollCtrl = ScrollController();
  String _query = '';
  String? _selectedNetwork; // null = All
  // Memoized filter result — recomputed only when query or network changes
  late List<CatalogToken> _cachedFiltered;
  String? _lastNetwork = '__unset__';
  String  _lastQuery   = '__unset__';

  @override
  void initState() {
    super.initState();
    _cachedFiltered = allCatalogTokens;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _networkScrollCtrl.dispose();
    super.dispose();
  }

  List<CatalogToken> _filtered() {
    if (_query == _lastQuery && _selectedNetwork == _lastNetwork) return _cachedFiltered;
    _lastQuery   = _query;
    _lastNetwork = _selectedNetwork;
    var list = _selectedNetwork == null
        ? allCatalogTokens
        : allCatalogTokens.where((t) => t.blockchain == _selectedNetwork).toList();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((t) =>
          t.symbol.toLowerCase().contains(q) ||
          t.name.toLowerCase().contains(q)).toList();
    }
    _cachedFiltered = list;
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(currentWalletProvider);
    final existingIds =
        walletAsync.valueOrNull?.assets
            .where((a) => a.isVisible)
            .map((a) => a.id).toSet() ?? {};
    final filtered = _filtered();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Add Token'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Network filter ─────────────────────────────────────────────────
          SizedBox(
            height: 46,
            child: ListView.builder(
              controller: _networkScrollCtrl,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _networks.length,
              itemBuilder: (_, i) {
                final net = _networks[i];
                final selected = _selectedNetwork == net.id;
                return _NetworkChip(
                  option: net,
                  selected: selected,
                  onTap: () => setState(() {
                    _selectedNetwork = net.id;
                    _query = '';
                    _searchCtrl.clear();
                  }),
                );
              },
            ),
          ),

          const SizedBox(height: 4),

          // ── Search bar ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: _selectedNetwork == null
                    ? 'Search token / name…'
                    : 'Search in ${_networkLabel(_selectedNetwork!)}…',
                hintStyle:
                    TextStyle(color: AppColors.textTertiary),
                prefixIcon: Icon(Icons.search_rounded,
                    color: AppColors.textTertiary, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: AppColors.textTertiary, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.card,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ── Count hint ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            child: Text(
              '${filtered.length} token${filtered.length == 1 ? '' : 's'}',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ),

          const SizedBox(height: 4),

          // ── Token list (selected first, then rest) ──────────────────────
          Expanded(
            child: Builder(builder: (_) {
              if (filtered.isEmpty) {
                return Center(
                  child: Text('No tokens found',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 15)),
                );
              }

              // Split into selected and unselected groups
              final selected = filtered
                  .where((t) => existingIds.contains(t.id))
                  .toList();
              final others = filtered
                  .where((t) => !existingIds.contains(t.id))
                  .toList();

              // Build a flat list: String items are section headers,
              // CatalogToken items are token rows.
              final items = <Object>[];
              if (selected.isNotEmpty) {
                items.add('Active'); // section header
                items.addAll(selected);
              }
              if (others.isNotEmpty) {
                if (selected.isNotEmpty) {
                  items.add('Available'); // second section header
                }
                items.addAll(others);
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 32),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  if (item is String) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                      child: Text(
                        item,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    );
                  }
                  final token  = item as CatalogToken;
                  final isAdded = existingIds.contains(token.id);
                  return _TokenRow(
                    token: token,
                    isAdded: isAdded,
                    onToggle: () => _toggle(token, isAdded),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(CatalogToken token, bool isAdded) async {
    final notifier = ref.read(currentWalletProvider.notifier);
    if (isAdded) {
      await notifier.removeToken(token.id);
      return;
    }
    // Warn user if this chain has no native address derivation
    if (!_supportedChains.contains(token.blockchain)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text('Price tracking only',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
          content: Text(
            '${token.name} (${token.blockchain}) is not yet fully supported.\n\n'
            'Adding it will track the price, but the receive address will be a '
            'placeholder (ETH format) and cannot actually receive ${token.symbol}.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Add anyway', style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await notifier.addToken(token);
  }
}

// ─── Network chip ─────────────────────────────────────────────────────────────

class _NetworkChip extends StatelessWidget {
  const _NetworkChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _NetworkOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedTap(
      onTap: onTap,
      pressScale: 0.9,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        decoration: BoxDecoration(
          color: selected ? AppColors.cardElevated : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.textPrimary.withValues(alpha: 0.3) : AppColors.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (option.iconSymbol.isNotEmpty) ...[
              CoinIcon(symbol: option.iconSymbol, size: 18),
              const SizedBox(width: 6),
            ],
            Text(
              option.label,
              style: TextStyle(
                color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Token row ────────────────────────────────────────────────────────────────

class _TokenRow extends StatelessWidget {
  const _TokenRow({
    required this.token,
    required this.isAdded,
    required this.onToggle,
  });

  final CatalogToken token;
  final bool isAdded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return AnimatedTap(
      onTap: onToggle,
      pressScale: 0.97,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          CoinIcon(symbol: token.symbol, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(token.symbol,
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _networkLabel(token.blockchain),
                        style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ]),
                ]),
          ),
          // +/- toggle button
          AnimatedTap(
            onTap: onToggle,
            pressScale: 0.85,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isAdded
                    ? AppColors.negative.withValues(alpha: 0.12)
                    : Colors.transparent,
                border: Border.all(
                  color: isAdded
                      ? AppColors.negative
                      : AppColors.textTertiary,
                  width: 1.5,
                ),
              ),
              child: Icon(
                isAdded ? Icons.remove_rounded : Icons.add_rounded,
                color:
                    isAdded ? AppColors.negative : AppColors.textSecondary,
                size: 16,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _networkLabel(String blockchain) {
  const map = <String, String>{
    'bitcoin': 'Bitcoin',     'ethereum': 'Ethereum',  'solana': 'Solana',
    'bsc': 'BNB Smart Chain', 'tron': 'Tron',          'dogecoin': 'Dogecoin',
    'litecoin': 'Litecoin',
  };
  return map[blockchain] ?? blockchain;
}

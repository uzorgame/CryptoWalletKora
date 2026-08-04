import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kora/core/constants/token_catalog.dart';
import 'package:kora/core/state/providers/wallet_provider.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/kora_app_bar.dart';
import 'package:kora/core/widgets/kora_field.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:kora/features/add_token/widgets/network_filter.dart';
import 'package:kora/features/add_token/widgets/token_row.dart';

// ─── Chains with full address derivation ─────────────────────────────────────
const _supportedChains = {
  'bitcoin', 'ethereum', 'bsc',
  'solana', 'tron', 'litecoin',
  'ethereum_classic',
  'bitcoin_cash',
};

// ─── Network options shown in the filter bar ──────────────────────────────────

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
      appBar: koraAppBar(context, 'Add Token',
          onBack: () => Navigator.of(context).pop()),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search bar ─────────────────────────────────────────────────────
          // The prototype's order: search first, then the networks it can be narrowed to.
          const SizedBox(height: 14),
          KoraField(
            child: Row(children: [
              Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 16),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: koraInputStyle(),
                  onChanged: (v) => setState(() => _query = v),
                  decoration: koraInputDecoration(
                    (_selectedNetwork == null
                            ? 'Search name or paste contract'
                            : 'Search in ${networkLabel(_selectedNetwork!)}')
                        .toUpperCase(),
                  ),
                ),
              ),
              if (_query.isNotEmpty)
                AnimatedTap(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                  child: Icon(Icons.close_rounded,
                      color: AppColors.textTertiary, size: 16),
                ),
            ]),
          ),

          // ── Network filter ─────────────────────────────────────────────────
          SizedBox(
            height: 50,
            child: ListView.builder(
              controller: _networkScrollCtrl,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              itemCount: networks.length,
              itemBuilder: (_, i) {
                final net = networks[i];
                final selected = _selectedNetwork == net.id;
                return NetworkChip(
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

          const SizedBox(height: 12),

          // ── Token list (selected first, then rest) ──────────────────────
          Expanded(
            child: Builder(builder: (_) {
              if (filtered.isEmpty) {
                return Center(
                  child: Text('NO TOKENS FOUND',
                      style: kLabel(AppColors.textTertiary, size: 10, tracking: 0.14)),
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
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                      child: Text(
                        item.toUpperCase(),
                        style: kLabel(AppColors.textTertiary, size: 9.5, tracking: 0.16),
                      ),
                    );
                  }
                  final token  = item as CatalogToken;
                  final isAdded = existingIds.contains(token.id);
                  return TokenRow(
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
              style: kBody(AppColors.textPrimary, size: 16)),
          content: Text(
            '${token.name} (${token.blockchain}) is not yet fully supported.\n\n'
            'Adding it will track the price, but the receive address will be a '
            'placeholder (ETH format) and cannot actually receive ${token.symbol}.',
            style: kBody(AppColors.textSecondary, size: 13).copyWith(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: kBody(AppColors.textSecondary, size: 13)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Add anyway', style: kBody(AppColors.accent, size: 13)),
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

// ─── Token row ────────────────────────────────────────────────────────────────

// ─── Helpers ──────────────────────────────────────────────────────────────────


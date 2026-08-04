import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kora/core/services/address_book_service.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:kora/core/widgets/kora_app_bar.dart';
import 'package:kora/core/widgets/kora_button.dart';
import 'package:kora/core/widgets/kora_field.dart';
import 'package:kora/features/address_book/chains.dart';
import 'package:kora/features/address_book/widgets/address_tile.dart';
import 'package:kora/features/address_book/widgets/add_entry_sheet.dart';

/// Address book screen.
/// If [filterBlockchain] is provided, shows only that chain and returns the
/// selected address via Navigator.pop(address).
///
/// The filter is the safety property, not a convenience: opened from a send, this screen can
/// only ever hand back an address filed under the chain being sent, so no amount of tapping
/// produces a Bitcoin address for a Tron transfer.
class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key, this.filterBlockchain});
  final String? filterBlockchain;

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> with ThemeAwareMixin {
  final _searchCtrl = TextEditingController();
  List<AddressEntry> _entries = [];
  bool _loading = true;
  String _query = '';

  /// Which chain the list is narrowed to when browsing. Null means all of them. Ignored
  /// entirely when the screen was opened as a picker — there the chain is not the user's to
  /// choose.
  String? _chainFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final entries = widget.filterBlockchain != null
        ? await AddressBookService.forBlockchain(widget.filterBlockchain!)
        : await AddressBookService.load();
    if (mounted) setState(() { _entries = entries; _loading = false; });
  }

  /// The chains the book actually holds something for — no point offering a filter that
  /// would empty the list.
  List<String> get _presentChains {
    final present = _entries.map((e) => e.blockchain).toSet();
    return chains.where(present.contains).toList();
  }

  List<AddressEntry> get _visible {
    var list = _entries;
    if (_chainFilter != null) {
      list = list.where((e) => e.blockchain == _chainFilter).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((e) =>
              e.label.toLowerCase().contains(q) ||
              e.address.toLowerCase().contains(q) ||
              chainLabel(e.blockchain).toLowerCase().contains(q) ||
              chainSymbol(e.blockchain).toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  Future<void> _addEntry() async {
    final entry = await showModalBottomSheet<AddressEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEntrySheet(
        // When picking for a send, the new address can only be for that chain.
        defaultBlockchain: widget.filterBlockchain ?? _chainFilter,
        lockBlockchain: widget.filterBlockchain != null,
      ),
    );
    if (entry != null) {
      await AddressBookService.add(entry);
      await _load();
    }
  }

  Future<void> _delete(AddressEntry target) async {
    // Map the visible entry back to its index in the stored list: the list on screen is
    // filtered and searched, so its indices are not the book's.
    final all = await AddressBookService.load();
    final globalIdx = all.indexWhere((e) =>
        e.address == target.address &&
        e.label == target.label &&
        e.blockchain == target.blockchain);
    if (globalIdx >= 0) await AddressBookService.delete(globalIdx);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isPicker = widget.filterBlockchain != null;
    final visible = _visible;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: koraAppBar(
        context,
        isPicker ? 'Select Address' : 'Address Book',
        backLabel: 'Settings',
          onBack: () => Navigator.of(context).pop(),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, size: 20, color: AppColors.textPrimary),
            onPressed: _addEntry,
            tooltip: 'Add address',
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                  color: AppColors.textTertiary, strokeWidth: 1.5))
          : Column(children: [
              // Opened from a send: say plainly why this list is short.
              if (isPicker)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                  padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: AppColors.textSecondary, width: 2),
                      top: kHairlineSide(),
                      right: kHairlineSide(),
                      bottom: kHairlineSide(),
                    ),
                  ),
                  child: Text(
                    'SHOWING ${chainLabel(widget.filterBlockchain!).toUpperCase()} '
                    'ADDRESSES ONLY — AN ADDRESS FROM ANOTHER NETWORK CANNOT RECEIVE THIS.',
                    style: kLabel(AppColors.textSecondary, size: 8.5, tracking: 0.08,
                            weight: FontWeight.w400)
                        .copyWith(height: 1.8),
                  ),
                ),

              if (_entries.isNotEmpty) ...[
                const SizedBox(height: 14),
                KoraField(
                  child: Row(children: [
                    Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 17),
                    const SizedBox(width: 9),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _query = v),
                        style: koraInputStyle(),
                        decoration: koraInputDecoration('SEARCH NAME, ADDRESS OR NETWORK'),
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
              ],

              // Browsing: narrow by network. Only chains the book actually holds appear.
              if (!isPicker && _presentChains.length > 1)
                SizedBox(
                  height: 54,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                    children: [
                      _ChainChip(
                        label: 'ALL',
                        selected: _chainFilter == null,
                        onTap: () => setState(() => _chainFilter = null),
                      ),
                      for (final c in _presentChains)
                        _ChainChip(
                          label: chainSymbol(c),
                          selected: _chainFilter == c,
                          onTap: () => setState(() => _chainFilter = c),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 14),

              Expanded(
                child: _entries.isEmpty
                    ? _EmptyState(onAdd: _addEntry)
                    : visible.isEmpty
                        ? Center(
                            child: Text('NO ADDRESSES MATCH',
                                style: kLabel(AppColors.textTertiary,
                                    size: 10, tracking: 0.14)),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: visible.length,
                            itemBuilder: (_, i) {
                              final e = visible[i];
                              return AddressTile(
                                entry: e,
                                onTap: isPicker
                                    ? () => Navigator.of(context).pop(e.address)
                                    : null,
                                onCopy: () {
                                  Clipboard.setData(ClipboardData(text: e.address));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Address copied')));
                                },
                                onDelete: () => _delete(e),
                              );
                            },
                          ),
              ),
            ]),
    );
  }
}

/// One network in the browse filter — inverted when it is the one being shown.
class _ChainChip extends StatelessWidget {
  const _ChainChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AnimatedTap(
        onTap: onTap,
        pressScale: 0.95,
        child: AnimatedContainer(
          duration: kControl,
          curve: kEase,
          margin: const EdgeInsets.only(right: 1),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.textPrimary : AppColors.background,
            border: kHairline(),
          ),
          child: Text(label,
              style: kLabel(
                  selected ? AppColors.background : AppColors.textTertiary,
                  size: 9.5, tracking: 0.1)),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('NO SAVED ADDRESSES',
            style: kLabel(AppColors.textSecondary, size: 10.5, tracking: 0.16)),
        const SizedBox(height: 10),
        Text('SAVE FREQUENT ADDRESSES FOR QUICK ACCESS.',
            textAlign: TextAlign.center,
            style: kLabel(AppColors.textTertiary, size: 8.5, tracking: 0.1,
                    weight: FontWeight.w400)
                .copyWith(height: 1.8)),
        const SizedBox(height: 24),
        KoraGhost(label: 'Add Address', onTap: onAdd),
      ]),
    ),
  );
}

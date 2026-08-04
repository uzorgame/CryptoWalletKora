import 'package:flutter/material.dart';
import 'package:kora/features/address_book/chains.dart';
import 'package:kora/core/services/address_book_service.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:kora/core/widgets/kora_button.dart';
import 'package:kora/core/widgets/kora_field.dart';
import 'package:kora/features/send/executors/registry.dart';

// The sheet that files a new address.
//
// The network is not a detail here — it is half of what an address *is*. The same string can
// be a valid address on one chain and a hole in the ground on another, so this sheet:
//   • asks for the network explicitly, searchable, never guessed;
//   • checks the address against that network's own validator before it will save;
//   • locks the network when it was opened from a send, where only one chain can be meant.
// Everything filed this way carries its chain, which is what lets the send screen show only
// the addresses that can actually receive what is being sent.

class AddEntrySheet extends StatefulWidget {
  const AddEntrySheet({super.key, this.defaultBlockchain, this.lockBlockchain = false});

  final String? defaultBlockchain;

  /// Set when the book was opened from a send: the chain is decided by what is being sent,
  /// and offering to change it here could only ever produce an address that send cannot use.
  final bool lockBlockchain;

  @override
  State<AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<AddEntrySheet> with ThemeAwareMixin {
  final _labelCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _searchCtrl  = TextEditingController();
  late String _blockchain;
  bool _picking = false;
  String _query = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _blockchain = widget.defaultBlockchain ?? 'ethereum';
    _addressCtrl.addListener(() {
      if (_error != null) setState(() => _error = null);
    });
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _addressCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> get _filteredChains {
    if (_query.isEmpty) return chains;
    final q = _query.toLowerCase();
    return chains
        .where((c) =>
            chainLabel(c).toLowerCase().contains(q) ||
            chainSymbol(c).toLowerCase().contains(q))
        .toList();
  }

  void _submit() {
    final label   = _labelCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Give this address a name.');
      return;
    }
    if (address.isEmpty) {
      setState(() => _error = 'Paste the address.');
      return;
    }
    // The chain's own validator — the same one the send screen runs before it will sign.
    // Catching a mismatch here is the whole point of filing the network with the address.
    final problem = getExecutor(_blockchain)?.validateAddress(address);
    if (problem != null) {
      setState(() => _error = 'Not a valid ${chainLabel(_blockchain)} address.');
      return;
    }
    Navigator.of(context).pop(AddressEntry(
      label: label, address: address, blockchain: _blockchain,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.borderHi, width: 1)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 14, bottom: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 24, height: 2, color: AppColors.textTertiary)),
              const SizedBox(height: 18),
              Center(
                child: Text(_picking ? 'CHOOSE NETWORK' : 'ADD ADDRESS',
                    style: kLabel(AppColors.textPrimary, size: 11, tracking: 0.18)),
              ),
              const SizedBox(height: 6),
              if (_picking) _networkPicker() else _form(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── The form ─────────────────────────────────────────────────────────────────────────

  Widget _form() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KoraSlabel('Name'),
          KoraField(
            child: TextField(
              controller: _labelCtrl,
              style: koraInputStyle(),
              decoration: koraInputDecoration('E.G. MY EXCHANGE WALLET'),
            ),
          ),
          const KoraSlabel('Network'),
          // Locked when the book was opened from a send: the chain is already decided.
          AnimatedTap(
            onTap: widget.lockBlockchain
                ? null
                : () => setState(() {
                      _picking = true;
                      _query = '';
                      _searchCtrl.clear();
                    }),
            pressScale: 0.99,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 22),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(color: AppColors.surface, border: kHairline()),
              child: Row(children: [
                Text(chainSymbol(_blockchain),
                    style: kLabel(AppColors.textPrimary, size: 11, tracking: 0.08)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(chainLabel(_blockchain),
                      style: kBody(AppColors.textSecondary, size: 12)),
                ),
                Text(widget.lockBlockchain ? 'LOCKED' : '▾',
                    style: kLabel(AppColors.textTertiary, size: 9, tracking: 0.14)),
              ]),
            ),
          ),
          const KoraSlabel('Address'),
          KoraField(
            child: TextField(
              controller: _addressCtrl,
              style: koraInputStyle(),
              maxLines: 2,
              minLines: 1,
              decoration: koraInputDecoration('PASTE ADDRESS HERE'),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
              child: Text(_error!.toUpperCase(),
                  style: kLabel(AppColors.negative, size: 9, tracking: 0.08)),
            ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: KoraCta(label: 'Save Address', onTap: _submit),
          ),
        ],
      );

  // ─── The network picker ───────────────────────────────────────────────────────────────

  Widget _networkPicker() {
    final list = _filteredChains;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        KoraField(
          child: Row(children: [
            Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 17),
            const SizedBox(width: 9),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: koraInputStyle(),
                decoration: koraInputDecoration('SEARCH NETWORK'),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 34),
            child: Center(
              child: Text('NO NETWORK FOUND',
                  style: kLabel(AppColors.textTertiary, size: 10, tracking: 0.14)),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 330),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: list.length,
              itemBuilder: (_, i) {
                final c = list[i];
                final selected = c == _blockchain;
                return AnimatedTap(
                  onTap: () => setState(() {
                    _blockchain = c;
                    _picking = false;
                    _error = null;
                  }),
                  pressScale: 0.98,
                  pressOpacity: 0.85,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    decoration: BoxDecoration(border: Border(bottom: kHairlineSide())),
                    child: Row(children: [
                      SizedBox(
                        width: 42,
                        child: Text(chainSymbol(c),
                            style: kLabel(
                                selected ? AppColors.textPrimary : AppColors.textSecondary,
                                size: 11, tracking: 0.08)),
                      ),
                      Expanded(
                        child: Text(chainLabel(c),
                            style: kBody(
                                selected ? AppColors.textPrimary : AppColors.textSecondary,
                                size: 13,
                                weight: selected ? FontWeight.w500 : FontWeight.w400)),
                      ),
                      if (selected)
                        Text('✓', style: kMonoText(AppColors.textPrimary, size: 12)),
                    ]),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            onTap: () => setState(() => _picking = false),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text('BACK',
                  style: kLabel(AppColors.textSecondary, size: 9.5, tracking: 0.16)),
            ),
          ),
        ),
      ],
    );
  }
}

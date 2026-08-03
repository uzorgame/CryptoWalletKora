import 'package:flutter/material.dart';
import 'package:kora/core/widgets/animated_tap.dart';
import 'package:flutter/services.dart';
import 'package:kora/core/services/address_book_service.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';

const _chains = [
  'ethereum', 'bsc',
  'tron', 'solana', 'bitcoin', 'litecoin',
];

String _chainLabel(String b) => const {
  'ethereum': 'Ethereum',   'bsc': 'BNB Chain',
  'tron': 'Tron',           'solana': 'Solana',    'bitcoin': 'Bitcoin',
  'litecoin': 'Litecoin',
}[b] ?? b;

/// Address book screen.
/// If [filterBlockchain] is provided, shows only that chain and returns the
/// selected address via Navigator.pop(address).
class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key, this.filterBlockchain});
  final String? filterBlockchain;

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> with ThemeAwareMixin {
  List<AddressEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = widget.filterBlockchain != null
        ? await AddressBookService.forBlockchain(widget.filterBlockchain!)
        : await AddressBookService.load();
    if (mounted) setState(() { _entries = entries; _loading = false; });
  }

  Future<void> _addEntry() async {
    final entry = await showModalBottomSheet<AddressEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddEntrySheet(
        defaultBlockchain: widget.filterBlockchain,
      ),
    );
    if (entry != null) {
      await AddressBookService.add(entry);
      await _load();
    }
  }

  Future<void> _delete(int index) async {
    // Map local index back to global index if filtered
    if (widget.filterBlockchain != null) {
      final allEntries = await AddressBookService.load();
      final target = _entries[index];
      final globalIdx = allEntries.indexWhere(
          (e) => e.address == target.address && e.label == target.label && e.blockchain == target.blockchain);
      if (globalIdx >= 0) await AddressBookService.delete(globalIdx);
    } else {
      await AddressBookService.delete(index);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isPicker = widget.filterBlockchain != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(isPicker ? 'Select Address' : 'Address Book'),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded),
            onPressed: _addEntry,
            tooltip: 'Add address',
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _EmptyState(onAdd: _addEntry)
              : ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  itemCount: _entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final e = _entries[i];
                    return _AddressTile(
                      entry: e,
                      onTap: isPicker ? () => Navigator.of(context).pop(e.address) : null,
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: e.address));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Address copied')));
                      },
                      onDelete: () => _delete(i),
                    );
                  },
                ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.entry,
    required this.onCopy,
    required this.onDelete,
    this.onTap,
  });
  final AddressEntry entry;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedTap(
      onTap: onTap,
      pressScale: 0.97,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                entry.label.isNotEmpty ? entry.label[0].toUpperCase() : '?',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.label,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(
                entry.address.length > 22
                    ? '${entry.address.substring(0, 10)}…${entry.address.substring(entry.address.length - 8)}'
                    : entry.address,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_chainLabel(entry.blockchain),
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
              ),
            ]),
          ),
          IconButton(
            icon: Icon(Icons.copy_rounded, size: 18, color: AppColors.textTertiary),
            onPressed: onCopy,
            tooltip: 'Copy',
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.textTertiary),
            onPressed: () => _confirmDelete(context),
            tooltip: 'Delete',
          ),
        ]),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Remove address?', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: Text('Remove "${entry.label}" from address book?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(context); onDelete(); },
            child: Text('Remove', style: TextStyle(color: AppColors.negative)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.book_outlined, size: 56, color: AppColors.textTertiary),
      const SizedBox(height: 16),
      Text('No saved addresses', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('Save frequent addresses for quick access.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: onAdd,
        icon: Icon(Icons.add_rounded, size: 18),
        label: Text('Add Address'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: AppColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ]),
  );
}

// ─── Add entry bottom sheet ───────────────────────────────────────────────────

class _AddEntrySheet extends StatefulWidget {
  const _AddEntrySheet({this.defaultBlockchain});
  final String? defaultBlockchain;

  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<_AddEntrySheet> with ThemeAwareMixin {
  final _labelCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  late String _blockchain;

  @override
  void initState() {
    super.initState();
    _blockchain = widget.defaultBlockchain ?? 'ethereum';
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final label   = _labelCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    if (label.isEmpty || address.isEmpty) return;
    Navigator.of(context).pop(AddressEntry(
      label: label, address: address, blockchain: _blockchain,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 20),
          Text('Add Address', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          _label('Label'),
          const SizedBox(height: 8),
          _field(_labelCtrl, 'e.g. My exchange wallet'),
          const SizedBox(height: 16),
          _label('Network'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _blockchain,
                isExpanded: true,
                dropdownColor: AppColors.card,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                items: _chains.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(_chainLabel(c)),
                )).toList(),
                onChanged: (v) { if (v != null) setState(() => _blockchain = v); },
              ),
            ),
          ),
          const SizedBox(height: 16),
          _label('Address'),
          const SizedBox(height: 8),
          _field(_addressCtrl, 'Paste address here'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.textPrimary, foregroundColor: AppColors.background,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Save Address', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ]),
      ),
    );
  }

  static Widget _label(String text) => Text(text,
      style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500));

  static Widget _field(TextEditingController ctrl, String hint) => TextField(
    controller: ctrl,
    style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textTertiary),
      filled: true,
      fillColor: AppColors.surface,
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.textSecondary, width: 1.5)),
    ),
  );
}

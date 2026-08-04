import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kora/core/services/address_book_service.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/features/address_book/widgets/address_tile.dart';
import 'package:kora/features/address_book/widgets/add_entry_sheet.dart';

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
          borderRadius: BorderRadius.zero),
      builder: (_) => AddEntrySheet(
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
                    return AddressTile(
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
    ]),
  );
}

// ─── Add entry bottom sheet ───────────────────────────────────────────────────

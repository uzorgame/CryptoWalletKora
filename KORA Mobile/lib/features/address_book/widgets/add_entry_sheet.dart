import 'package:flutter/material.dart';
import 'package:kora/features/address_book/chains.dart';
import 'package:kora/core/services/address_book_service.dart';
import 'package:kora/core/services/theme_notifier.dart';
import 'package:kora/core/theme/app_theme.dart';

// The sheet that saves a new address into the book.

class AddEntrySheet extends StatefulWidget {
  const AddEntrySheet({super.key, this.defaultBlockchain});
  final String? defaultBlockchain;

  @override
  State<AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<AddEntrySheet> with ThemeAwareMixin {
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
                items: chains.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(chainLabel(c)),
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

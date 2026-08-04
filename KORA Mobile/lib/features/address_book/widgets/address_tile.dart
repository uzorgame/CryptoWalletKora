import 'package:flutter/material.dart';
import 'package:kora/features/address_book/chains.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:kora/core/services/address_book_service.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';

// One saved address: name, chain and the address itself, with copy and delete.

class AddressTile extends StatelessWidget {
  const AddressTile({
    super.key,
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

          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,

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

                ),
                child: Text(chainLabel(entry.blockchain),
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

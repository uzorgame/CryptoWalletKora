import 'package:flutter/material.dart';
import 'package:kora/features/address_book/chains.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:kora/core/services/address_book_service.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';

// One saved address: name, chain and the address itself, with copy and delete.
//
// The network leads the row. An address without its chain is not an address you can send to,
// so it is the first thing the eye lands on, not a footnote under the string.

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
      pressScale: 0.98,
      pressOpacity: 0.85,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: kHairlineSide())),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(chainSymbol(entry.blockchain),
                        style: kLabel(AppColors.textPrimary, size: 11, tracking: 0.08)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(entry.label,
                          overflow: TextOverflow.ellipsis,
                          style: kBody(AppColors.textSecondary, size: 12)),
                    ),
                  ]),
              const SizedBox(height: 5),
              Text(
                entry.address.length > 22
                    ? '${entry.address.substring(0, 10)}…${entry.address.substring(entry.address.length - 8)}'
                    : entry.address,
                style: kMonoText(AppColors.textTertiary, size: 9.5),
              ),
            ]),
          ),
          AnimatedTap(
            onTap: onCopy,
            pressScale: 0.85,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.copy_rounded, size: 15, color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(width: 4),
          AnimatedTap(
            onTap: () => _confirmDelete(context),
            pressScale: 0.85,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.delete_outline_rounded,
                  size: 15, color: AppColors.textTertiary),
            ),
          ),
        ]),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
            side: BorderSide(color: AppColors.borderHi, width: 1),
            borderRadius: BorderRadius.zero),
        title: Text('REMOVE ADDRESS?',
            style: kLabel(AppColors.textPrimary, size: 11, tracking: 0.16)),
        content: Text(
            'Remove "${entry.label}" (${chainLabel(entry.blockchain)}) from the address book?',
            style: kBody(AppColors.textSecondary, size: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL',
                style: kLabel(AppColors.textSecondary, size: 9.5, tracking: 0.16)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(context); onDelete(); },
            child: Text('REMOVE',
                style: kLabel(AppColors.negative, size: 9.5, tracking: 0.16)),
          ),
        ],
      ),
    );
  }
}

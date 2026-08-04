import 'package:flutter/material.dart';
import 'package:kora/features/address_book/chains.dart';
import 'package:kora/core/widgets/input/animated_tap.dart';
import 'package:kora/core/services/address_book_service.dart';
import 'package:kora/core/theme/app_theme.dart';
import 'package:kora/core/theme/kora_design.dart';
import 'package:kora/core/widgets/kora_rows.dart';

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
    // The prototype's row: a lettered square, the name with its network as a hairline tag,
    // the address in mono beneath, and the copy glyph at the edge.
    return KoraRow(
      onTap: onTap,
      children: [
        KoraBox(entry.label.isNotEmpty ? entry.label[0] : '?', size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(entry.label.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: kLabel(AppColors.textPrimary, size: 12.5, tracking: 0.06)),
              ),
              const SizedBox(width: 7),
              KoraTag(chainLabel(entry.blockchain)),
            ]),
            const SizedBox(height: 4),
            Text(
              entry.address.length > 26
                  ? '${entry.address.substring(0, 12)}…${entry.address.substring(entry.address.length - 8)}'
                  : entry.address,
              overflow: TextOverflow.ellipsis,
              style: kMonoText(AppColors.textSecondary, size: 10),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        AnimatedTap(
          onTap: onCopy,
          pressScale: 0.85,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Text('⧉', style: kMonoText(AppColors.textSecondary, size: 13)),
          ),
        ),
        AnimatedTap(
          onTap: () => _confirmDelete(context),
          pressScale: 0.85,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(Icons.delete_outline_rounded,
                size: 15, color: AppColors.textTertiary),
          ),
        ),
      ],
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

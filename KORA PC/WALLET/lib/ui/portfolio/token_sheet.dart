import 'package:flutter/material.dart';

import '../../core/constants/token_catalog.dart';
import '../../core/theme/kora_design.dart';
import '../common/kora_field.dart';
import '../common/kora_sheet.dart';
import '../format/money.dart';

/// One row's worth of what the sheet needs to know about a coin.
class TokenChoice {
  const TokenChoice({required this.token, required this.shown, required this.held});

  final CatalogToken token;

  /// Whether it is currently on the portfolio.
  final bool shown;

  /// How much of it the wallet holds. A coin with a balance cannot be taken off the list —
  /// hiding a funded coin hides money, and the user would have no way back to it.
  final double held;

  bool get removable => held <= 0;
}

/// Choose which coins the portfolio shows.
///
/// Adding and removing are the same list rather than two screens: the question the user is
/// answering is "which coins do I care about", and splitting it in two makes them ask it
/// twice. Removal is only offered where it is safe, so nothing here can lose sight of funds.
class TokenSheet extends StatefulWidget {
  const TokenSheet({super.key, required this.choices, required this.onToggle});

  final List<TokenChoice> choices;

  /// Called with the coin and whether it should now be shown.
  final void Function(CatalogToken token, bool shown) onToggle;

  @override
  State<TokenSheet> createState() => _TokenSheetState();
}

class _TokenSheetState extends State<TokenSheet> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<TokenChoice> get _matches {
    final query = _search.text.trim().toLowerCase();
    final all = widget.choices;
    if (query.isEmpty) return all;
    return all
        .where(
          (c) =>
              c.token.symbol.toLowerCase().contains(query) ||
              c.token.name.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    final matches = _matches;

    return KoraSheet(
      title: 'COINS',
      subtitle: 'PORTFOLIO',
      width: 460,
      body: [
        KoraField(
          label: 'FIND',
          controller: _search,
          autofocus: true,
          placeholder: 'Name or ticker',
          hint: 'A coin holding a balance always stays on the list.',
        ),
        const SizedBox(height: 16),
        // Fixed height so the sheet does not resize as the user types. A dialog that grows
        // and shrinks under the cursor moves the row you were about to click.
        SizedBox(
          height: 300,
          child: matches.isEmpty
              ? Center(
                  child: Text(
                    'NOTHING MATCHES “${_search.text.trim()}”',
                    style: koraLabel(p.text3, size: 9.5, tracking: 0.14),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: matches.length,
                  itemBuilder: (context, i) => _TokenRow(
                    choice: matches[i],
                    onToggle: widget.onToggle,
                    last: i == matches.length - 1,
                  ),
                ),
        ),
      ],
    );
  }
}

class _TokenRow extends StatefulWidget {
  const _TokenRow({required this.choice, required this.onToggle, required this.last});

  final TokenChoice choice;
  final void Function(CatalogToken token, bool shown) onToggle;
  final bool last;

  @override
  State<_TokenRow> createState() => _TokenRowState();
}

class _TokenRowState extends State<_TokenRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = Kora.of(context);
    final choice = widget.choice;
    final locked = choice.shown && !choice.removable;

    return MouseRegion(
      cursor: locked ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: locked ? null : () => widget.onToggle(choice.token, !choice.shown),
        child: AnimatedContainer(
          duration: kHoverFast,
          curve: kEase,
          decoration: BoxDecoration(
            color: _hover && !locked ? p.hover : p.hover.withAlpha(0),
            border: Border(bottom: BorderSide(color: widget.last ? Colors.transparent : p.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(choice.token.symbol, style: koraNumeric(p.text, size: 12)),
                    const SizedBox(height: 3),
                    Text(choice.token.name, style: koraLabel(p.text3, size: 9, tracking: 0.1)),
                  ],
                ),
              ),
              if (choice.held > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(quantity(choice.held), style: koraNumeric(p.text2, size: 11)),
                ),
              Text(
                locked ? 'HELD' : (choice.shown ? 'REMOVE' : 'ADD'),
                style: koraLabel(
                  locked ? p.text3 : (choice.shown ? p.down : p.text),
                  size: 9,
                  tracking: 0.14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

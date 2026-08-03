# `lib/ui` — the redesigned interface

Everything under this directory is presentation. It reads from `lib/core` and calls into it;
nothing in `lib/core` imports from here. That one rule is what keeps a redesign from being
able to damage the wallet.

The interface it implements is the one built and approved in `design/` — same tokens, same
timings, same structure.

## Layout

```
ui/
  shell/            the window itself: chrome, navigation, view switching
  portfolio/        01 — balance, curve, holdings
  coin/             a single asset: position, cost basis, its own history
  send/             outgoing transactions
  history/          every movement, and the detail sheet for one
  settings/         security, display, wallets, about
  onboarding/       first run, create, restore
  common/           pieces used by more than one of the above
  format/           turning numbers and moments into text
```

## Rules this code follows

**One responsibility per file.** A file is named for the single thing it renders or decides.
`asset_row.dart` renders one row; it does not also fetch prices or format money.

**No file grows past what fits in a head.** The shell it replaces was 1,793 lines holding the
window bootstrap, the root widget, onboarding, the PIN gate, the sidebar and the page host at
once. Anything approaching a few hundred lines here is a signal that a piece wants its own
file.

**Presentation takes data, it does not go looking for it.** Widgets receive what they draw.
Where a screen genuinely owns state — a form, a wizard — that state lives in a controller
beside it, not scattered through the widget tree.

**Design tokens come from one place.** Colours, type, spacing and every animation duration
live in `core/theme/kora_design.dart`. A literal `Color(0x…)` or a bare `Duration` inside a
widget here is a bug: it is a value that will drift away from the rest of the system.

**Nothing here writes to storage directly.** All persistence goes through the existing
repositories and services in `lib/core`, which are the code that has been reviewed for the
consequences of getting it wrong.

## How a view reaches the app's state

```
kora_gate.dart      onboarding | lock | app — decided from the store, not from a flag
  kora_app.dart     the shell, plus the two things no single view owns:
                    which coin is open, and which asset Send starts on
    screens/        one file per destination: reads providers, hands plain data downward
      ↓
    <feature>/      widgets that take what they draw and nothing more
```

`screens/` is the only layer that touches Riverpod. Everything below it receives `Asset`,
`TxRecord`, `CurrencyState` — the app's own types, unchanged. That is deliberate: an earlier
pass introduced parallel models to sit between the two, and each one became a second version
of the truth that nothing else in the app knew about.

Providers are the ones that already existed. When a screen needs something there is no
provider for, the provider is added under `core/state/providers/` — where the rest of them
live — rather than the screen reaching for a service directly.

## Where the app decides things once

Some rules are enforced in one place because holding them in several is how they drift:

- **`features/send/send_gateway.dart`** — which chain uses which executor and which fee
  provider. This was three separate switch statements over the same blockchain strings.
- **`core/services/theme_notifier.dart`** — the theme. `AppSettings` also carried one, over
  the same storage key and in a different vocabulary, so choosing dark stored a value the
  reader did not recognise and read back as light.
- **`core/services/localization_service.dart`** — the language list, so the picker cannot
  offer a translation that was never shipped.

## Two rules that were learned the hard way

**Never fade to `Colors.transparent`.** It is transparent *black*, and `Color.lerp` is not
premultiplied: fading a surface to it drags red, green and blue down towards zero while alpha
falls, so the midpoint of the transition is a grey that appears nowhere in the design. On the
rail this produced a flashing block, and because leaving one row and entering the next start in
the same frame, two of them flashed together. Fade `p.hover` to `p.hover.withAlpha(0)` instead
— same rgb, alpha only. `p.hover` and `p.selected` exist for exactly this.

**A provider that returns a `List` notifies every time it is recomputed.** Riverpod compares
with `!=`, which for a List is identity, so `assets.where(...).toList()` is always "new". Any
`FutureProvider` that watches one of those re-runs — and if it makes a network request, that
request repeats on every price tick. Watch a scalar through `select`, and keep the source from
emitting when nothing changed: `Wallet` and `Asset` are freezed and compare by value, which is
what `CurrentWalletNotifier._publish` relies on.

# KORA

Three products, one design language.

```
KORA Mobile/            Flutter wallet for Android and iOS
  lib/core/theme/       the design language itself — kora_design.dart holds every token
  lib/core/widgets/     the parts every screen is built from: rows, fields, buttons, the mark
  lib/core/blockchain/  keys, chains, signing — the part that must never be broken casually
  lib/features/         one folder per screen
  docs/                 what it is, in English and Ukrainian

KORA PC/
  WALLET/               Flutter wallet for Windows
    lib/core/           keys, chains, storage — the part that must never be broken casually
    lib/ui/             the redesigned interface (see lib/ui/ARCHITECTURE.md)
    lib/screens/        the screens being replaced, still live until they are
    design/             the approved prototype this interface was built from
    docs/               product documentation
    tools/branding/     icon packs and the installer artwork generator
    installer_combined.iss   the installer for both Windows products

  MARKET/               Flutter price widget for Windows
    lib/                the redesigned interface, complete
    design/             the approved prototype
    docs/               product documentation
    installer_market.iss     Market on its own, for a standalone release
```

## The design language

Monochrome, square, ruled in hairlines. No rounded corner, no circle, no gradient, no
shadow anywhere in the product — colour is spent only on what a price did, so green and red
mean one thing and are never decoration.

Three faces, each with a job:

| Face | Carries |
| --- | --- |
| Space Grotesk | figures — balances, amounts, prices |
| JetBrains Mono | labels, tickers, addresses, every table row |
| Inter | prose — onboarding copy, warnings, legal text |

Every token lives in one file per product — `lib/core/theme/kora_design.dart` — and every
screen is assembled from the widgets beside it, so a measurement cannot drift between two
screens without being changed in the one place that decides it.

## Running the design prototypes

Each Windows product keeps the prototype its interface was approved from, so a question
about intended behaviour has an answer that can be opened rather than remembered.

```bash
node "KORA PC/MARKET/design/server.mjs"        # localhost:5182
node "KORA PC/WALLET/design/server.mjs"        # localhost:5183
```

## Before the first build

Two files are deliberately absent from this repository because they hold secrets. Copy the
templates beside them and fill in your own values:

```bash
cp "KORA Mobile/lib/core/config/api_secrets.example.dart" "KORA Mobile/lib/core/config/api_secrets.dart"
cp "KORA PC/WALLET/lib/core/config/api_secrets.example.dart" "KORA PC/WALLET/lib/core/config/api_secrets.dart"
```

`android/key.properties` and any `.jks` are ignored for the same reason. Without a keystore
at the path `key.properties` names, a release build falls back to the debug signature: it
installs and runs, but it is not a publishable artefact and cannot update an APK signed with
a different key.

## Building

```bash
cd "KORA Mobile" && flutter build apk --release
cd "KORA PC/WALLET" && flutter build windows --release
cd "KORA PC/MARKET" && flutter build windows --release
```

Then compile `KORA PC/WALLET/installer_combined.iss` with Inno Setup 6 for the Windows pair.

## Why the two Windows products are siblings

Market used to sit inside the wallet's own source tree. That made every analyzer run walk
into a second Dart package under the wrong package config, every clean touch both apps, and
every path in the installer script relative to a nesting that meant nothing. They are two
products; they are laid out as two products.

## Two things to know before changing a wallet

**Windows.** User funds are reachable only through the record under
`%APPDATA%\com.kora\kora_windows\`. `lib/core/repositories/wallet_repository.dart` explains,
in the code, what makes that record easy to destroy and what now stands in the way. Read it
before touching the `Wallet` model, `CacheService`, or anything in an installer's
`[UninstallDelete]`.

**Mobile.** The seed is stored encrypted under the app PIN, and the address shown on screen
must belong to the key that signs. `test/unit/crypto/` covers the encryption and key
handling; run it before and after anything under `lib/core/crypto/` or `lib/core/blockchain/`
and compare the counts rather than trusting that it still compiles.

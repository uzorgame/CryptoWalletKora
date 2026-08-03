# KORA

Two products, one design system.

```
KORA Mobile/            Flutter wallet for Android and iOS
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

## Why the two Windows products are siblings

Market used to sit inside the wallet's own source tree. That made every analyzer run walk
into a second Dart package under the wrong package config, every clean touch both apps, and
every path in the installer script relative to a nesting that meant nothing. They are two
products; they are laid out as two products.

## Running the design prototypes

Each Windows product keeps the prototype its interface was approved from, so a question about
intended behaviour has an answer that can be opened rather than remembered.

```bash
node "KORA PC/MARKET/design/server.mjs"    # localhost:5182
node "KORA PC/WALLET/design/server.mjs"    # localhost:5183
```

## Building

```bash
cd "KORA PC/WALLET" && flutter build windows --release
cd "KORA PC/MARKET" && flutter build windows --release
```

Then compile `KORA PC/WALLET/installer_combined.iss` with Inno Setup 6.

## One thing to know before changing the wallet

User funds are reachable only through the record under `%APPDATA%\com.kora\kora_windows\`.
`lib/core/repositories/wallet_repository.dart` explains, in the code, what makes that record
easy to destroy and what now stands in the way. Read it before touching the `Wallet` model,
`CacheService`, or anything in an installer's `[UninstallDelete]`.

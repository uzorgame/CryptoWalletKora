# KORA WALLET (Mobile - Android)

**Non-Custodial Multi-Chain Cryptocurrency Wallet for Android**

Version: 3.5.0+24

---

## 📋 Overview

**Kora Wallet for Android** is a secure, non-custodial mobile cryptocurrency wallet that supports multiple blockchain networks. Built with Flutter, it provides a native Android experience for managing digital assets across Bitcoin, Ethereum, Solana, Tron, BSC, and other major blockchains on the go.

### Key Features

- **Non-Custodial**: Full control of your private keys - never stored on servers
- **Multi-Chain Support**: 8+ blockchain networks in one mobile wallet
- **Multi-Asset**: Support for native coins and tokens (ERC-20, BEP-20, TRC-20, SPL)
- **HD Wallet**: BIP39/BIP32 hierarchical deterministic wallet implementation
- **Biometric Security**: Fingerprint and face unlock support
- **Secure Enclave**: Hardware-backed key storage on supported devices
- **Real-Time Prices**: Live cryptocurrency prices with 24h change tracking
- **QR Code Scanner**: Built-in camera scanner for addresses and payment requests
- **Transaction History**: Complete transaction history for all supported chains
- **Portfolio Tracking**: Real-time portfolio value with interactive charts
- **Modern UI**: Beautiful Material Design interface with smooth animations
- **Multi-Language**: Support for multiple languages
- **Cross-Platform**: Also available for iOS (future release)

---

## 🏗️ Architecture

### Technology Stack

- **Framework**: Flutter 3.10.4+ (Dart SDK)
- **Platform**: Android (iOS support planned)
- **Minimum SDK**: Android 5.0 (API 21)
- **Target SDK**: Android 14 (API 34)
- **State Management**: Riverpod (flutter_riverpod ^2.5.1)
- **Security**: 
  - `flutter_secure_storage` ^9.2.2 (encrypted key storage)
  - `local_auth` ^2.3.0 (biometric authentication)
  - `encrypt` ^5.0.3 (AES encryption)
- **Cryptography**:
  - `bip39` ^1.0.6 (mnemonic generation)
  - `bip32` ^2.0.0 (HD wallet derivation)
  - `pointycastle` ^3.9.1 (cryptographic primitives)
  - `web3dart` ^2.7.3 (Ethereum/EVM chains)
- **UI Components**:
  - `fl_chart` ^0.69.0 (portfolio charts)
  - `qr_flutter` ^4.1.0 (QR code generation)
  - `mobile_scanner` ^6.0.0 (QR code scanning)
  - `cached_network_image` ^3.3.1 (image caching)
  - `shimmer` ^3.0.0 (loading animations)

### Project Structure

```
kora/
├── lib/
│   ├── main.dart                    # Application entry point
│   ├── core/                        # Core functionality
│   │   ├── blockchain/              # Blockchain-specific implementations
│   │   │   ├── bitcoin/             # Bitcoin service & wallet
│   │   │   │   ├── bitcoin_service.dart
│   │   │   │   ├── bitcoin_wallet.dart
│   │   │   │   ├── bitcoin_signer.dart
│   │   │   │   └── bitcoin_transaction.dart
│   │   │   ├── ethereum/            # Ethereum/EVM service
│   │   │   │   ├── ethereum_service.dart
│   │   │   │   └── ethereum_wallet.dart
│   │   │   ├── solana/              # Solana service & SPL tokens
│   │   │   │   ├── solana_service.dart
│   │   │   │   ├── solana_wallet.dart
│   │   │   │   └── spl_token.dart
│   │   │   └── tron/                # Tron service & TRC-20
│   │   │       ├── tron_service.dart
│   │   │       ├── tron_wallet.dart
│   │   │       └── tron_transaction.dart
│   │   ├── crypto/                  # Cryptographic utilities
│   │   │   ├── hd_wallet.dart       # HD wallet implementation
│   │   │   ├── mnemonic.dart        # BIP39 mnemonic handling
│   │   │   ├── key_manager.dart     # Private key management
│   │   │   └── encryption.dart      # Encryption/decryption
│   │   ├── models/                  # Data models (Freezed)
│   │   │   ├── wallet.dart          # Wallet model
│   │   │   ├── asset.dart           # Asset/token model
│   │   │   └── transaction.dart     # Transaction model
│   │   ├── services/                # Business logic services
│   │   │   ├── balance_service.dart # Balance fetching
│   │   │   ├── crypto_price_service.dart # Price tracking
│   │   │   ├── binance_price_stream.dart # Real-time WebSocket prices
│   │   │   ├── tx_history_service.dart # Transaction history
│   │   │   ├── storage_service.dart # Secure storage wrapper
│   │   │   ├── biometric_service.dart # Biometric authentication
│   │   │   ├── lock_service.dart    # Auto-lock functionality
│   │   │   ├── cache_service.dart   # Caching layer
│   │   │   └── portfolio_chart_service.dart # Portfolio charts
│   │   ├── repositories/            # Data repositories
│   │   │   ├── wallet_repository.dart
│   │   │   └── price_repository.dart
│   │   ├── state/                   # Riverpod providers
│   │   │   └── providers/
│   │   ├── config/                  # Configuration
│   │   │   └── api_config.dart      # API endpoints & keys
│   │   ├── constants/               # Constants
│   │   │   └── token_catalog.dart   # Token addresses
│   │   └── theme/                   # App theming
│   │       └── app_theme.dart       # Light/dark themes
│   ├── features/                    # Feature modules
│   │   ├── splash/                  # Splash screen
│   │   ├── onboarding/              # Onboarding flow
│   │   ├── wallet_setup/            # Wallet creation/import
│   │   ├── home/                    # Home screen with portfolio
│   │   ├── send/                    # Send transactions
│   │   │   ├── send_screen.dart
│   │   │   ├── executors/           # Transaction executors
│   │   │   │   ├── utxo_executor.dart    # BTC/LTC/BCH
│   │   │   │   ├── evm_executor.dart     # ETH/BNB/ETC
│   │   │   │   ├── tron_executor.dart    # TRX
│   │   │   │   └── solana_executor.dart  # SOL
│   │   │   └── fee/                 # Fee estimation services
│   │   │       ├── bitcoin_fee/
│   │   │       ├── ethereum_fee/
│   │   │       ├── solana_fee/
│   │   │       └── tron_fee/
│   │   ├── receive/                 # Receive screen (QR codes)
│   │   ├── asset_detail/            # Asset detail view
│   │   ├── transaction_detail/      # Transaction detail view
│   │   ├── settings/                # Settings & preferences
│   │   └── lock/                    # Lock screen with PIN/biometric
│   └── test/                        # Unit tests
├── android/                         # Android platform code
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── AndroidManifest.xml
│   │   │   └── kotlin/
│   │   └── build.gradle
│   └── gradle/
├── ios/                             # iOS platform code (future)
├── assets/
│   ├── crypto_icons/                # 100+ cryptocurrency icons
│   ├── fonts/                       # SF Pro Display fonts
│   └── app_icon.png                 # App launcher icon
└── pubspec.yaml                     # Dependencies
```

### Core Architecture Patterns

#### 1. **Clean Architecture**
- **Presentation Layer**: UI screens and widgets
- **Domain Layer**: Business logic and use cases
- **Data Layer**: Repositories and data sources

#### 2. **State Management (Riverpod)**
- Provider-based dependency injection
- Immutable state with Freezed models
- Reactive UI updates
- Scoped providers for feature isolation

#### 3. **Security First**
- Private keys encrypted with AES-256
- Hardware-backed keystore on supported devices
- Biometric authentication for sensitive operations
- Auto-lock after inactivity
- Secure memory handling

---

## 💰 Supported Blockchains & Assets

### Native Blockchains (8)

1. **Bitcoin (BTC)** - UTXO-based blockchain
   - P2PKH (Legacy) addresses
   - P2WPKH (SegWit) addresses
   - Fee estimation via mempool.space

2. **Litecoin (LTC)** - UTXO-based blockchain
   - Similar to Bitcoin implementation
   - Litecoin-specific address format

3. **Bitcoin Cash (BCH)** - UTXO-based blockchain
   - CashAddr format support
   - BCH-specific transaction building

4. **Ethereum (ETH)** - EVM-compatible smart contract platform
   - EIP-155 transaction signing
   - Gas estimation and optimization
   - ERC-20 token support

5. **Binance Smart Chain (BNB)** - EVM-compatible
   - BSC-specific RPC endpoints
   - BEP-20 token support
   - Lower gas fees than Ethereum

6. **Ethereum Classic (ETC)** - EVM-compatible
   - Original Ethereum chain
   - EVM smart contract support

7. **Tron (TRX)** - DPoS blockchain
   - TRC-20 token support
   - Energy and bandwidth management
   - Fast transaction finality

8. **Solana (SOL)** - High-performance blockchain
   - SPL token support
   - Sub-second transaction finality
   - Low transaction fees

### Token Standards

- **ERC-20** (Ethereum): USDT, USDC, DAI, and 1000+ tokens
- **BEP-20** (BSC): USDT, USDC, and BSC tokens
- **TRC-20** (Tron): USDT, USDC, and Tron tokens
- **SPL** (Solana): USDC and other SPL tokens

### Total Supported Assets

**17+ pre-configured assets** + ability to add custom tokens:
- 8 native coins
- 9+ popular tokens (USDT on 3 chains, USDC on 4 chains, DAI)
- Custom token import via contract address

---

## 🔐 Security Features

### Multi-Layer Security

#### 1. **Key Management**
- **BIP39 Mnemonic**: 12/24-word recovery phrases
- **BIP32 HD Wallet**: Hierarchical deterministic key derivation
- **Secure Storage**: Android Keystore for hardware-backed encryption
- **AES-256 Encryption**: Military-grade encryption for private keys
- **No Cloud Backup**: Keys never leave the device

#### 2. **Authentication**
- **PIN Protection**: 4-6 digit PIN for wallet access
- **Biometric Authentication**: Fingerprint and face unlock
- **Auto-Lock**: Configurable auto-lock timeout (1-30 minutes)
- **Lock on Background**: Immediate lock when app goes to background

#### 3. **Transaction Security**
- **Confirmation Required**: PIN/biometric confirmation for all transactions
- **Address Validation**: Checksum validation for all addresses
- **Amount Confirmation**: Clear display of send amount and fees
- **Transaction Preview**: Review all details before signing

#### 4. **Privacy**
- **No Analytics**: No user tracking or analytics
- **No Account Required**: No email, phone, or personal information
- **Local Data Only**: All data stored locally on device
- **Open Source Ready**: Transparent security implementation

---

## 🔧 Technical Implementation

### Blockchain Services

#### Bitcoin/UTXO Chains (BTC, LTC, BCH)

**Implementation**: `lib/core/blockchain/bitcoin/`

**Features**:
- UTXO selection with coin control
- P2PKH and P2WPKH address generation
- Transaction building and signing
- Fee estimation (slow/normal/fast)
- Broadcast to multiple nodes with fallback

**APIs Used**:
- mempool.space (primary)
- blockstream.info (fallback)
- litecoinspace.org (LTC)
- api.haskoin.com (BCH)

#### Ethereum/EVM Chains (ETH, BNB, ETC)

**Implementation**: `lib/core/blockchain/ethereum/`

**Features**:
- EIP-155 transaction signing
- ERC-20 token transfers
- Gas price estimation
- Nonce management
- Contract interaction via web3dart

**APIs Used**:
- Ankr RPC (primary)
- PublicNode (fallback)
- Etherscan API (transaction history)
- BscScan API (BSC history)

#### Tron (TRX)

**Implementation**: `lib/core/blockchain/tron/`

**Features**:
- TRC-20 token support
- Energy/bandwidth calculation
- Transaction signing with Ed25519
- Smart contract calls

**APIs Used**:
- api.trongrid.io (primary)
- TronScan API (transaction history)

#### Solana (SOL)

**Implementation**: `lib/core/blockchain/solana/`

**Features**:
- SPL token support
- Ed25519 signature scheme
- Transaction serialization
- Recent blockhash fetching

**APIs Used**:
- Helius RPC (primary with API key)
- Public Solana RPC (fallback)

### Fee Estimation System

Each blockchain has dedicated fee estimation services:

```
lib/features/send/fee/
├── bitcoin_fee/
│   └── bitcoin_fee_service.dart      # mempool.space API
├── litecoin_fee/
│   └── litecoin_fee_service.dart     # litecoinspace.org API
├── bitcoin_cash_fee/
│   └── bitcoin_cash_fee_service.dart # BlockCypher API
├── ethereum_fee/
│   └── ethereum_fee_service.dart     # Etherscan gas oracle
├── bsc_fee/
│   └── bsc_fee_service.dart          # BscScan gas oracle
├── ethereum_classic_fee/
│   └── ethereum_classic_fee_service.dart # Fixed fee
├── tron_fee/
│   └── tron_fee_service.dart         # TronScan API
└── solana_fee/
    └── solana_fee_service.dart       # Helius RPC
```

**Fee Tiers**:
- **Slow**: Low priority, longer confirmation time
- **Normal**: Standard priority, average confirmation time
- **Fast**: High priority, quick confirmation

### Real-Time Price Updates

**Implementation**: Binance WebSocket + REST API fallback

```
BinancePriceStream (WebSocket)
    ↓ (real-time updates)
CryptoPriceService
    ↓ (fallback to REST)
CoinGecko API → CryptoCompare API → Cache
    ↓
Portfolio value calculation
    ↓
UI update via Riverpod
```

**Features**:
- Sub-second price updates via WebSocket
- Automatic reconnection on connection loss
- Fallback to REST APIs if WebSocket fails
- Persistent cache for offline access
- 24h price change tracking

---

## 🚀 Features

### Wallet Management

- **Create New Wallet**: Generate secure 12/24-word mnemonic
- **Import Wallet**: Import existing wallet via mnemonic phrase
- **Backup Reminder**: Persistent reminders to backup mnemonic
- **Wallet Recovery**: Restore wallet from mnemonic

### Portfolio Management

- **Portfolio Overview**: Total value in USD with 24h change
- **Asset List**: All assets with balances and values
- **Interactive Charts**: 7-day portfolio value chart
- **Asset Sorting**: Sort by value, name, or 24h change
- **Pull to Refresh**: Manual balance refresh

### Send Transactions

- **Multi-Chain Send**: Send any supported asset
- **Address Input**: Manual entry or QR code scan
- **Amount Input**: Enter amount in crypto or USD
- **Fee Selection**: Choose transaction speed and fee
- **Address Book**: Save frequently used addresses
- **Recent Addresses**: Quick access to recent recipients
- **Transaction Preview**: Review before confirmation
- **Biometric Confirmation**: Secure transaction approval

### Receive Funds

- **QR Code Display**: Large, scannable QR code
- **Address Copy**: One-tap address copying
- **Share Address**: Share via messaging apps
- **Multiple Formats**: Support for different address formats

### Transaction History

- **Complete History**: All transactions for each asset
- **Transaction Details**: Full information for each transaction
- **Status Tracking**: Pending/confirmed/failed status
- **Block Explorer Links**: Open in external block explorer
- **Search & Filter**: Find specific transactions

### Settings & Customization

- **Theme**: Light/dark mode toggle
- **Language**: Multiple language support
- **Currency**: Display values in different fiat currencies
- **Security**: PIN/biometric settings, auto-lock timeout
- **Network**: Custom RPC endpoints (advanced users)
- **About**: Version info, privacy policy, terms

---

## 📱 Mobile-Specific Features

### Android Optimizations

- **Adaptive Icons**: Support for Android adaptive icons
- **Edge-to-Edge**: Full-screen immersive experience
- **System Theme**: Follows Android system theme
- **Share Integration**: Native Android share sheet
- **Clipboard**: Secure clipboard handling
- **Permissions**: Camera permission for QR scanning

### Performance

- **Fast Startup**: Optimized splash screen and initialization
- **Smooth Animations**: 60 FPS animations throughout
- **Efficient Memory**: Proper image caching and disposal
- **Background Handling**: Proper app lifecycle management
- **Battery Optimization**: Minimal background activity

### User Experience

- **Material Design 3**: Modern Android design language
- **Haptic Feedback**: Tactile feedback for interactions
- **Swipe Gestures**: Intuitive swipe-to-refresh
- **Bottom Navigation**: Easy thumb-reach navigation
- **Floating Action Button**: Quick access to send/receive

---

## 🛠️ Building & Running

### Prerequisites

- Flutter SDK 3.10.4 or higher
- Android Studio or VS Code
- Android SDK (API 21-34)
- JDK 11 or higher

### Setup

```bash
# Clone repository
git clone <repository-url>
cd kora

# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Build APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release
```

### Configuration

1. **API Keys**: Configure in `lib/core/config/api_config.dart`
   - Etherscan API key
   - BscScan API key
   - Helius API key (Solana)
   - CoinGecko API key (optional)

2. **App Icon**: Located in `assets/app_icon.png`
   - Generate icons: `flutter pub run flutter_launcher_icons`

3. **Environment**: Create `.env` file from `.env.example`

### Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Run with coverage
flutter test --coverage
```

---

## 📦 Distribution

### Google Play Store

The app can be published to Google Play Store:
- Minimum SDK: API 21 (Android 5.0)
- Target SDK: API 34 (Android 14)
- App Bundle format for optimal size

### APK Distribution

Direct APK distribution for users who prefer sideloading:
- Release APK available in `build/app/outputs/flutter-apk/`
- Signed with release keystore

---

## 🎨 UI/UX Design

### Design System

- **Typography**: SF Pro Display font family
- **Color Palette**: 
  - Light theme: White background, blue accents
  - Dark theme: Dark background, blue accents
- **Spacing**: 8px grid system
- **Border Radius**: Consistent 12px-16px rounded corners
- **Elevation**: Material elevation for depth

### Screen Flow

```
Splash Screen
    ↓
Onboarding (first launch)
    ↓
Wallet Setup (create/import)
    ↓
Home Screen (portfolio)
    ├─→ Asset Detail
    │   ├─→ Send
    │   └─→ Receive
    ├─→ Transaction History
    │   └─→ Transaction Detail
    └─→ Settings
```

### Animations

- **Splash**: Logo fade-in and scale animation
- **Theme Switch**: Smooth fade overlay transition
- **List Items**: Shimmer loading effect
- **Charts**: Animated line drawing
- **Buttons**: Scale and ripple effects

---

## 🔗 Integration with Kora Ecosystem

Kora Wallet (Mobile) is part of the KORA ecosystem:

- **Kora Wallet (Mobile)**: This application
- **Kora Wallet (Windows)**: Desktop version with same features
- **Kora Market (Widget)**: Real-time price tracker widget

**Shared Codebase**:
- ~90% code shared between mobile and desktop versions
- Same blockchain implementations
- Same security model
- Same UI components (adapted for platform)

---

## 📝 Version History

**v3.5.0+24** (Current)
- Multi-chain wallet support (8 blockchains)
- Non-custodial HD wallet implementation
- Biometric authentication
- Real-time price tracking via WebSocket
- Complete transaction history
- Send/receive functionality for all chains
- QR code scanner and generator
- Portfolio charts
- Light/dark theme
- Auto-lock security
- Fee estimation for all chains

---

## 🤝 Contributing

This is a private project. For issues or feature requests, please contact the development team.

---

## 📄 License

Private project - Not published to pub.dev

---

## 🔗 Resources

- **Flutter**: https://flutter.dev
- **Riverpod**: https://riverpod.dev
- **Web3dart**: https://pub.dev/packages/web3dart
- **BIP39**: https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki
- **BIP32**: https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
- **Material Design**: https://m3.material.io

---

**Kora Wallet** - Your keys, your crypto, your freedom 🔐📱

# KORA WALLET (Windows Desktop)

**Non-Custodial Multi-Chain Cryptocurrency Wallet for Windows**

Version: 3.5.0+1

---

## 📋 Overview

**Kora Wallet for Windows** is a secure, non-custodial cryptocurrency wallet that supports multiple blockchain networks. Built with Flutter, it provides a native Windows desktop experience for managing digital assets across Bitcoin, Ethereum, Solana, Tron, BSC, and other major blockchains.

### Key Features

- **Non-Custodial**: Full control of your private keys - stored securely on your device
- **Multi-Chain Support**: 8+ blockchain networks in one wallet
- **Multi-Asset**: Support for native coins and tokens (ERC-20, BEP-20, TRC-20, SPL)
- **HD Wallet**: BIP39/BIP32 hierarchical deterministic wallet implementation
- **Secure Storage**: Encrypted private keys using `flutter_secure_storage`
- **Real-Time Prices**: Live cryptocurrency prices via CoinGecko and CryptoCompare APIs
- **Transaction History**: Complete transaction history for all supported chains
- **QR Code Support**: Generate and scan QR codes for addresses
- **Modern UI**: Beautiful interface with light/dark theme support
- **Multi-Language**: Support for multiple languages

---

## 🏗️ Architecture

### Technology Stack

- **Framework**: Flutter 3.10.4+ (Dart SDK)
- **Platform**: Windows Desktop
- **State Management**: Riverpod (flutter_riverpod ^2.5.1)
- **Security**: 
  - `flutter_secure_storage` ^9.2.2 (encrypted key storage)
  - `encrypt` ^5.0.3 (AES encryption)
  - `local_auth` support (biometric authentication)
- **Cryptography**:
  - `bip39` ^1.0.6 (mnemonic generation)
  - `bip32` ^2.0.0 (HD wallet derivation)
  - `pointycastle` ^3.9.1 (cryptographic primitives)
  - `web3dart` ^2.7.3 (Ethereum/EVM chains)
- **Networking**:
  - `dio` ^5.4.3+1 (HTTP client)
  - `web_socket_channel` ^2.4.5 (WebSocket for real-time data)
  - `http` ^1.2.1 (REST API calls)

### Project Structure

```
kora_windows/
├── lib/
│   ├── main.dart                    # Application entry point
│   ├── core/                        # Core functionality
│   │   ├── blockchain/              # Blockchain-specific implementations
│   │   │   ├── bitcoin/             # Bitcoin service & wallet
│   │   │   ├── ethereum/            # Ethereum/EVM service
│   │   │   ├── solana/              # Solana service & SPL tokens
│   │   │   └── tron/                # Tron service & TRC-20
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
│   │   │   ├── tx_history_service.dart # Transaction history
│   │   │   ├── storage_service.dart # Secure storage wrapper
│   │   │   └── cache_service.dart   # Caching layer
│   │   ├── repositories/            # Data repositories
│   │   │   ├── wallet_repository.dart
│   │   │   └── price_repository.dart
│   │   ├── state/                   # Riverpod providers
│   │   │   └── providers/
│   │   ├── config/                  # Configuration
│   │   │   └── api_config.dart      # API endpoints & keys
│   │   └── constants/               # Constants
│   │       └── token_catalog.dart   # Token addresses
│   ├── features/                    # Feature modules
│   │   ├── send/                    # Send transactions
│   │   │   ├── send_screen.dart
│   │   │   ├── executors/           # Transaction executors
│   │   │   │   ├── utxo_executor.dart    # BTC/LTC/BCH
│   │   │   │   ├── evm_executor.dart     # ETH/BNB/ETC
│   │   │   │   ├── tron_executor.dart    # TRX
│   │   │   │   └── solana_executor.dart  # SOL
│   │   │   └── services/
│   │   ├── receive/                 # Receive screen (QR codes)
│   │   ├── portfolio/               # Portfolio overview
│   │   ├── settings/                # Settings & preferences
│   │   └── wallet_setup/            # Wallet creation/import
│   └── screens/                     # Additional screens
├── assets/
│   ├── crypto_icons/                # Cryptocurrency icons
│   ├── fonts/                       # SF Pro Display fonts
│   └── Language/                    # Localization files
├── windows/                         # Windows platform code
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

#### 3. **Security First**
- Private keys never leave the device
- Encrypted storage for sensitive data
- Secure memory handling

---

## 💰 Supported Blockchains & Assets

### Native Blockchains (8)

1. **Bitcoin (BTC)** - UTXO-based blockchain
2. **Litecoin (LTC)** - UTXO-based blockchain
3. **Bitcoin Cash (BCH)** - UTXO-based blockchain
4. **Ethereum (ETH)** - EVM-compatible smart contract platform
5. **Binance Smart Chain (BNB)** - EVM-compatible (BSC)
6. **Ethereum Classic (ETC)** - EVM-compatible
7. **Tron (TRX)** - DPoS blockchain with smart contracts
8. **Solana (SOL)** - High-performance blockchain

### Token Standards

- **ERC-20** (Ethereum): USDT, USDC, DAI, and custom tokens
- **BEP-20** (BSC): USDT, USDC, and custom tokens
- **TRC-20** (Tron): USDT, USDC, and custom tokens
- **SPL** (Solana): USDC and other SPL tokens

### Total Supported Assets

**17+ assets** including:
- 8 native coins (BTC, ETH, SOL, BNB, TRX, LTC, BCH, ETC)
- 9+ tokens (USDT on multiple chains, USDC on multiple chains, DAI, etc.)

---

## 🔐 Security Features

### Key Management

- **BIP39 Mnemonic**: 12/24-word recovery phrases
- **BIP32 HD Wallet**: Hierarchical deterministic key derivation
- **Secure Storage**: Encrypted storage using Windows Data Protection API
- **No Cloud Backup**: Keys stored only on local device

### Encryption

- **AES-256 Encryption**: Military-grade encryption for private keys
- **Password Protection**: User-defined password for wallet access
- **Secure Memory**: Sensitive data cleared from memory after use

### Authentication

- **PIN/Password**: Required for transactions
- **Biometric Support**: Windows Hello integration (optional)
- **Auto-Lock**: Automatic wallet locking after inactivity

---

## 🔧 Technical Implementation

### Blockchain Services

#### Bitcoin/UTXO Chains (BTC, LTC, BCH)
```
lib/core/blockchain/bitcoin/
├── bitcoin_service.dart       # UTXO fetching, balance, broadcast
├── bitcoin_wallet.dart        # Address generation (P2PKH, P2WPKH)
├── bitcoin_signer.dart        # Transaction signing
└── bitcoin_transaction.dart   # Transaction building
```

**Features**:
- P2PKH (Legacy) and P2WPKH (SegWit) address support
- UTXO selection and transaction building
- Fee estimation via mempool.space API
- Transaction broadcasting

#### Ethereum/EVM Chains (ETH, BNB, ETC)
```
lib/core/blockchain/ethereum/
├── ethereum_service.dart      # RPC calls, balance, transactions
└── ethereum_wallet.dart       # Address generation, signing
```

**Features**:
- EIP-155 transaction signing
- ERC-20 token support
- Gas estimation and fee calculation
- Contract interaction via web3dart
- Multiple RPC endpoints with fallback

#### Tron (TRX)
```
lib/core/blockchain/tron/
├── tron_service.dart          # TronGrid API integration
├── tron_wallet.dart           # Address generation
└── tron_transaction.dart      # Transaction building
```

**Features**:
- TRC-20 token support
- Energy and bandwidth management
- Transaction signing with Ed25519
- TronGrid API integration

#### Solana (SOL)
```
lib/core/blockchain/solana/
├── solana_service.dart        # RPC calls, balance
├── solana_wallet.dart         # Address generation
└── spl_token.dart             # SPL token utilities
```

**Features**:
- SPL token support
- Ed25519 signature scheme
- Helius RPC integration
- Transaction serialization

### Transaction Execution Flow

```
User initiates send
    ↓
SendScreen (UI validation)
    ↓
Select appropriate executor based on blockchain
    ↓
[UTXO/EVM/Tron/Solana]Executor
    ↓
Build transaction
    ↓
Sign with private key
    ↓
Broadcast to network
    ↓
Monitor confirmation
    ↓
Update balance & history
```

### API Integration

#### Price APIs (with fallback)
1. **Primary**: CoinGecko API (free tier)
2. **Fallback**: CryptoCompare API
3. **Cache**: Persistent local cache

#### RPC Endpoints (with fallback)
- **Ethereum**: Ankr → PublicNode → LlamaRPC
- **BSC**: Binance dataseed1 → dataseed2 → dataseed3
- **Solana**: Helius → Public RPC
- **Bitcoin**: mempool.space → blockstream.info

#### Block Explorers
- **Ethereum**: Etherscan API
- **BSC**: BscScan / Blockscout
- **Bitcoin**: mempool.space / blockchain.info
- **Tron**: TronScan API
- **Solana**: Helius Enhanced Transactions

---

## 🚀 Features

### Wallet Management

- **Create New Wallet**: Generate new 12/24-word mnemonic
- **Import Wallet**: Import existing wallet via mnemonic
- **Multiple Wallets**: Support for multiple wallet instances
- **Backup & Restore**: Secure mnemonic backup

### Asset Management

- **Portfolio View**: Overview of all assets with USD values
- **Real-Time Prices**: Live price updates via WebSocket
- **24h Change**: Price change indicators
- **Balance Tracking**: Automatic balance updates

### Send & Receive

- **Send Transactions**: Send coins and tokens to any address
- **Fee Selection**: Choose between slow/normal/fast fees
- **Address Validation**: Validate recipient addresses
- **QR Code Scanning**: Scan QR codes for addresses
- **QR Code Generation**: Generate QR codes for receiving

### Transaction History

- **Complete History**: All transactions for each blockchain
- **Transaction Details**: View full transaction information
- **Status Tracking**: Pending/confirmed status
- **Block Explorer Links**: Open transactions in block explorers

### Settings & Preferences

- **Theme**: Light/dark mode toggle
- **Language**: Multi-language support
- **Security**: PIN/password settings
- **Network**: Custom RPC endpoints (advanced)

---

## 📊 Data Flow

### Balance Updates
```
User opens wallet
    ↓
BalanceService fetches balances for all assets
    ↓
Parallel API calls to blockchain RPCs
    ↓
CryptoPriceService fetches USD prices
    ↓
Calculate portfolio value
    ↓
Update UI via Riverpod providers
```

### Transaction Broadcasting
```
User enters send details
    ↓
Validate address & amount
    ↓
Fetch current fee estimates
    ↓
User confirms transaction
    ↓
Build & sign transaction
    ↓
Broadcast to blockchain
    ↓
Monitor transaction status
    ↓
Update local transaction history
```

---

## 🛠️ Building & Running

### Prerequisites

- Flutter SDK 3.10.4 or higher
- Windows 10/11 (64-bit)
- Visual Studio 2019+ with C++ tools
- Git

### Setup

```bash
# Clone repository
git clone <repository-url>
cd kora_windows

# Install dependencies
flutter pub get

# Run in debug mode
flutter run -d windows

# Build release
flutter build windows --release
```

### Build Scripts

The project includes PowerShell scripts for automated builds:

```powershell
# Build release version
.\build_release_all.ps1

# Build installer (requires Inno Setup)
.\build_installer.bat
```

### Configuration

API keys are configured in `lib/core/config/api_config.dart`:
- Etherscan API key (for ETH transaction history)
- BscScan API key (for BSC transaction history)
- Helius API key (for Solana RPC)
- CoinGecko API key (optional, for higher rate limits)

---

## 📦 Distribution

### Installer

The project includes Inno Setup scripts for creating Windows installers:
- `installer.iss` - Single application installer
- `installer_combined.iss` - Combined installer for wallet + widget

### Portable Version

The release build can be distributed as a portable application:
- Located in `build/windows/runner/Release/`
- No installation required
- All data stored in user's AppData folder

---

## 🎨 UI/UX

### Design Language

- **SF Pro Display Font**: Apple's system font for clean typography
- **Material Design**: Flutter's Material Design components
- **Custom Widgets**: Tailored components for crypto operations
- **Smooth Animations**: Fade transitions and micro-interactions

### Theme Support

- **Light Theme**: Clean white background with blue accents
- **Dark Theme**: Dark background with reduced eye strain
- **Persistent Preference**: Theme choice saved locally

### Responsive Layout

- Optimized for desktop screen sizes
- Minimum window size: 800x600
- Scalable UI elements

---

## 🔗 Integration with Kora Ecosystem

Kora Wallet (Windows) shares the same codebase foundation with:

- **Kora Wallet (Mobile)**: Android version with mobile-specific features
- **Kora Market (Widget)**: Price tracking widget

**Shared Components**:
- Blockchain service implementations
- Cryptographic utilities
- State management patterns
- Design system and themes

---

## 📝 Version History

**v3.5.0+1** (Current)
- Multi-chain wallet support (8 blockchains)
- Non-custodial HD wallet implementation
- Real-time price tracking
- Transaction history for all chains
- Send/receive functionality
- QR code support
- Light/dark theme
- Secure encrypted storage

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

---

**Kora Wallet** - Your keys, your crypto 🔐

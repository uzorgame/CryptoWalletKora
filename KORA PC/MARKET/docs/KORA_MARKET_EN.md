# KORA MARKET

**Real-time Cryptocurrency Price Tracker Widget for Windows**

Version: 3.5.0+1

---

## 📋 Overview

**Kora Market** is a lightweight, always-on-top Windows desktop widget that provides real-time cryptocurrency price tracking for the top 20 digital assets. Built with Flutter, it offers a sleek, modern interface with live price updates via Binance WebSocket streams.

### Key Features

- **Real-time Price Updates**: Live cryptocurrency prices via Binance WebSocket API
- **Top 20 Assets**: Track Bitcoin, Ethereum, Solana, BNB, Tron, and 15+ other major cryptocurrencies
- **Compact Design**: Fixed 820x420 window optimized for desktop widgets
- **Light/Dark Theme**: Automatic theme switching with smooth transitions
- **Minimal Resource Usage**: Lightweight Flutter application with efficient WebSocket connections
- **Always Accessible**: Stays on top of other windows for quick price checks
- **Beautiful UI**: Modern design with SF Pro Display font and smooth animations

---

## 🏗️ Architecture

### Technology Stack

- **Framework**: Flutter 3.10.4+ (Dart SDK)
- **Platform**: Windows Desktop
- **UI Components**: Material Design with custom widgets
- **Data Source**: Binance WebSocket API (real-time streaming)
- **State Management**: Built-in Flutter state management with Listenable patterns
- **Window Management**: `window_manager` package for custom window controls
- **Charts**: `fl_chart` for price visualization
- **Icons**: SVG icons via `flutter_svg`

### Project Structure

```
kora_windows/widget/
├── lib/
│   ├── main.dart              # Application entry point & splash screen
│   ├── theme.dart             # Theme definitions (light/dark)
│   ├── screens/
│   │   └── market_screen.dart # Main market display screen
│   ├── services/
│   │   └── binance_service.dart # WebSocket connection to Binance API
│   └── widgets/               # Reusable UI components
├── assets/
│   ├── kora_logo.png          # Application logo
│   ├── crypto_icons/          # SVG icons for cryptocurrencies
│   └── fonts/                 # SF Pro Display font family
├── windows/                   # Windows platform-specific code
└── pubspec.yaml               # Dependencies and configuration
```

### Core Components

#### 1. **BinanceService** (`services/binance_service.dart`)
- Manages WebSocket connection to Binance API
- Subscribes to real-time price streams for 20+ trading pairs
- Handles connection lifecycle (connect, reconnect, disconnect)
- Parses and broadcasts price updates to UI

#### 2. **MarketScreen** (`screens/market_screen.dart`)
- Main UI displaying cryptocurrency list
- Real-time price updates with 24h change percentages
- Color-coded price movements (green/red)
- Sortable by price, change, or market cap

#### 3. **ThemeNotifier** (`theme.dart`)
- Manages light/dark theme switching
- Persists theme preference via SharedPreferences
- Provides smooth theme transition animations

#### 4. **SplashScreen** (`main.dart`)
- Animated splash screen with logo and loading indicators
- Smooth fade transition to main market screen
- Displays supported cryptocurrencies in bottom strip

---

## 💰 Supported Cryptocurrencies

Kora Market tracks **20 major cryptocurrencies** with real-time Binance data:

### Native Coins
- **BTC** - Bitcoin
- **ETH** - Ethereum
- **SOL** - Solana
- **BNB** - Binance Coin
- **TRX** - Tron
- **LTC** - Litecoin
- **BCH** - Bitcoin Cash
- **ETC** - Ethereum Classic

### Stablecoins
- **USDT** - Tether
- **USDC** - USD Coin
- **DAI** - Dai

### Additional Assets
- **ADA** - Cardano
- **XRP** - Ripple
- **DOT** - Polkadot
- **MATIC** - Polygon
- **AVAX** - Avalanche
- **LINK** - Chainlink
- **UNI** - Uniswap
- **ATOM** - Cosmos
- And more...

---

## 🔧 Technical Details

### Dependencies

```yaml
dependencies:
  flutter: sdk
  window_manager: ^0.3.8      # Custom window controls
  http: ^1.2.1                # HTTP client
  fl_chart: ^0.69.0           # Chart visualization
  web_socket_channel: ^2.4.5  # WebSocket connections
  shared_preferences: ^2.2.2  # Local storage
  flutter_svg: ^2.0.10        # SVG icon support
```

### Window Configuration

- **Size**: 820x420 pixels (fixed)
- **Title Bar**: Custom hidden title bar with minimize/close buttons
- **Background**: Transparent with custom styling
- **Position**: Centered on screen at launch
- **Taskbar**: Visible in Windows taskbar

### Data Flow

```
Binance API (WebSocket)
    ↓
BinanceService (Connection Manager)
    ↓
Stream<PriceUpdate>
    ↓
MarketScreen (UI)
    ↓
User Display (Real-time prices)
```

### Performance Optimizations

- **Efficient WebSocket**: Single connection for all price streams
- **Minimal Redraws**: Only updates changed price widgets
- **Asset Caching**: Local SVG icons for instant loading
- **Throttled Updates**: Price updates throttled to prevent UI lag

---

## 🚀 Building & Running

### Prerequisites

- Flutter SDK 3.10.4 or higher
- Windows 10/11 development environment
- Visual Studio 2019+ with C++ desktop development tools

### Build Commands

```bash
# Development build
flutter run -d windows

# Release build
flutter build windows --release

# Build with custom name
flutter build windows --release --build-name=3.5.0 --build-number=1
```

### Installation

The widget can be distributed as:
1. **Standalone EXE**: Located in `build/windows/runner/Release/`
2. **Installer Package**: Can be packaged with Inno Setup or similar tools

---

## 🎨 UI/UX Features

### Visual Design

- **Modern Interface**: Clean, minimalist design inspired by iOS/macOS
- **SF Pro Display Font**: Apple's system font for professional appearance
- **Smooth Animations**: Fade transitions, scale effects, and loading indicators
- **Color Coding**: Green (positive) / Red (negative) price changes
- **Ambient Effects**: Subtle glow effects and grid backgrounds

### User Interactions

- **Drag to Move**: Custom title bar allows window dragging
- **Minimize/Close**: macOS-style window control buttons
- **Theme Toggle**: Switch between light and dark themes
- **Hover Effects**: Interactive button states with smooth transitions

---

## 📊 Data Sources

### Primary API: Binance WebSocket

- **Endpoint**: `wss://stream.binance.com:9443/ws`
- **Stream Type**: Individual symbol ticker streams
- **Update Frequency**: Real-time (sub-second updates)
- **Data Format**: JSON with price, volume, and 24h change

### API Features

- **Free Access**: No API key required
- **High Reliability**: 99.9%+ uptime
- **Low Latency**: Direct WebSocket connection
- **Comprehensive Data**: Price, volume, high/low, change percentage

---

## 🔐 Security & Privacy

- **No User Data Collection**: Widget does not collect or store personal information
- **Read-Only Access**: Only reads public market data from Binance
- **Local Storage**: Theme preferences stored locally via SharedPreferences
- **No Network Tracking**: No analytics or telemetry

---

## 🛠️ Configuration

### Customization Options

Users can customize:
- **Theme**: Light or dark mode (persisted)
- **Window Position**: Freely movable on screen
- **Startup Behavior**: Can be added to Windows startup

### Future Enhancements

Potential features for future versions:
- Custom asset selection
- Price alerts and notifications
- Historical price charts
- Multiple fiat currency support
- Portfolio tracking integration

---

## 📝 Version History

**v3.5.0+1** (Current)
- Initial release of Kora Market widget
- Real-time price tracking for 20+ cryptocurrencies
- Light/dark theme support
- Binance WebSocket integration
- Custom Windows window controls

---

## 🤝 Integration with Kora Ecosystem

Kora Market is part of the **KORA** cryptocurrency ecosystem:

- **Kora Wallet (Mobile)**: Non-custodial multi-chain wallet for Android
- **Kora Wallet (Windows)**: Desktop version of the wallet
- **Kora Market (Widget)**: Real-time price tracker (this application)

All three applications share:
- Common design language
- SF Pro Display typography
- Consistent color schemes
- Support for the same cryptocurrencies

---

## 📄 License

Private project - Not published to pub.dev

---

## 🔗 Resources

- **Flutter**: https://flutter.dev
- **Binance API**: https://binance-docs.github.io/apidocs/spot/en/
- **Window Manager**: https://pub.dev/packages/window_manager
- **FL Chart**: https://pub.dev/packages/fl_chart

---

**Kora Market** - Your window to the crypto world 🚀

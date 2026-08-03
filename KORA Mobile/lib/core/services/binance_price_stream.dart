import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:kora/core/repositories/price_repository.dart';

// ── Wallet coins tracked via Binance WebSocket ─────────────────────────────
// Maps CoinGecko ID → Binance trading pair
const _geckoToBinance = <String, String>{
  'bitcoin':           'BTCUSDT',
  'ethereum':          'ETHUSDT',
  'solana':            'SOLUSDT',
  'binancecoin':       'BNBUSDT',
  'tron':              'TRXUSDT',
  'litecoin':          'LTCUSDT',
  'bitcoin-cash':      'BCHUSDT',
  'ethereum-classic':  'ETCUSDT',
};

// Reverse map: Binance symbol → CoinGecko ID
const _binanceToGecko = <String, String>{
  'BTCUSDT':  'bitcoin',
  'ETHUSDT':  'ethereum',
  'SOLUSDT':  'solana',
  'BNBUSDT':  'binancecoin',
  'TRXUSDT':  'tron',
  'LTCUSDT':  'litecoin',
  'BCHUSDT':  'bitcoin-cash',
  'ETCUSDT':  'ethereum-classic',
};

// Stablecoins fixed at $1 — no stream needed
const _stablecoins = <String, String>{
  'tether':   '1.0',
  'usd-coin': '1.0',
};

const _wsBase = 'wss://stream.binance.com:9443/stream?streams=';

// ── BinancePriceStream ─────────────────────────────────────────────────────

/// Real-time price stream from Binance public WebSocket combined ticker.
///
/// - Primary source for live prices in Kora Wallet.
/// - Auto-reconnects on disconnect/error (5 s delay).
/// - Prices are keyed by CoinGecko ID to match existing [PriceRepository] API.
/// - When disconnected, [PriceRepository.getPricesOptimized] falls back to
///   CoinGecko REST → CryptoCompare REST → local cache (existing chain).
class BinancePriceStream {
  BinancePriceStream._();
  static final instance = BinancePriceStream._();

  // ── Internal state ──────────────────────────────────────────────────────

  final Map<String, CryptoPrice> _prices = {};

  /// Latest prices keyed by CoinGecko ID. Empty until first WS message.
  Map<String, CryptoPrice> get latestPrices => Map.unmodifiable(_prices);

  bool _connected = false;

  /// True while WS is open and receiving data.
  bool get isConnected => _connected;

  bool _hasLiveData = false;

  /// True after the first real (non-stablecoin) ticker is received.
  /// Guards against entering the WS fast-path before any live data exists.
  bool get hasLiveData => _hasLiveData;

  bool _active = false;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;

  // ── Public API ──────────────────────────────────────────────────────────

  /// Start the WebSocket stream. Safe to call multiple times.
  void start() {
    if (_active) return;
    _active = true;

    // Pre-fill stablecoins immediately
    final now = DateTime.now();
    for (final entry in _stablecoins.entries) {
      _prices[entry.key] = CryptoPrice(
        coinId: entry.key,
        priceUsd: double.parse(entry.value),
        change24h: 0.0,
        lastUpdated: now,
      );
    }

    _connect();
  }

  /// Stop the stream and release resources.
  void stop() {
    _active = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connected = false;
  }

  // ── WebSocket lifecycle ─────────────────────────────────────────────────

  void _connect() {
    if (!_active) return;

    final streams = _geckoToBinance.values
        .map((pair) => '${pair.toLowerCase()}@ticker')
        .join('/');

    try {
      _channel = WebSocketChannel.connect(Uri.parse('$_wsBase$streams'));
      _sub = _channel!.stream.listen(
        _onMessage,
        onError: (_) => _scheduleReconnect(),
        onDone:  _scheduleReconnect,
        cancelOnError: false,
      );
      _connected = true;
      if (kDebugMode) debugPrint('[BinanceWS] Connected');
    } catch (e) {
      if (kDebugMode) debugPrint('[BinanceWS] Connect error: $e');
      _connected = false;
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final env  = jsonDecode(raw as String) as Map<String, dynamic>;
      final data = env['data'] as Map<String, dynamic>?;
      if (data == null) return;

      final binanceSym = ((data['s'] as String?) ?? '').toUpperCase();
      final geckoId    = _binanceToGecko[binanceSym];
      if (geckoId == null) return;

      final price  = double.tryParse((data['c'] as String?) ?? '') ?? 0.0;
      final change = double.tryParse((data['P'] as String?) ?? '') ?? 0.0;

      _prices[geckoId] = CryptoPrice(
        coinId:      geckoId,
        priceUsd:    price,
        change24h:   change,
        lastUpdated: DateTime.now(),
      );
      if (!_hasLiveData) _hasLiveData = true;
    } catch (_) {}
  }

  void _scheduleReconnect() {
    if (!_active) return;
    _connected = false;
    _hasLiveData = false;
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), _connect);
    if (kDebugMode) debugPrint('[BinanceWS] Disconnected — reconnecting in 5 s…');
  }
}

/// Binance REST klines endpoint helper.
/// Used by [PriceChartService] to fetch historical price data.
class BinanceKlines {
  static const _restBase = 'https://api.binance.com/api/v3/klines';

  /// Returns the Binance trading pair for a given CoinGecko ID,
  /// or null if the coin is not tracked.
  static String? pairForGeckoId(String geckoId) =>
      _geckoToBinance[geckoId];

  /// Build the klines URL for daily candles.
  static String dailyUrl(String pair, {int limit = 365}) =>
      '$_restBase?symbol=$pair&interval=1d&limit=$limit';
}

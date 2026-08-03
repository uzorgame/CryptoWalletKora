import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Live market data for KORA Market.
///
/// The socket runs continuously; the screen commits on a ten-second beat. Holding the newest
/// value and releasing it on a fixed rhythm is what makes a price readable — at one update a
/// second the number is legible as motion but useless as a figure — and it lets the flash on
/// a card mean "this moved over the last ten seconds" instead of "a packet arrived".

// ── Tracked market ────────────────────────────────────────────────────────────

/// Twenty pairs, each verified as TRADING on Binance rather than assumed. The list this
/// replaced carried MATIC, DAI, MKR, EOS, WAVES and OMG, whose USDT pairs are all in BREAK
/// status — six cards that could never update no matter how healthy the connection was.
const List<String> kSymbols = [
  'BTC', 'ETH', 'BNB', 'SOL', 'XRP', 'ADA', 'DOGE', 'AVAX', 'LINK', 'DOT',
  'POL', 'LTC', 'BCH', 'ETC', 'TRX', 'UNI', 'ATOM', 'ALGO', 'USDC', 'FIL',
];

const Map<String, String> kNames = {
  'BTC': 'Bitcoin', 'ETH': 'Ethereum', 'BNB': 'BNB', 'SOL': 'Solana', 'XRP': 'XRP',
  'ADA': 'Cardano', 'DOGE': 'Dogecoin', 'AVAX': 'Avalanche', 'LINK': 'Chainlink',
  'DOT': 'Polkadot', 'POL': 'Polygon', 'LTC': 'Litecoin', 'BCH': 'Bitcoin Cash',
  'ETC': 'Ethereum Classic', 'TRX': 'Tron', 'UNI': 'Uniswap', 'ATOM': 'Cosmos',
  'ALGO': 'Algorand', 'USDC': 'USD Coin', 'FIL': 'Filecoin',
};

/// Binance can price a pair but cannot capitalise a coin: it does not know how many exist.
/// Circulating supply and the all-time high are fetched from CoinGecko and treated as slow
/// constants; every figure built on them is recomputed from the live price on each beat.
const Map<String, String> _geckoIds = {
  'BTC': 'bitcoin', 'ETH': 'ethereum', 'BNB': 'binancecoin', 'SOL': 'solana',
  'XRP': 'ripple', 'ADA': 'cardano', 'DOGE': 'dogecoin', 'AVAX': 'avalanche-2',
  'LINK': 'chainlink', 'DOT': 'polkadot', 'POL': 'polygon-ecosystem-token',
  'LTC': 'litecoin', 'BCH': 'bitcoin-cash', 'ETC': 'ethereum-classic', 'TRX': 'tron',
  'UNI': 'uniswap', 'ATOM': 'cosmos', 'ALGO': 'algorand', 'USDC': 'usd-coin',
  'FIL': 'filecoin',
};

const _wsBase = 'wss://stream.binance.com:9443/stream?streams=';
const _restBase = 'https://api.binance.com/api/v3';
const _geckoBase =
    'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&per_page=250&ids=';

String _pair(String symbol) => '${symbol}USDT';

/// The beat. Everything visible changes on this and only this.
const Duration kBeat = Duration(seconds: 10);

// ── Models ────────────────────────────────────────────────────────────────────

enum FeedStatus { loading, connecting, live, reconnecting, offline }

extension FeedStatusLabel on FeedStatus {
  String get label => switch (this) {
        FeedStatus.loading => 'LOADING',
        FeedStatus.connecting => 'CONNECTING',
        FeedStatus.live => 'LIVE',
        FeedStatus.reconnecting => 'RECONNECTING',
        FeedStatus.offline => 'OFFLINE',
      };
}

/// Mutable by design: the socket writes into this on the hot path, and only the beat reads
/// it. Rebuilding twenty immutable records several hundred times a second would allocate
/// hard for values nobody is going to look at.
class Coin {
  Coin({required this.symbol, required this.rank}) : name = kNames[symbol] ?? symbol;

  final String symbol;
  final String name;
  final int rank;

  double? price;
  double delta = 0;
  double volume = 0;
  double? high;
  double? low;

  double? supply;
  double? ath;

  /// Thirty daily closes. The last one is today, a candle that has not closed yet, so the
  /// beat overwrites it with the live price — the month stays on one time base and still
  /// reaches the current second.
  List<double> history = const [];

  /// What the screen is currently showing, so direction and change describe the interval
  /// the user actually watched rather than the gap between two adjacent messages.
  double? shown;
  bool changed = false;
  bool rising = true;

  double? get marketCap => (supply != null && price != null) ? supply! * price! : null;
  double? get fromAth => (ath != null && ath! > 0 && price != null) ? (price! / ath! - 1) * 100 : null;
}

class Candle {
  const Candle(this.time, this.close);
  final DateTime time;
  final double close;
}

// ── Service ───────────────────────────────────────────────────────────────────

class MarketService extends ChangeNotifier {
  MarketService._();
  static final instance = MarketService._();

  final Map<String, Coin> coins = {
    for (final (i, s) in kSymbols.indexed) s: Coin(symbol: s, rank: i + 1),
  };

  FeedStatus _status = FeedStatus.loading;
  FeedStatus get status => _status;

  /// Increments once per commit. Cards compare it to decide whether a flash is due, which
  /// keeps the decision out of build() where it would fire on every unrelated rebuild.
  int beat = 0;

  int _messages = 0;
  int _rate = 0;
  int get rate => _rate;

  bool _started = false;
  bool _disposed = false;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _beatTimer;
  Timer? _rateTimer;
  Timer? _retryTimer;
  Timer? _supplyTimer;
  int _retries = 0;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _beatTimer = Timer.periodic(kBeat, (_) => commit());
    _rateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _rate = _messages;
      _messages = 0;
    });
    _supplyTimer = Timer.periodic(const Duration(minutes: 15), (_) => _loadSupply());

    await _bootstrap();
    _connect();
    unawaited(_loadSupply());
  }

  @override
  void dispose() {
    _disposed = true;
    _beatTimer?.cancel();
    _rateTimer?.cancel();
    _retryTimer?.cancel();
    _supplyTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  void _setStatus(FeedStatus s) {
    if (_status == s || _disposed) return;
    _status = s;
    notifyListeners();
  }

  // ── The beat ───────────────────────────────────────────────────────────────

  void commit() {
    if (_disposed) return;
    var moved = false;
    for (final coin in coins.values) {
      final price = coin.price;
      if (price == null) continue;
      coin.changed = coin.shown != null && price != coin.shown;
      coin.rising = coin.shown == null || price >= coin.shown!;
      coin.shown = price;
      if (coin.history.isNotEmpty) coin.history[coin.history.length - 1] = price;
      moved = true;
    }
    if (!moved) return;
    beat++;
    notifyListeners();
  }

  // ── First load ─────────────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    _setStatus(FeedStatus.loading);
    final list = jsonEncode(kSymbols.map(_pair).toList());
    try {
      final res = await http
          .get(Uri.parse('$_restBase/ticker/24hr?symbols=${Uri.encodeComponent(list)}'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        for (final row in jsonDecode(res.body) as List<dynamic>) {
          final d = row as Map<String, dynamic>;
          final coin = coins[_strip(d['symbol'] as String? ?? '')];
          if (coin == null) continue;
          coin.price = _num(d['lastPrice']);
          coin.delta = _num(d['priceChangePercent']) ?? 0;
          coin.volume = _num(d['quoteVolume']) ?? 0;
          coin.high = _num(d['highPrice']);
          coin.low = _num(d['lowPrice']);
        }
      }
    } catch (_) {
      _setStatus(FeedStatus.offline);
    }

    // A month of daily closes each. Seen twenty at a time the grid is not a tick display —
    // an hour of noise says nothing across twenty cards, while a month says which way each
    // coin has been going, which is the only question a glance at the grid can answer.
    await Future.wait(kSymbols.map((sym) async {
      final candles = await fetchCandles(sym, interval: '1d', limit: 30);
      if (candles.isNotEmpty) {
        coins[sym]!.history = candles.map((c) => c.close).toList();
      }
    }), eagerError: false);

    commit();
  }

  Future<void> _loadSupply() async {
    try {
      final res = await http
          .get(Uri.parse(_geckoBase + _geckoIds.values.join(',')))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return;
      final byId = {
        for (final r in jsonDecode(res.body) as List<dynamic>)
          (r as Map<String, dynamic>)['id'] as String: r,
      };
      for (final entry in _geckoIds.entries) {
        final row = byId[entry.value];
        final coin = coins[entry.key];
        if (row == null || coin == null) continue;
        coin.supply = _num(row['circulating_supply']);
        coin.ath = _num(row['ath']);
      }
      if (!_disposed) notifyListeners();
    } catch (_) {
      // The stats band degrades to the figures Binance alone can answer.
    }
  }

  // ── Socket ─────────────────────────────────────────────────────────────────

  void _connect() {
    if (_disposed) return;
    _setStatus(_retries > 0 ? FeedStatus.reconnecting : FeedStatus.connecting);

    /*
     * One stream per pair, not two.
     *
     * The prototype also subscribed to @bookTicker, which fires on every change to the top
     * of the book — six hundred messages a second across twenty pairs. That was worth it
     * when the screen repainted continuously. Against a ten-second beat it is six thousand
     * parsed messages per painted frame: @ticker's one-per-second is already ten times
     * faster than the screen can show, at a thirtieth of the CPU.
     */
    final streams = kSymbols.map((s) => '${_pair(s).toLowerCase()}@ticker').join('/');

    try {
      _channel = WebSocketChannel.connect(Uri.parse('$_wsBase$streams'));
      _sub = _channel!.stream.listen(
        _onMessage,
        onError: (_) => _scheduleRetry(),
        onDone: _scheduleRetry,
        cancelOnError: false,
      );
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _onMessage(dynamic raw) {
    _messages++;
    if (_status != FeedStatus.live) {
      _retries = 0;
      _setStatus(FeedStatus.live);
    }
    try {
      final data = (jsonDecode(raw as String) as Map<String, dynamic>)['data']
          as Map<String, dynamic>?;
      if (data == null) return;
      final coin = coins[_strip(data['s'] as String? ?? '')];
      if (coin == null) return;
      // State absorbs everything; only the beat decides when any of it reaches the screen.
      coin.price = _num(data['c']) ?? coin.price;
      coin.delta = _num(data['P']) ?? coin.delta;
      coin.volume = _num(data['q']) ?? coin.volume;
      coin.high = _num(data['h']) ?? coin.high;
      coin.low = _num(data['l']) ?? coin.low;
    } catch (_) {
      // A malformed frame is not worth tearing down a healthy connection over.
    }
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _setStatus(FeedStatus.reconnecting);
    // Back off so an exchange-side outage is not hammered, but recover fast from a blip.
    _retries = (_retries + 1).clamp(1, 5);
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(milliseconds: 1200 * _retries), _connect);
  }

  // ── Candles ────────────────────────────────────────────────────────────────

  Future<List<Candle>> fetchCandles(String symbol,
      {required String interval, required int limit}) async {
    final uri = Uri.parse(
        '$_restBase/klines?symbol=${_pair(symbol)}&interval=$interval&limit=$limit');
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return const [];
      return [
        for (final k in jsonDecode(res.body) as List<dynamic>)
          Candle(
            DateTime.fromMillisecondsSinceEpoch((k as List<dynamic>)[0] as int),
            _num(k[4]) ?? 0,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _strip(String pair) =>
      pair.endsWith('USDT') ? pair.substring(0, pair.length - 4) : pair;

  static double? _num(dynamic v) => switch (v) {
        null => null,
        final num n => n.toDouble(),
        final String s => double.tryParse(s),
        _ => null,
      };
}

// ── Ranges ────────────────────────────────────────────────────────────────────

/// Each range maps to the coarsest candle that still fills the window with detail. Fifteen
/// minutes of one-minute candles is fifteen points and looks like a sketch, so it uses the
/// one-second candle — the shortest Binance publishes.
class ChartRange {
  const ChartRange(this.label, this.interval, this.limit);
  final String label;
  final String interval;
  final int limit;
}

const List<ChartRange> kRanges = [
  ChartRange('15M', '1s', 900),
  ChartRange('1H', '1m', 60),
  ChartRange('24H', '15m', 96),
  ChartRange('7D', '1h', 168),
  ChartRange('30D', '4h', 180),
  ChartRange('1Y', '1d', 365),
];

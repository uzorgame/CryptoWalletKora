import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:async';

/// WebSocket Service for real-time cryptocurrency prices
/// Supports multiple providers: Binance, Coinbase, Kraken
class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<PriceUpdate>? _priceController;
  final WebSocketProvider _provider;
  Timer? _reconnectTimer;
  List<String>? _currentSymbols;
  bool _shouldReconnect = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 5);
  
  WebSocketService({
    WebSocketProvider provider = WebSocketProvider.binance,
  }) : _provider = provider;
  
  /// Connect to WebSocket and subscribe to symbols
  /// [symbols] - List of trading pairs (e.g., ['btcusdt', 'ethusdt'])
  void connect(List<String> symbols) {
    _currentSymbols = symbols;
    _shouldReconnect = true;
    _reconnectAttempts = 0;
    _connect();
  }
  
  void _connect() {
    if (_channel != null) {
      _channel?.sink.close();
      _channel = null;
    }
    
    if (_priceController == null || _priceController!.isClosed) {
      _priceController = StreamController<PriceUpdate>.broadcast();
    }
    
    final url = _buildWebSocketUrl(_currentSymbols!);
    _channel = WebSocketChannel.connect(Uri.parse(url));
    
    // Subscribe to symbols if needed (Coinbase, Kraken)
    if (_provider != WebSocketProvider.binance) {
      _subscribe(_currentSymbols!);
    }
    
    // Listen to messages
    _channel!.stream.listen(
      _handleMessage,
      onError: _handleError,
      onDone: _handleDone,
    );
    
    // Reset reconnect attempts on successful connection
    _reconnectAttempts = 0;
  }
  
  /// Get price updates stream
  Stream<PriceUpdate> get priceUpdates {
    if (_priceController == null) {
      throw WebSocketServiceException('Not connected. Call connect() first.');
    }
    return _priceController!.stream;
  }
  
  /// Disconnect from WebSocket
  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channel?.sink.close();
    _channel = null;
    _priceController?.close();
    _priceController = null;
    _currentSymbols = null;
  }
  
  /// Check if connected
  bool get isConnected => _channel != null;
  
  String _buildWebSocketUrl(List<String> symbols) {
    switch (_provider) {
      case WebSocketProvider.binance:
        return _buildBinanceUrl(symbols);
      case WebSocketProvider.coinbase:
        return 'wss://ws-feed.exchange.coinbase.com';
      case WebSocketProvider.kraken:
        return 'wss://ws.kraken.com';
    }
  }
  
  String _buildBinanceUrl(List<String> symbols) {
    // Binance WebSocket URL format:
    // wss://stream.binance.com:9443/ws/btcusdt@ticker/ethusdt@ticker
    final streams = symbols.map((s) => '${s.toLowerCase()}@ticker').join('/');
    return 'wss://stream.binance.com:9443/ws/$streams';
  }
  
  void _subscribe(List<String> symbols) {
    if (_channel == null) return;
    
    switch (_provider) {
      case WebSocketProvider.coinbase:
        _subscribeCoinbase(symbols);
        break;
      case WebSocketProvider.kraken:
        _subscribeKraken(symbols);
        break;
      case WebSocketProvider.binance:
        // Binance doesn't need subscription message
        break;
    }
  }
  
  void _subscribeCoinbase(List<String> symbols) {
    final message = {
      'type': 'subscribe',
      'product_ids': symbols,
      'channels': ['ticker'],
    };
    _channel!.sink.add(jsonEncode(message));
  }
  
  void _subscribeKraken(List<String> symbols) {
    final message = {
      'event': 'subscribe',
      'pair': symbols,
      'subscription': {'name': 'ticker'},
    };
    _channel!.sink.add(jsonEncode(message));
  }
  
  void _handleMessage(dynamic data) {
    try {
      final json = jsonDecode(data);
      
      PriceUpdate? update;
      switch (_provider) {
        case WebSocketProvider.binance:
          update = _parseBinanceMessage(json);
          break;
        case WebSocketProvider.coinbase:
          update = _parseCoinbaseMessage(json);
          break;
        case WebSocketProvider.kraken:
          update = _parseKrakenMessage(json);
          break;
      }
      
      if (update != null) {
        _priceController?.add(update);
      }
    } catch (e) {
      // Ignore parsing errors
    }
  }
  
  PriceUpdate? _parseBinanceMessage(Map<String, dynamic> json) {
    if (json['e'] != '24hrTicker') return null;
    
    return PriceUpdate(
      symbol: json['s'],
      price: double.parse(json['c']),
      change24h: double.parse(json['p']),
      changePercent24h: double.parse(json['P']),
      volume24h: double.parse(json['v']),
      high24h: double.parse(json['h']),
      low24h: double.parse(json['l']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['E']),
    );
  }
  
  PriceUpdate? _parseCoinbaseMessage(Map<String, dynamic> json) {
    if (json['type'] != 'ticker') return null;
    
    return PriceUpdate(
      symbol: json['product_id'],
      price: double.parse(json['price']),
      volume24h: double.parse(json['volume_24h']),
      timestamp: DateTime.parse(json['time']),
    );
  }
  
  PriceUpdate? _parseKrakenMessage(dynamic json) {
    // Kraken messages are arrays
    if (json is! List || json.length < 4) return null;
    
    final data = json[1];
    if (data is! Map) return null;
    
    return PriceUpdate(
      symbol: json[3],
      price: double.parse(data['c'][0]),
      volume24h: double.parse(data['v'][1]),
      timestamp: DateTime.now(),
    );
  }
  
  void _handleError(error) {
    _priceController?.addError(WebSocketServiceException('WebSocket error: $error'));
    _attemptReconnect();
  }
  
  void _handleDone() {
    _attemptReconnect();
  }
  
  /// Attempt to reconnect with exponential backoff
  void _attemptReconnect() {
    if (!_shouldReconnect || _currentSymbols == null) return;
    
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _priceController?.addError(
        WebSocketServiceException('Max reconnect attempts reached'),
      );
      return;
    }
    
    _reconnectAttempts++;
    final delay = _reconnectDelay * _reconnectAttempts;
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_shouldReconnect && _currentSymbols != null) {
        _connect();
      }
    });
  }
  
  /// Manually trigger reconnect
  void reconnect() {
    if (_currentSymbols != null) {
      _reconnectAttempts = 0;
      _connect();
    }
  }
  
  void dispose() {
    disconnect();
  }
}

/// WebSocket Provider
enum WebSocketProvider {
  binance,
  coinbase,
  kraken,
}

/// Price Update Model
class PriceUpdate {
  final String symbol;
  final double price;
  final double? change24h;
  final double? changePercent24h;
  final double? volume24h;
  final double? high24h;
  final double? low24h;
  final DateTime timestamp;
  
  PriceUpdate({
    required this.symbol,
    required this.price,
    this.change24h,
    this.changePercent24h,
    this.volume24h,
    this.high24h,
    this.low24h,
    required this.timestamp,
  });
  
  @override
  String toString() {
    return 'PriceUpdate($symbol: \$$price, ${changePercent24h?.toStringAsFixed(2)}%)';
  }
}

/// WebSocket Service Exception
class WebSocketServiceException implements Exception {
  final String message;
  WebSocketServiceException(this.message);
  
  @override
  String toString() => 'WebSocketServiceException: $message';
}

/// Popular Trading Pairs
class TradingPairs {
  // Binance format (lowercase, no separator)
  static const String btcUsdt = 'btcusdt';
  static const String ethUsdt = 'ethusdt';
  static const String solUsdt = 'solusdt';
  static const String bnbUsdt = 'bnbusdt';
  static const String adaUsdt = 'adausdt';
  
  // Coinbase format (uppercase, with separator)
  static const String btcUsdCoinbase = 'BTC-USD';
  static const String ethUsdCoinbase = 'ETH-USD';
  static const String solUsdCoinbase = 'SOL-USD';
  
  // Kraken format (uppercase, with separator)
  static const String btcUsdKraken = 'XBT/USD';
  static const String ethUsdKraken = 'ETH/USD';
  static const String solUsdKraken = 'SOL/USD';
}

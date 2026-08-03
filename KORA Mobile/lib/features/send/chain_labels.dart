// What a chain is called on screen, and what its fee is paid in.

String feeSymbol(String blockchain) => const {
  'bitcoin': 'BTC', 'ethereum': 'ETH', 'bsc': 'BNB',
  'ethereum_classic': 'ETC', 'solana': 'SOL', 'tron': 'TRX',
  'litecoin': 'LTC', 'bitcoin_cash': 'BCH',
}[blockchain] ?? '';

String netLabel(String b) => const {
  'ethereum': 'Ethereum',    'bsc': 'BNB Smart Chain',
  'tron': 'Tron',
  'solana': 'Solana',        'bitcoin': 'Bitcoin',     'dogecoin': 'Dogecoin',
  'litecoin': 'Litecoin',
}[b] ?? b;

// The chains an address can be filed under, and what each is called on screen.
//
// Every chain the wallet can sign for is here. The list used to stop at six, which meant a
// Bitcoin Cash or Ethereum Classic address simply could not be filed — and an address book
// that quietly cannot hold an address is worse than no address book.

const chains = [
  'bitcoin',
  'ethereum',
  'tron',
  'solana',
  'bsc',
  'litecoin',
  'bitcoin_cash',
  'ethereum_classic',
];

String chainLabel(String b) => const {
  'bitcoin': 'Bitcoin',
  'ethereum': 'Ethereum',
  'tron': 'Tron',
  'solana': 'Solana',
  'bsc': 'BNB Smart Chain',
  'litecoin': 'Litecoin',
  'bitcoin_cash': 'Bitcoin Cash',
  'ethereum_classic': 'Ethereum Classic',
}[b] ?? b;

/// The ticker each chain's own coin trades under, so a network is recognisable by either
/// its name or the symbol the user actually holds.
String chainSymbol(String b) => const {
  'bitcoin': 'BTC',
  'ethereum': 'ETH',
  'tron': 'TRX',
  'solana': 'SOL',
  'bsc': 'BNB',
  'litecoin': 'LTC',
  'bitcoin_cash': 'BCH',
  'ethereum_classic': 'ETC',
}[b] ?? b.toUpperCase();

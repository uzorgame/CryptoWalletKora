// The chains an address can be filed under, and what each is called on screen.

const chains = [
  'ethereum', 'bsc',
  'tron', 'solana', 'bitcoin', 'litecoin',
];

String chainLabel(String b) => const {
  'ethereum': 'Ethereum',   'bsc': 'BNB Chain',
  'tron': 'Tron',           'solana': 'Solana',    'bitcoin': 'Bitcoin',
  'litecoin': 'Litecoin',
}[b] ?? b;

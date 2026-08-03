/**
 * Measures what Binance actually pushes, rather than trusting the documentation.
 *
 * The question is not "does a fast stream exist" but "does every coin the widget tracks
 * update at that rate", because a timeframe that refreshes only the liquid pairs would
 * show a frozen grid for the rest.
 */

const COINS = [
  'BTC', 'ETH', 'BNB', 'SOL', 'XRP', 'ADA', 'DOGE', 'AVAX', 'LINK', 'DOT',
  'MATIC', 'LTC', 'BCH', 'ETC', 'TRX', 'UNI', 'ATOM', 'ALGO',
]
const PAIRS = COINS.map((c) => `${c.toLowerCase()}usdt`)
const SECONDS = 20

function measure(label, streams, extract) {
  return new Promise((resolve) => {
    const url = `wss://stream.binance.com:9443/stream?streams=${streams}`
    const ws = new WebSocket(url)
    const perSymbol = new Map()
    const arrivals = []
    let messages = 0
    const started = Date.now()

    const timer = setTimeout(() => {
      try { ws.close() } catch {}
    }, SECONDS * 1000)

    ws.onmessage = (event) => {
      messages++
      arrivals.push(Date.now())
      for (const sym of extract(JSON.parse(event.data))) {
        perSymbol.set(sym, (perSymbol.get(sym) ?? 0) + 1)
      }
    }

    ws.onerror = () => {}

    ws.onclose = () => {
      clearTimeout(timer)
      const elapsed = (Date.now() - started) / 1000
      const gaps = arrivals.slice(1).map((t, i) => t - arrivals[i]).sort((a, b) => a - b)
      const median = gaps.length ? gaps[Math.floor(gaps.length / 2)] : null
      const counts = COINS.map((c) => perSymbol.get(`${c}USDT`) ?? 0)
      resolve({
        label,
        elapsed: elapsed.toFixed(1),
        messages,
        msgPerSecond: (messages / elapsed).toFixed(1),
        medianGapMs: median,
        coinsSeen: counts.filter((n) => n > 0).length + '/' + COINS.length,
        updatesPerCoin: {
          min: Math.min(...counts),
          median: counts.slice().sort((a, b) => a - b)[Math.floor(counts.length / 2)],
          max: Math.max(...counts),
        },
        perCoinPerSecond: (counts.reduce((a, b) => a + b, 0) / counts.length / elapsed).toFixed(2),
      })
    }
  })
}

const tests = [
  {
    label: '@ticker (what the widget uses now)',
    streams: PAIRS.map((p) => `${p}@ticker`).join('/'),
    extract: (m) => (m.data?.s ? [m.data.s] : []),
  },
  {
    label: '@miniTicker',
    streams: PAIRS.map((p) => `${p}@miniTicker`).join('/'),
    extract: (m) => (m.data?.s ? [m.data.s] : []),
  },
  {
    label: '@kline_1s',
    streams: PAIRS.map((p) => `${p}@kline_1s`).join('/'),
    extract: (m) => (m.data?.s ? [m.data.s] : []),
  },
  {
    label: '@bookTicker (per book change, no fixed interval)',
    streams: PAIRS.map((p) => `${p}@bookTicker`).join('/'),
    extract: (m) => (m.data?.s ? [m.data.s] : []),
  },
]

for (const test of tests) {
  const result = await measure(test.label, test.streams, test.extract)
  console.log(`\n${result.label}`)
  console.log(`  ${result.messages} messages in ${result.elapsed}s  (${result.msgPerSecond}/s)`)
  console.log(`  median gap between messages: ${result.medianGapMs} ms`)
  console.log(`  coins that produced data: ${result.coinsSeen}`)
  console.log(`  updates per coin — min ${result.updatesPerCoin.min}, median ${result.updatesPerCoin.median}, max ${result.updatesPerCoin.max}`)
  console.log(`  average updates per coin per second: ${result.perCoinPerSecond}`)
}

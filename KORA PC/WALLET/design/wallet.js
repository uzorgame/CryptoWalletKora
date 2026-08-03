/**
 * KORA Wallet — interaction prototype.
 *
 * Prices and price history are real, from Binance. Balances, addresses and transactions come
 * from the ledgers below: a prototype has no business near a key store. The point of a ledger
 * is that everything derives from it — holdings, per-coin history, the portfolio curve and the
 * cost basis are one consistent story rather than four invented ones.
 */

const MARK = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect x="17" y="16" width="7" height="32"/>
  <path d="M28 32 L45 16 L45 25 L37 32 L45 39 L45 48 Z"/></svg>`
document.documentElement.style.setProperty(
  '--mark-url',
  `url("data:image/svg+xml;utf8,${encodeURIComponent(MARK)}")`,
)

// ── Supported assets ───────────────────────────────────────────────────────────
/** Every pair here was checked as TRADING on Binance; a coin that cannot be priced has no
 *  business in a catalogue the user picks from. */
const CATALOGUE = {
  BTC: { chain: 'BTC', network: 'Bitcoin', name: 'Bitcoin' },
  ETH: { chain: 'ERC20', network: 'Ethereum', name: 'Ethereum' },
  BNB: { chain: 'BEP20', network: 'BNB Smart Chain', name: 'BNB' },
  SOL: { chain: 'SOL', network: 'Solana', name: 'Solana' },
  XRP: { chain: 'XRP', network: 'XRP Ledger', name: 'XRP' },
  ADA: { chain: 'ADA', network: 'Cardano', name: 'Cardano' },
  DOGE: { chain: 'DOGE', network: 'Dogecoin', name: 'Dogecoin' },
  AVAX: { chain: 'AVAX', network: 'Avalanche C-Chain', name: 'Avalanche' },
  LINK: { chain: 'ERC20', network: 'Ethereum', name: 'Chainlink' },
  DOT: { chain: 'DOT', network: 'Polkadot', name: 'Polkadot' },
  POL: { chain: 'POL', network: 'Polygon', name: 'Polygon' },
  LTC: { chain: 'LTC', network: 'Litecoin', name: 'Litecoin' },
  BCH: { chain: 'BCH', network: 'Bitcoin Cash', name: 'Bitcoin Cash' },
  ETC: { chain: 'ETC', network: 'Ethereum Classic', name: 'Ethereum Classic' },
  TRX: { chain: 'TRC20', network: 'Tron', name: 'Tron' },
  UNI: { chain: 'ERC20', network: 'Ethereum', name: 'Uniswap' },
  ATOM: { chain: 'ATOM', network: 'Cosmos', name: 'Cosmos' },
  ALGO: { chain: 'ALGO', network: 'Algorand', name: 'Algorand' },
  USDC: { chain: 'ERC20', network: 'Ethereum', name: 'USD Coin' },
  FIL: { chain: 'FIL', network: 'Filecoin', name: 'Filecoin' },
}

const ADDRESSES = {
  BTC: 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
  ERC20: '0x7A16fF8270133F063aAb6C9977183D9e72835428',
  BEP20: '0x2170Ed0880ac9A755fd29B2688956BD959F933F8',
  SOL: '7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2',
  XRP: 'rEb8TK3gBgk5auZkwc6sHnwrGVJH8DuaLh',
  ADA: 'addr1qxck2v9dxsvsm4qhqfeqf4wrq5rlxmyc8mjy8shyx8xj7q',
  DOGE: 'DH5yaieqoZN36fDVciNyRueRGvGLR3mr7L',
  AVAX: '0x8ae8be25c23833e0a01aa200403e826f611f9cd2',
  DOT: '15oF4uVJwmo4TdGW7VfQxNLavjCXviqxT9S1MgbjMNHr6Sp5',
  POL: '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270',
  LTC: 'ltc1qd4x0trh8s0k6fkqmnvgphdrfhs0mvvv6vkfg8k',
  BCH: 'qr95sy3j9xwd2ap32xkykttr4cvcu7as4y0qverfuy',
  ETC: '0x3f5CE5FBFe3E9af3971dD833D26bA9b5C936f0bE',
  TRC20: 'TQrY8tryqsYVnoTDsHqjkUgHi9zRjJmDDf',
  ATOM: 'cosmos1clpqr4nrk4khgkxj78fcwwh6dl3uw4epsluffn',
  ALGO: 'RENDEZVOUS7KQVDGVXKPSJRLIHRMYRHCKQCEJVJK4YQMBMU5NGSTJQ',
  FIL: 'f1zrkbmvkfydfdgmrgqtnrvhbqzmxgnj4ycsvo6qi',
}

// ── Wallets ────────────────────────────────────────────────────────────────────
/**
 * KORA holds several wallets behind one app. The passphrase is the app's, not a wallet's —
 * unlocking KORA unlocks every wallet in it, which is why the PIN lives in Settings and not
 * in this switcher.
 */
const WALLETS = [
  {
    id: 'main',
    name: 'MAIN',
    tracked: ['BTC', 'ETH', 'SOL', 'TRX', 'USDC', 'LTC', 'BNB'],
    ledger: [
      { sym: 'BTC', date: '2025-11-04', qty: 0.3, peer: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh' },
      { sym: 'ETH', date: '2025-11-04', qty: 4, peer: '0x3f5CE5FBFe3E9af3971dD833D26bA9b5C936f0bE' },
      { sym: 'USDC', date: '2025-12-01', qty: 5000, peer: '0x9f8Ce1ff2a7B6C0d43e12aA97B5B4b0f5a1D2c31' },
      { sym: 'SOL', date: '2025-12-19', qty: 120, peer: '5Q544fKrFoe6tsEbD7S8EmZ5r8Gy2vB1xTfa9WqQm3nH' },
      { sym: 'TRX', date: '2026-01-08', qty: 15000, peer: 'TJRabPrwbZy45sbavfcjinPJC6WFhVYcHY' },
      { sym: 'LTC', date: '2026-01-27', qty: 14, peer: 'ltc1q9d4ywgfnd8h43da5tpcxcn6ajv590cg6d3tg6a' },
      { sym: 'USDC', date: '2026-02-14', qty: -1750, peer: '0x28C6c06298d514Db089934071355E5743bf21d60' },
      { sym: 'BTC', date: '2026-02-18', qty: 0.15, peer: 'bc1q9d4ywgfnd8h43da5tpcxcn6ajv590cg6d3tg6a' },
      { sym: 'BNB', date: '2026-03-05', qty: 3.4, peer: '0x28C6c06298d514Db089934071355E5743bf21d60' },
      { sym: 'ETH', date: '2026-04-11', qty: 2.512, peer: '0x3f5CE5FBFe3E9af3971dD833D26bA9b5C936f0bE' },
      { sym: 'TRX', date: '2026-05-22', qty: -2520, peer: 'TQrY8tryqsYVnoTDsHqjkUgHi9zRjJmDDf' },
      { sym: 'LTC', date: '2026-06-09', qty: -2.6, peer: 'ltc1qd4x0trh8s0k6fkqmnvgphdrfhs0mvvv6vkfg8k' },
      { sym: 'SOL', date: '2026-07-02', qty: 28.2, peer: '5Q544fKrFoe6tsEbD7S8EmZ5r8Gy2vB1xTfa9WqQm3nH' },
      { sym: 'BNB', date: '2026-07-24', qty: -0.34, peer: '0x28C6c06298d514Db089934071355E5743bf21d60' },
      { sym: 'BTC', date: '2026-07-31', qty: -0.0282, peer: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh' },
    ],
  },
  {
    id: 'savings',
    name: 'SAVINGS',
    tracked: ['BTC', 'USDC'],
    ledger: [
      { sym: 'BTC', date: '2026-01-15', qty: 0.62, peer: 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq' },
      { sym: 'USDC', date: '2026-03-20', qty: 8200, peer: '0x7A16fF8270133F063aAb6C9977183D9e72835428' },
      { sym: 'BTC', date: '2026-06-01', qty: 0.11, peer: 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq' },
    ],
  },
  {
    id: 'trading',
    name: 'TRADING',
    tracked: ['SOL', 'DOGE', 'LINK'],
    ledger: [
      { sym: 'SOL', date: '2026-04-02', qty: 42, peer: '5Q544fKrFoe6tsEbD7S8EmZ5r8Gy2vB1xTfa9WqQm3nH' },
      { sym: 'DOGE', date: '2026-05-11', qty: 24000, peer: 'DH5yaieqoZN36fDVciNyRueRGvGLR3mr7L' },
      { sym: 'LINK', date: '2026-06-28', qty: 180, peer: '0x7A16fF8270133F063aAb6C9977183D9e72835428' },
      { sym: 'DOGE', date: '2026-07-19', qty: -6000, peer: '0x28C6c06298d514Db089934071355E5743bf21d60' },
    ],
  },
]

for (const w of WALLETS) {
  for (const e of w.ledger) e.ts = Date.parse(`${e.date}T00:00:00Z`)
  w.ledger.sort((a, b) => a.ts - b.ts)
}

let activeWallet = 0
const wallet = () => WALLETS[activeWallet]
const ledger = () => wallet().ledger
const fundedAt = () => ledger()[0]?.ts ?? Date.now()

/** Everything any wallet has ever touched — the set worth fetching history for. */
const HISTORIC = [...new Set(WALLETS.flatMap((w) => w.ledger.map((e) => e.sym)))]

const coins = new Map(
  Object.entries(CATALOGUE).map(([sym, meta]) => [sym, { sym, ...meta, price: null, delta: 0 }]),
)

const REST = 'https://api.binance.com/api/v3'
const WS = 'wss://stream.binance.com:9443/stream?streams='
const BEAT_MS = 10_000
const pair = (s) => `${s}USDT`

// ── Formatting ─────────────────────────────────────────────────────────────────
const CURRENCIES = {
  USD: { code: 'USD', symbol: '$', rate: 1 },
  EUR: { code: 'EUR', symbol: '€', rate: 0.92 },
  GBP: { code: 'GBP', symbol: '£', rate: 0.79 },
  CAD: { code: 'CAD', symbol: 'C$', rate: 1.37 },
  UAH: { code: 'UAH', symbol: '₴', rate: 41.5 },
}
let currency = 'USD'

/* Zero has no magnitude to scale precision by. Falling through to six decimals printed a
   fresh wallet's balance as "$0.000000", which reads as a number that failed to load. */
const places = (v) => (v === 0 ? 2 : v >= 1 ? 2 : v >= 0.01 ? 4 : 6)
function money(v) {
  if (v == null || !isFinite(v)) return '—'
  const c = CURRENCIES[currency]
  const value = Math.abs(v) * c.rate
  const p = places(value)
  return c.symbol + value.toLocaleString('en-US', { minimumFractionDigits: p, maximumFractionDigits: p })
}
const pct = (v) => (v == null || !isFinite(v) ? '—' : (v >= 0 ? '+' : '') + v.toFixed(2) + '%')
const qtyText = (v) =>
  Math.abs(v).toLocaleString('en-US', { maximumFractionDigits: Math.abs(v) >= 1000 ? 0 : 4 })
const short = (a) => `${a.slice(0, 7)}…${a.slice(-5)}`

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
function dayText(ms) {
  const d = new Date(ms)
  return `${String(d.getUTCDate()).padStart(2, '0')} ${MONTHS[d.getUTCMonth()]} ${d.getUTCFullYear()}`
}
function agoText(ms) {
  const mins = Math.round((Date.now() - ms) / 60000)
  if (mins < 60) return `${mins} min ago`
  const hours = Math.round(mins / 60)
  if (hours < 24) return `${hours} h ago`
  const days = Math.round(hours / 24)
  if (days === 1) return 'Yesterday'
  if (days < 30) return `${days} days ago`
  return dayText(ms)
}

// ── Holdings ───────────────────────────────────────────────────────────────────
function qtyAt(sym, ms) {
  let q = 0
  for (const e of ledger()) {
    if (e.sym !== sym) continue
    if (e.ts > ms) break
    q += e.qty
  }
  return q
}
const held = (sym) => qtyAt(sym, Date.now())

function walletValue(index) {
  const keep = activeWallet
  activeWallet = index
  let sum = 0
  for (const sym of new Set(WALLETS[index].ledger.map((e) => e.sym))) {
    const c = coins.get(sym)
    if (c?.price != null) sum += c.price * held(sym)
  }
  activeWallet = keep
  return sum
}

// ── Price history ──────────────────────────────────────────────────────────────
const daily = new Map()
const hourly = new Map()

async function fetchSeries(sym, interval, limit) {
  try {
    const res = await fetch(`${REST}/klines?symbol=${pair(sym)}&interval=${interval}&limit=${limit}`)
    const rows = await res.json()
    return Array.isArray(rows) ? rows.map((r) => ({ t: r[0], c: Number(r[4]) })) : []
  } catch {
    return []
  }
}

async function loadHistory() {
  const earliest = Math.min(...WALLETS.map((w) => w.ledger[0]?.ts ?? Date.now()))
  const days = Math.ceil((Date.now() - earliest) / 86400000) + 2
  await Promise.all(
    HISTORIC.flatMap((sym) => [
      fetchSeries(sym, '1d', Math.min(days, 1000)).then((s) => daily.set(sym, s)),
      fetchSeries(sym, '1h', 168).then((s) => hourly.set(sym, s)),
    ]),
  )
}

function closeAt(sym, ms) {
  const series = daily.get(sym) ?? []
  let value = null
  for (const point of series) {
    if (point.t > ms) break
    value = point.c
  }
  return value ?? series[0]?.c ?? null
}

/**
 * The portfolio curve.
 *
 * Every point is the wallet as it actually stood that day: the quantity the ledger says was
 * held then, at that day's close. A deposit steps the line up because the wallet really did
 * gain value; before the first deposit the line does not exist, because an empty wallet is not
 * a data point about a wallet's performance.
 */
function portfolioSeries(source) {
  const symbols = [...new Set(ledger().map((e) => e.sym))]
  let axis = []
  for (const sym of symbols) {
    const s = source.get(sym) ?? []
    if (s.length > axis.length) axis = s
  }
  if (!axis.length) return []

  const cursors = new Map(symbols.map((s) => [s, 0]))
  const lastClose = new Map()
  const from = fundedAt()

  const curve = axis
    .filter((point) => point.t >= from - 86400000)
    .map((point) => {
      let total = 0
      for (const sym of symbols) {
        const s = source.get(sym) ?? []
        let i = cursors.get(sym)
        while (i < s.length && s[i].t <= point.t) {
          lastClose.set(sym, s[i].c)
          i++
        }
        cursors.set(sym, i)
        const price = lastClose.get(sym) ?? s[0]?.c
        if (price == null) continue
        total += qtyAt(sym, point.t) * price
      }
      return { t: point.t, v: total }
    })

  const start = curve.findIndex((p) => p.v > 0)
  return start < 0 ? [] : curve.slice(start)
}

let dailyCurve = []
let hourlyCurve = []
function rebuildCurves() {
  dailyCurve = portfolioSeries(daily)
  hourlyCurve = portfolioSeries(hourly)
}

const RANGES = {
  '24H': () => hourlyCurve.slice(-24),
  '7D': () => hourlyCurve,
  '30D': () => dailyCurve.slice(-30),
  '1Y': () => dailyCurve.slice(-365),
  ALL: () => dailyCurve,
}
let range = 'ALL'

function totalValue() {
  let sum = 0
  for (const sym of wallet().tracked) {
    const c = coins.get(sym)
    if (c?.price != null) sum += c.price * held(sym)
  }
  return sum
}
function totalDelta() {
  let now = 0
  let then = 0
  for (const sym of wallet().tracked) {
    const c = coins.get(sym)
    if (c?.price == null) continue
    const value = c.price * held(sym)
    now += value
    then += value / (1 + c.delta / 100)
  }
  return then === 0 ? 0 : (now / then - 1) * 100
}

function costBasis(sym) {
  let spent = 0
  let units = 0
  for (const e of ledger()) {
    if (e.sym !== sym || e.qty <= 0) continue
    const price = closeAt(sym, e.ts)
    if (price == null) continue
    spent += price * e.qty
    units += e.qty
  }
  return units === 0 ? null : spent / units
}

// ── Chart ──────────────────────────────────────────────────────────────────────
function linePath(points, w, h, pad = 8) {
  let min = Infinity
  let max = -Infinity
  for (const p of points) {
    if (p.v < min) min = p.v
    if (p.v > max) max = p.v
  }
  const span = max - min || 1
  const step = w / (points.length - 1)
  const inner = h - pad * 2
  const d = points
    .map((p, i) => `${i ? 'L' : 'M'}${(i * step).toFixed(1)} ${(pad + inner - ((p.v - min) / span) * inner).toFixed(1)}`)
    .join('')
  return { d, min, max }
}

function chartBlock(points, height = 172) {
  if (points.length < 2) return `<div class="chart"><div class="chart-empty">NO HISTORY</div></div>`
  const w = 1000
  const { d, min, max } = linePath(points, w, height)
  const rising = points[points.length - 1].v >= points[0].v
  const stroke = rising ? 'var(--up)' : 'var(--down)'
  return `<div class="chart">
    <svg viewBox="0 0 ${w} ${height}" width="100%" height="${height}" preserveAspectRatio="none" fill="none">
      <defs><linearGradient id="wfade" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="${stroke}" stop-opacity=".16"/>
        <stop offset="1" stop-color="${stroke}" stop-opacity="0"/>
      </linearGradient></defs>
      ${[0.33, 0.66].map((f) => `<line x1="0" y1="${(height * f).toFixed(0)}" x2="${w}" y2="${(height * f).toFixed(0)}" stroke="var(--border)"/>`).join('')}
      <path d="${d}L${w} ${height}L0 ${height}Z" fill="url(#wfade)"
            style="opacity:0;animation:fadeIn .7s .25s var(--ease) forwards"/>
      <path d="${d}" stroke="${stroke}" stroke-width="1.6" stroke-linejoin="round"
            pathLength="1" style="stroke-dasharray:1;stroke-dashoffset:1;animation:draw 1s var(--ease) forwards"/>
    </svg>
    <div class="chart-scale"><span>${money(max)}</span><span>${money(min)}</span></div>
    <div class="chart-since">${dayText(points[0].t)} → ${dayText(points[points.length - 1].t)}</div>
  </div>`
}

// ── Views ──────────────────────────────────────────────────────────────────────
const views = Object.fromEntries(
  ['portfolio', 'coin', 'send', 'history', 'settings'].map((v) => [v, document.querySelector(`#view-${v}`)]),
)

let selected = 'BTC'
let feeTier = 'standard'

/** Held first, then anything the user is only watching. */
function trackedSorted() {
  return wallet().tracked
    .map((sym) => coins.get(sym))
    .filter(Boolean)
    .sort((a, b) => {
      const va = (a.price ?? 0) * held(a.sym)
      const vb = (b.price ?? 0) * held(b.sym)
      if ((va > 0) !== (vb > 0)) return vb > 0 ? 1 : -1
      return vb - va
    })
}

function renderPortfolio() {
  const total = totalValue()
  const delta = totalDelta()
  const points = RANGES[range]()
  const change = points.length > 1 ? (points[points.length - 1].v / points[0].v - 1) * 100 : null
  const rows = trackedSorted()
  const empty = ledger().length === 0

  views.portfolio.innerHTML = `
    <div class="page">
      <div class="head">
        <div>
          <div class="head-label">${wallet().name} · TOTAL BALANCE</div>
          <div class="head-total" data-total>${money(total)}</div>
        </div>
        <div class="head-delta ${delta >= 0 ? 'up' : 'down'}" data-total-delta>${pct(delta)} · 24H</div>
      </div>

      ${empty ? `
        <!-- A wallet with no history gets a reason, not an empty frame and a dash. -->
        <div class="chart"><div class="chart-empty blank">
          <b>NOTHING HERE YET</b>
          <span>This wallet has no transactions. Receive to any of its addresses and the balance and its history start from there.</span>
          <button class="submit" data-receive="${rows[0]?.sym ?? 'BTC'}">RECEIVE ${rows[0]?.sym ?? 'BTC'}</button>
        </div></div>`
      : `
        ${chartBlock(points)}
        <div style="display:flex;align-items:center;gap:16px">
          <div class="ranges">
            ${Object.keys(RANGES).map((r) => `<button data-range="${r}" class="${r === range ? 'on' : ''}">${r}</button>`).join('')}
          </div>
          <span class="head-delta ${change >= 0 ? 'up' : 'down'}" style="padding:0">${pct(change)} over ${range === 'ALL' ? 'the whole history' : range}</span>
        </div>`}

      <div class="sec">
        <h2>ASSETS</h2><span class="rule"></span>
        <!-- Sending and receiving live on a coin, not on a portfolio: there is no answer to
             "send what?" until one is chosen. -->
        <button class="add-btn" data-act="add-token">+ ADD TOKEN</button>
      </div>

      <div class="assets">
        <div class="assets-head">
          <span>NETWORK</span><span>ASSET</span><span>HOLDINGS</span>
          <span class="num">PRICE</span><span class="num">VALUE</span><span class="num">24H</span>
        </div>
        ${rows.map((c, i) => {
          const q = held(c.sym)
          return `
          <div class="asset-row ${q > 0 ? '' : 'zero'}" data-sym="${c.sym}" style="--d:${i * 20}ms" title="Open ${c.sym}">
            <span class="chain-tag">${c.chain}</span>
            <span class="asset-id"><span class="sym">${c.sym}</span><span class="name">${c.name}</span></span>
            <span class="asset-qty">${qtyText(q)} ${c.sym}</span>
            <span class="asset-price num" data-price>${money(c.price)}</span>
            <span class="asset-value num" data-value>${c.price == null ? '—' : money(c.price * q)}</span>
            <span class="asset-delta num ${c.delta >= 0 ? 'up' : 'down'}" data-delta>${pct(c.delta)}</span>
          </div>`
        }).join('')}
      </div>
    </div>`
}

function txRows(sym) {
  const list = ledger().filter((e) => !sym || e.sym === sym).slice().reverse()
  if (!list.length) return `<div class="empty">NO TRANSACTIONS</div>`
  return list.map((e, i) => {
    const incoming = e.qty > 0
    const pending = i === 0 && Date.now() - e.ts < 3 * 86400000
    return `
      <div class="tx-row" style="--d:${i * 18}ms" data-filter="${sym ?? ''}" title="Open transaction">
        <span class="tx-kind ${incoming ? 'in' : 'out'}">${incoming ? 'RECEIVED' : 'SENT'}</span>
        <span class="tx-addr">${short(e.peer)}</span>
        <span class="tx-amt">${incoming ? '+' : '−'}${qtyText(e.qty)} ${e.sym}</span>
        <span class="tx-when">${agoText(e.ts)}</span>
        <span class="tx-state ${pending ? 'pending' : ''}">${pending ? 'PENDING' : 'CONFIRMED'}</span>
      </div>`
  }).join('')
}

function renderCoin() {
  const c = coins.get(selected)
  const q = held(c.sym)
  const value = c.price == null ? null : c.price * q
  const avg = costBasis(c.sym)
  const pl = avg == null || c.price == null ? null : (c.price / avg - 1) * 100
  const first = ledger().find((e) => e.sym === c.sym)

  views.coin.innerHTML = `
    <div class="page">
      <button class="back" data-go="portfolio"><span class="arrow"></span>PORTFOLIO</button>

      <div class="head">
        <div>
          <div class="head-label">${c.sym} · ${c.network}</div>
          <div class="head-total" data-coin-value>${money(value)}</div>
        </div>
        <div class="head-sub" data-coin-qty>${qtyText(q)} ${c.sym}</div>
        <div class="head-delta ${c.delta >= 0 ? 'up' : 'down'}">${pct(c.delta)} · 24H</div>
        <div class="actions">
          <button class="primary" data-send="${c.sym}" ${q > 0 ? '' : 'disabled'}>SEND</button>
          <button data-receive="${c.sym}">RECEIVE</button>
        </div>
      </div>

      <div class="facts">
        <div class="fact"><span class="fact-k">HOLDINGS</span><span class="fact-v">${qtyText(q)}</span></div>
        <div class="fact"><span class="fact-k">PRICE</span><span class="fact-v" data-coin-price>${money(c.price)}</span></div>
        <div class="fact"><span class="fact-k">AVERAGE COST</span><span class="fact-v">${money(avg)}</span></div>
        <div class="fact">
          <span class="fact-k">PROFIT / LOSS</span>
          <span class="fact-v ${pl >= 0 ? 'up' : 'down'}">${pct(pl)}</span>
        </div>
      </div>

      <div class="sec">
        <h2>${c.sym} TRANSACTIONS</h2><span class="rule"></span>
        <span class="aside">${first ? `FIRST ${dayText(first.ts)}` : ''}</span>
      </div>
      <div class="tx">
        <div class="tx-head">
          <span>TYPE</span><span>COUNTERPARTY</span><span style="text-align:right">AMOUNT</span>
          <span style="text-align:right">WHEN</span><span style="justify-self:end">STATUS</span>
        </div>
        ${txRows(c.sym)}
      </div>
    </div>`
}

function renderSend() {
  const order = trackedSorted()
  if (held(selected) <= 0 && order.some((c) => held(c.sym) > 0)) {
    selected = order.find((c) => held(c.sym) > 0).sym
  }
  const c = coins.get(selected)
  const q = held(c.sym)

  views.send.innerHTML = `
    <div class="page">
      <div class="sec"><h2>SEND</h2><span class="rule"></span></div>

      <div class="form">
        <div class="field">
          <label>ASSET</label>
          <!-- Ordered by what is actually spendable: a list that opens on an empty coin asks
               the user to notice the balance before the name. -->
          <div class="ranges">
            ${order.map((x) => `<button data-pick="${x.sym}" class="${x.sym === selected ? 'on' : ''}" ${held(x.sym) > 0 ? '' : 'disabled style="opacity:.4"'}>${x.sym}</button>`).join('')}
          </div>
          <span class="hint">Available ${qtyText(q)} ${c.sym} · ${money(c.price == null ? null : c.price * q)}</span>
        </div>

        <div class="field">
          <label>RECIPIENT</label>
          <input id="to" placeholder="${ADDRESSES[c.chain] ?? ''}" spellcheck="false">
          <span class="hint">Network ${c.network} (${c.chain}). An address from another chain will be rejected.</span>
        </div>

        <div class="field">
          <label>AMOUNT</label>
          <input id="amount" placeholder="0.00" inputmode="decimal" spellcheck="false">
          <span class="hint" id="amount-hint">—</span>
        </div>

        <div class="field">
          <label>NETWORK FEE</label>
          <div class="fee">
            ${[
              ['slow', 'SLOW', '~40 min', 0.42],
              ['standard', 'STANDARD', '~10 min', 1.18],
              ['fast', 'FAST', '~2 min', 3.05],
            ].map(([id, k, t, usd]) => `
              <button data-fee="${id}" class="${id === feeTier ? 'on' : ''}">
                <span class="fee-k">${k}</span><span class="fee-v">${t} · ${money(usd)}</span>
              </button>`).join('')}
          </div>
        </div>

        <button class="submit" id="review" disabled>REVIEW TRANSACTION</button>
      </div>
    </div>`
}

function renderHistory() {
  views.history.innerHTML = `
    <div class="page">
      <div class="sec"><h2>TRANSACTIONS</h2><span class="rule"></span><span class="aside">${wallet().name} · ${ledger().length} TOTAL</span></div>
      <div class="tx">
        <div class="tx-head">
          <span>TYPE</span><span>COUNTERPARTY</span><span style="text-align:right">AMOUNT</span>
          <span style="text-align:right">WHEN</span><span style="justify-self:end">STATUS</span>
        </div>
        ${txRows(null)}
      </div>
    </div>`
}

// ── Settings ───────────────────────────────────────────────────────────────────
const SETTINGS = {
  autoLock: true,
  lockAfter: '5 MIN',
  confirmSend: true,
  hideBalances: false,
  currency: 'USD',
  theme: 'DARK',
}

const toggleRow = (key, title, note) => `
  <div class="row">
    <span class="row-k"><b>${title}</b><span>${note}</span></span>
    <span class="row-v"><button class="toggle ${SETTINGS[key] ? 'on' : ''}" data-toggle="${key}" aria-label="${title}"><i></i></button></span>
  </div>`

const choiceRow = (key, title, note, options) => `
  <div class="row">
    <span class="row-k"><b>${title}</b><span>${note}</span></span>
    <span class="row-v"><span class="choice">
      ${options.map((o) => `<button data-choice="${key}" data-value="${o}" class="${SETTINGS[key] === o ? 'on' : ''}">${o}</button>`).join('')}
    </span></span>
  </div>`

function renderSettings() {
  views.settings.innerHTML = `
    <div class="page">
      <div class="sec"><h2>SECURITY</h2><span class="rule"></span></div>
      <div class="group">
        <div class="row">
          <span class="row-k"><b>App passphrase</b><span>One PIN unlocks KORA, and KORA holds every wallet — there is no separate code per wallet.</span></span>
          <span class="row-v"><button class="submit ghost" data-act="pin">CHANGE PIN</button></span>
        </div>
        ${toggleRow('autoLock', 'Auto-lock', 'Lock the app after a period of inactivity')}
        ${SETTINGS.autoLock ? choiceRow('lockAfter', 'Lock after', 'How long KORA stays open while unattended', ['1 MIN', '5 MIN', '15 MIN', '1 H']) : ''}
        ${toggleRow('confirmSend', 'Passphrase to send', 'No transaction leaves any wallet without the app passphrase, even while KORA is unlocked')}
        <div class="row">
          <span class="row-k"><b>Recovery phrase</b><span>Twelve words per wallet. Shown once, never stored in plain text, never sent anywhere.</span></span>
          <span class="row-v"><button class="submit ghost" data-act="reveal">REVEAL</button></span>
        </div>
      </div>

      <div class="sec"><h2>DISPLAY</h2><span class="rule"></span></div>
      <div class="group">
        ${choiceRow('theme', 'Appearance', 'The window follows this, not the system setting', ['DARK', 'LIGHT'])}
        ${choiceRow('currency', 'Currency', 'Every value on screen is converted to this', Object.keys(CURRENCIES))}
        ${toggleRow('hideBalances', 'Hide balances', 'Replace every figure with dots until revealed')}
      </div>

      <div class="sec"><h2>WALLETS</h2><span class="rule"></span></div>
      <div class="group">
        ${WALLETS.map((w, i) => `
          <div class="row">
            <span class="row-k"><b>${w.name}</b><span>Funded ${dayText(w.ledger[0]?.ts ?? Date.now())} · ${w.ledger.length} transactions</span></span>
            <span class="row-v">
              <span class="row-value">${money(walletValue(i))}</span>
              ${i === activeWallet ? '<span class="row-value">ACTIVE</span>' : `<button class="submit ghost" data-switch="${i}">OPEN</button>`}
              <!-- Deleting a wallet belongs beside that wallet. A single remove button
                   somewhere else can only ever mean "the one currently open", which is
                   exactly the ambiguity you do not want next to a key store. -->
              <button class="submit danger" data-delete="${i}" ${WALLETS.length > 1 ? '' : 'disabled'}>DELETE</button>
            </span>
          </div>`).join('')}
        <div class="row">
          <span class="row-k"><b>Add wallet</b><span>A new key set under the same app passphrase</span></span>
          <span class="row-v"><button class="submit ghost" data-act="new-wallet">CREATE</button></span>
        </div>
      </div>

      <div class="sec"><h2>ABOUT</h2><span class="rule"></span></div>
      <div class="group">
        <div class="row">
          <span class="row-k"><b>Version</b><span>KORA Wallet for Windows</span></span>
          <span class="row-v"><span class="row-value">4.0.0</span></span>
        </div>
      </div>
    </div>`
}

const RENDER = {
  portfolio: renderPortfolio,
  coin: renderCoin,
  send: renderSend,
  history: renderHistory,
  settings: renderSettings,
}

// ── Navigation ─────────────────────────────────────────────────────────────────
const rail = document.querySelector('#rail')
const marker = document.querySelector('#rail-marker')
const ORDER = ['portfolio', 'coin', 'send', 'history', 'settings']
let current = 'portfolio'

function moveMarker() {
  const active = rail.querySelector('.rail-item.on')
  if (!active) return
  marker.style.height = `${active.offsetHeight}px`
  marker.style.transform = `translateY(${active.offsetTop}px)`
}

function show(next) {
  if (!RENDER[next]) return
  const forward = ORDER.indexOf(next) > ORDER.indexOf(current)
  for (const [name, el] of Object.entries(views)) {
    el.style.setProperty('--enter', `${forward ? 20 : -20}px`)
    el.classList.toggle('on', name === next)
  }
  const railTarget = next === 'coin' ? 'portfolio' : next
  rail.querySelectorAll('.rail-item[data-view]').forEach((b) =>
    b.classList.toggle('on', b.dataset.view === railTarget))
  current = next
  moveMarker()
  RENDER[next]()
}

rail.addEventListener('click', (e) => {
  const item = e.target.closest('.rail-item[data-view]')
  if (item) show(item.dataset.view)
})

// ── Wallet switcher ────────────────────────────────────────────────────────────
const walletPick = document.querySelector('#wallet-pick')
const walletMenu = document.querySelector('#wallet-menu')

function renderWalletMenu() {
  walletMenu.innerHTML = `
    ${WALLETS.map((w, i) => `
      <button class="wallet-opt ${i === activeWallet ? 'on' : ''}" data-wallet="${i}">
        <b>${w.name}</b><span>${money(walletValue(i))}</span>
      </button>`).join('')}
    <button class="wallet-opt add" data-act="new-wallet">+ NEW WALLET</button>
    <div class="pin-note">One passphrase unlocks every wallet in KORA.</div>`
}

function switchWallet(index) {
  if (index === activeWallet || !WALLETS[index]) return
  activeWallet = index
  // A coin the previous wallet tracked may not exist here, so land somewhere that always does.
  if (!wallet().tracked.includes(selected)) selected = wallet().tracked[0] ?? 'BTC'
  rebuildCurves()
  show('portfolio')
}

walletPick.addEventListener('click', () => {
  const open = walletMenu.hidden
  if (open) renderWalletMenu()
  walletMenu.hidden = !open
  walletPick.classList.toggle('open', open)
})

walletMenu.addEventListener('click', (e) => {
  const close = () => {
    walletMenu.hidden = true
    walletPick.classList.remove('open')
  }
  const opt = e.target.closest('[data-wallet]')
  if (opt) { switchWallet(Number(opt.dataset.wallet)); close(); return }
  if (e.target.closest('[data-act="new-wallet"]')) { close(); requestNewWallet() }
})

document.addEventListener('click', (e) => {
  if (walletMenu.hidden) return
  if (e.target.closest('#wallet-menu') || e.target.closest('#wallet-pick')) return
  walletMenu.hidden = true
  walletPick.classList.remove('open')
})

// ── Sheets ─────────────────────────────────────────────────────────────────────
const modal = document.querySelector('#modal')
const closeModal = () => { modal.hidden = true }

function openReceive(sym) {
  const c = coins.get(sym) ?? coins.get(selected)
  const address = ADDRESSES[c.chain] ?? ADDRESSES.BTC
  let qrSvg = ''
  try {
    const qr = qrcode(0, 'M')
    qr.addData(address)
    qr.make()
    qrSvg = qr.createSvgTag({ cellSize: 5, margin: 0, scalable: true })
  } catch { /* the address alone still works, typed by hand */ }

  modal.innerHTML = `
    <div class="sheet">
      <div class="sheet-head">
        <div class="sheet-title">RECEIVE ${c.sym}</div>
        <div class="sheet-sub">${c.network} · ${c.chain} · ${wallet().name}</div>
      </div>
      ${qrSvg ? `<div class="qr">${qrSvg}</div>` : `<div class="warn">QR unavailable offline</div>`}
      <div class="addr">${address}</div>
      <div class="warn">Send only ${c.sym} on ${c.network} to this address.<br>Anything else is lost permanently.</div>
      <div class="sheet-actions">
        <button class="submit ghost" data-copy="${address}">COPY ADDRESS</button>
        <button class="submit" data-close>DONE</button>
      </div>
    </div>`
  modal.hidden = false
}

let catalogueFilter = ''
function openCatalogue() {
  const q = catalogueFilter.trim().toUpperCase()
  const matches = ([sym, m]) => !q || sym.includes(q) || m.name.toUpperCase().includes(q)

  const inList = wallet().tracked
    .map((sym) => [sym, CATALOGUE[sym]])
    .filter(([, m]) => m)
    .filter(matches)
  const available = Object.entries(CATALOGUE)
    .filter(([sym]) => !wallet().tracked.includes(sym))
    .filter(matches)

  /*
   * Removal is only offered on an empty position. Hiding a coin that still holds a balance
   * would not remove the coins — it would remove the only place they are visible, which is
   * how people lose track of money they still own.
   */
  const row = (sym, m, mode) => {
    const q2 = held(sym)
    const locked = mode === 'remove' && q2 > 0
    return `
      <div class="cat-row ${locked ? 'locked' : ''}" ${locked ? '' : `data-${mode}="${sym}"`}>
        <span class="chain-tag">${m.chain}</span>
        <span class="sym">${sym}</span>
        <span class="name">${m.name}</span>
        <span class="add ${mode === 'remove' && !locked ? 'remove' : ''}">${
          mode === 'add' ? 'ADD' : locked ? `HOLDS ${qtyText(q2)}` : 'REMOVE'
        }</span>
      </div>`
  }

  // Adding or removing rebuilds the list, and a rebuilt list starts at the top. Carrying the
  // scroll position across means the row you just acted on is still under your cursor.
  const keepScroll = document.querySelector('.catalogue')?.scrollTop ?? 0

  modal.innerHTML = `
    <div class="sheet wide">
      <div class="sheet-head">
        <div class="sheet-title">TOKENS</div>
        <div class="sheet-sub">IN ${wallet().name}</div>
      </div>
      <div class="field">
        <input id="cat-search" placeholder="Search by symbol or name" spellcheck="false" value="${catalogueFilter}">
      </div>
      <div class="catalogue">
        <div class="cat-note">IN THIS WALLET — A COIN WITH A BALANCE CANNOT BE REMOVED</div>
        ${inList.length ? inList.map(([sym, m]) => row(sym, m, 'remove')).join('')
                        : `<div class="cat-empty">NOTHING MATCHES</div>`}
        <div class="cat-note">AVAILABLE TO ADD</div>
        ${available.length ? available.map(([sym, m]) => row(sym, m, 'add')).join('')
                           : `<div class="cat-empty">${q ? 'NOTHING MATCHES' : 'EVERY SUPPORTED TOKEN IS ALREADY HERE'}</div>`}
      </div>
      <div class="sheet-actions"><button class="submit" data-close>DONE</button></div>
    </div>`
  modal.hidden = false

  const list = document.querySelector('.catalogue')
  if (list) list.scrollTop = keepScroll

  const search = document.querySelector('#cat-search')
  search?.focus()
  search?.addEventListener('input', () => {
    catalogueFilter = search.value
    const at = search.selectionStart
    openCatalogue()
    const again = document.querySelector('#cat-search')
    again?.setSelectionRange(at, at)
  })
}

// ── Transaction detail ─────────────────────────────────────────────────────────
/** A hash the transaction can be recognised by, derived from its own contents. */
function txHash(e) {
  let h = 0x811c9dc5
  for (const ch of `${e.sym}${e.date}${e.qty}${e.peer}`) {
    h ^= ch.charCodeAt(0)
    h = Math.imul(h, 0x01000193) >>> 0
  }
  let out = ''
  let seed = h
  for (let i = 0; i < 64; i++) {
    seed = Math.imul(seed ^ (seed >>> 13), 0x5bd1e995) >>> 0
    out += '0123456789abcdef'[seed & 15]
  }
  return out
}

function openTx(index, filter) {
  // The same filter the rows were built from, so an index taken off the coin page still
  // points at the transaction the user actually clicked.
  const list = ledger().filter((x) => !filter || x.sym === filter).slice().reverse()
  const e = list[index]
  if (!e) return
  const c = coins.get(e.sym) ?? CATALOGUE[e.sym]
  const incoming = e.qty > 0
  const then = closeAt(e.sym, e.ts)
  const now = coins.get(e.sym)?.price ?? null
  const pending = index === 0 && Date.now() - e.ts < 3 * 86400000
  const drift = then && now ? (now / then - 1) * 100 : null

  modal.innerHTML = `
    <div class="sheet wide">
      <div class="sheet-head">
        <div class="sheet-title">${incoming ? 'RECEIVED' : 'SENT'} ${e.sym}</div>
        <div class="sheet-sub">${c.network} · ${c.chain} · ${wallet().name}</div>
      </div>

      <div class="detail-amount ${incoming ? 'in' : 'out'}">${incoming ? '+' : '−'}${qtyText(e.qty)} ${e.sym}</div>

      <div class="detail">
        <div class="detail-row"><span class="detail-k">STATUS</span>
          <span class="detail-v ${pending ? '' : 'up'}">${pending ? 'PENDING' : 'CONFIRMED'}</span></div>
        <div class="detail-row"><span class="detail-k">DATE</span>
          <span class="detail-v">${dayText(e.ts)} · ${agoText(e.ts)}</span></div>
        <div class="detail-row"><span class="detail-k">${incoming ? 'FROM' : 'TO'}</span>
          <span class="detail-v">${e.peer}</span></div>
        <div class="detail-row"><span class="detail-k">NETWORK</span>
          <span class="detail-v">${c.network} (${c.chain})</span></div>
        <div class="detail-row"><span class="detail-k">PRICE THEN</span>
          <span class="detail-v">${money(then)}</span></div>
        <div class="detail-row"><span class="detail-k">VALUE THEN</span>
          <span class="detail-v">${then == null ? '—' : money(Math.abs(e.qty) * then)}</span></div>
        <div class="detail-row"><span class="detail-k">VALUE NOW</span>
          <span class="detail-v">${now == null ? '—' : money(Math.abs(e.qty) * now)}</span></div>
        <div class="detail-row"><span class="detail-k">SINCE THEN</span>
          <span class="detail-v ${drift >= 0 ? 'up' : 'down'}">${pct(drift)}</span></div>
        <div class="detail-row"><span class="detail-k">NETWORK FEE</span>
          <span class="detail-v">${incoming ? 'PAID BY SENDER' : money(1.18)}</span></div>
        <div class="detail-row"><span class="detail-k">TRANSACTION</span>
          <span class="detail-v">${txHash(e)}</span></div>
      </div>

      <div class="sheet-actions">
        <button class="submit ghost" data-copy="${txHash(e)}">COPY HASH</button>
        <button class="submit" data-close>DONE</button>
      </div>
    </div>`
  modal.hidden = false
}

// ── Passphrase gate ────────────────────────────────────────────────────────────
/**
 * One passphrase guards the app, so anything destructive or outgoing asks for the same one.
 * The prototype accepts any non-empty entry — what is being designed here is the moment of
 * being asked, not the check itself.
 */
let pendingConfirm = null
function askPassphrase({ title, note, confirmLabel = 'CONFIRM', danger = false }, onConfirm) {
  pendingConfirm = onConfirm
  modal.innerHTML = `
    <div class="sheet">
      <div class="sheet-head">
        <div class="sheet-title">${title}</div>
        <div class="sheet-sub">APP PASSPHRASE</div>
      </div>
      <div class="warn">${note}</div>
      <div class="field" style="width:100%">
        <input id="pass" type="password" placeholder="••••••••" spellcheck="false">
        <span class="hint" id="pass-hint">One passphrase covers every wallet in KORA.</span>
      </div>
      <div class="sheet-actions">
        <button class="submit ghost" data-close>CANCEL</button>
        <button class="submit ${danger ? 'danger' : ''}" data-confirm>${confirmLabel}</button>
      </div>
    </div>`
  modal.hidden = false
  const input = document.querySelector('#pass')
  input?.focus()
  input?.addEventListener('keydown', (ev) => {
    if (ev.key === 'Enter') document.querySelector('[data-confirm]')?.click()
  })
}

modal.addEventListener('click', (e) => {
  if (e.target === modal || e.target.closest('[data-close]')) { closeModal(); return }

  const copy = e.target.closest('[data-copy]')
  if (copy) {
    navigator.clipboard?.writeText(copy.dataset.copy)
    copy.textContent = 'COPIED'
    setTimeout(() => { copy.textContent = 'COPY ADDRESS' }, 1400)
    return
  }

  const add = e.target.closest('[data-add]')
  if (add) {
    wallet().tracked.push(add.dataset.add)
    renderPortfolio()
    openCatalogue()
    return
  }

  const remove = e.target.closest('[data-remove]')
  if (remove) {
    const sym = remove.dataset.remove
    if (held(sym) > 0) return
    wallet().tracked = wallet().tracked.filter((s) => s !== sym)
    if (selected === sym) selected = wallet().tracked[0] ?? 'BTC'
    renderPortfolio()
    openCatalogue()
    return
  }

  const confirm = e.target.closest('[data-confirm]')
  if (confirm) {
    const input = document.querySelector('#pass')
    if (!input?.value.trim()) {
      const hint = document.querySelector('#pass-hint')
      if (hint) { hint.textContent = 'Enter the app passphrase to continue.'; hint.style.color = 'var(--down)' }
      input?.focus()
      return
    }
    const run = pendingConfirm
    pendingConfirm = null
    closeModal()
    run?.()
  }
})

// ── Onboarding ─────────────────────────────────────────────────────────────────
/**
 * Creating and restoring a wallet, and the very first launch when there is nothing to open.
 *
 * The words below are a sample of the BIP-39 English list, enough to make the flow real to
 * look at. A shipping build must draw from the full 2048-word list and carry the checksum —
 * a phrase that cannot be restored elsewhere is not a recovery phrase.
 */
const WORDS = `abandon ability able about above absent absorb abstract absurd abuse access accident
account accuse achieve acid acoustic acquire across action actor actual adapt add addict address
adjust admit adult advance advice aerobic affair afford afraid again age agent agree ahead aim air
airport aisle alarm album alcohol alert alien all alley allow almost alone alpha already also alter
always amateur amazing among amount amused analyst anchor ancient anger angle angry animal ankle
announce annual another answer antenna antique anxiety any apart apology appear apple approve april
arch arctic area arena argue arm armed armor army around arrange arrest arrive arrow art artefact
artist artwork ask aspect assault asset assist assume asthma athlete atom attack attend attitude
attract auction audit august aunt author auto autumn average avocado avoid awake aware away awesome
awful awkward axis baby bachelor bacon badge bag balance balcony ball bamboo banana banner bar
barely bargain barrel base basic basket battle beach bean beauty because become beef before begin`
  .trim().split(/\s+/)

const onboard = document.querySelector('#onboard')

let ob = null
function openOnboarding({ firstRun }) {
  ob = {
    firstRun,
    step: 'choose',
    mode: null,
    name: firstRun ? 'MAIN' : `WALLET ${WALLETS.length + 1}`,
    phrase: [],
    restore: Array(12).fill(''),
    checks: [],
    error: '',
  }
  onboard.hidden = false
  renderOnboard()
}

function closeOnboarding() {
  onboard.hidden = true
  ob = null
}

function newPhrase() {
  const out = []
  const pool = [...WORDS]
  for (let i = 0; i < 12; i++) {
    out.push(pool.splice(Math.floor(Math.random() * pool.length), 1)[0])
  }
  return out
}

/** Three positions to type back, so writing the phrase down is actually verified. */
function pickChecks() {
  const idx = new Set()
  while (idx.size < 3) idx.add(Math.floor(Math.random() * 12))
  return [...idx].sort((a, b) => a - b).map((i) => ({ i, value: '' }))
}

const OB_STEPS = { choose: 0, name: 1, phrase: 2, verify: 3, restore: 2, passphrase: 4, done: 5 }

function renderOnboard() {
  if (!ob) return
  const stepCount = ob.firstRun ? 5 : 4
  const dots = (active) =>
    `<div class="ob-steps">${Array.from({ length: stepCount }, (_, i) =>
      `<span class="ob-step ${i <= active ? 'on' : ''}"></span>`).join('')}</div>`

  const shell = (body, foot) => `
    <div class="ob-body">${body}</div>
    <div class="ob-foot">${foot}</div>`

  if (ob.step === 'choose') {
    onboard.innerHTML = shell(`
      <div class="ob-mark"><svg width="54" height="54" viewBox="0 0 64 64" fill="currentColor">
        <rect x="17" y="16" width="7" height="32"/>
        <path d="M28 32 L45 16 L45 25 L37 32 L45 39 L45 48 Z"/></svg></div>
      <div class="ob-title">${ob.firstRun ? 'Welcome to KORA' : 'Add a wallet'}</div>
      <div class="ob-note">${ob.firstRun
        ? 'There is no wallet on this computer yet. Create one, or restore a wallet you already own from its recovery phrase.'
        : 'A new key set under the same app passphrase. Every wallet in KORA is unlocked by the one you already use.'}</div>
      <div class="ob-choices">
        <button class="ob-choice" data-ob="create">
          <b>CREATE A NEW WALLET</b>
          <span>Generates a fresh recovery phrase. Write it down — it is the only way back in.</span>
        </button>
        <button class="ob-choice" data-ob="restore">
          <b>RESTORE FROM A RECOVERY PHRASE</b>
          <span>Twelve words from a wallet you already have, here or in another app.</span>
        </button>
      </div>
      ${dots(0)}`,
      ob.firstRun ? '<div class="spacer"></div>' : `<div class="spacer"></div><button class="submit ghost" data-ob="cancel">CANCEL</button>`)
    return
  }

  if (ob.step === 'name') {
    onboard.innerHTML = shell(`
      <div class="ob-title">Name this wallet</div>
      <div class="ob-note">Only you see this. It is how the wallet is labelled in the switcher and on the portfolio.</div>
      <div class="ob-form">
        <div class="field">
          <label>WALLET NAME</label>
          <input id="ob-name" value="${ob.name}" spellcheck="false" maxlength="18">
          ${ob.error ? `<span class="hint" style="color:var(--down)">${ob.error}</span>` : ''}
        </div>
      </div>
      ${dots(1)}`,
      `<button class="submit ghost" data-ob="back">BACK</button><div class="spacer"></div><button class="submit" data-ob="name-next">CONTINUE</button>`)
    const input = document.querySelector('#ob-name')
    input?.focus()
    input?.select()
    return
  }

  if (ob.step === 'phrase') {
    onboard.innerHTML = shell(`
      <div class="ob-title">Your recovery phrase</div>
      <div class="ob-note loud warn">Write these twelve words down in order and keep them offline.<br>
        Anyone who has them owns this wallet. KORA cannot show them again.</div>
      <div class="phrase">
        ${ob.phrase.map((w, i) => `<div class="word"><i>${String(i + 1).padStart(2, '0')}</i><b>${w}</b></div>`).join('')}
      </div>
      ${dots(2)}`,
      `<button class="submit ghost" data-ob="back">BACK</button>
       <button class="submit ghost" data-ob="copy-phrase">COPY</button>
       <button class="submit" data-ob="phrase-next">I HAVE WRITTEN IT DOWN</button>`)
    return
  }

  if (ob.step === 'verify') {
    onboard.innerHTML = shell(`
      <div class="ob-title">Confirm the phrase</div>
      <div class="ob-note">Type the words at these positions. This is the only check that the phrase left the screen.</div>
      <div class="ob-form">
        ${ob.checks.map((c, n) => `
          <div class="field">
            <label>WORD ${String(c.i + 1).padStart(2, '0')}</label>
            <input data-check="${n}" value="${c.value}" spellcheck="false" autocomplete="off">
          </div>`).join('')}
        ${ob.error ? `<span class="hint" style="color:var(--down)">${ob.error}</span>` : ''}
      </div>
      ${dots(3)}`,
      `<button class="submit ghost" data-ob="back">BACK</button><div class="spacer"></div><button class="submit" data-ob="verify-next">CONTINUE</button>`)
    document.querySelector('[data-check="0"]')?.focus()
    return
  }

  if (ob.step === 'restore') {
    onboard.innerHTML = shell(`
      <div class="ob-title">Enter your recovery phrase</div>
      <div class="ob-note">Twelve words, in order. Paste into the first box to fill them all at once.</div>
      <div class="phrase">
        ${ob.restore.map((w, i) => `
          <div class="word ${ob.error && !w.trim() ? 'bad' : ''}">
            <i>${String(i + 1).padStart(2, '0')}</i>
            <input data-word="${i}" value="${w}" spellcheck="false" autocomplete="off">
          </div>`).join('')}
      </div>
      ${ob.error ? `<div class="warn loud">${ob.error}</div>` : ''}
      ${dots(2)}`,
      `<button class="submit ghost" data-ob="back">BACK</button><div class="spacer"></div><button class="submit" data-ob="restore-next">CONTINUE</button>`)
    document.querySelector('[data-word="0"]')?.focus()
    return
  }

  if (ob.step === 'passphrase') {
    onboard.innerHTML = shell(`
      <div class="ob-title">Set the app passphrase</div>
      <div class="ob-note">One passphrase unlocks KORA and everything in it. It is not the recovery phrase, and it never leaves this computer.</div>
      <div class="ob-form">
        <div class="field">
          <label>PASSPHRASE</label>
          <input id="ob-pass" type="password" placeholder="••••••••" spellcheck="false">
        </div>
        <div class="field">
          <label>REPEAT</label>
          <input id="ob-pass2" type="password" placeholder="••••••••" spellcheck="false">
          ${ob.error ? `<span class="hint" style="color:var(--down)">${ob.error}</span>` : ''}
        </div>
      </div>
      ${dots(4)}`,
      `<button class="submit ghost" data-ob="back">BACK</button><div class="spacer"></div><button class="submit" data-ob="pass-next">FINISH</button>`)
    document.querySelector('#ob-pass')?.focus()
    return
  }

  if (ob.step === 'done') {
    onboard.innerHTML = shell(`
      <div class="ob-mark"><svg width="54" height="54" viewBox="0 0 64 64" fill="currentColor">
        <rect x="17" y="16" width="7" height="32"/>
        <path d="M28 32 L45 16 L45 25 L37 32 L45 39 L45 48 Z"/></svg></div>
      <div class="ob-title">${ob.name} is ready</div>
      <div class="ob-note">${ob.mode === 'restore'
        ? 'Balances appear as the networks are scanned.'
        : 'Receive to any of its addresses to fund it.'}</div>
      ${dots(stepCount - 1)}`,
      `<div class="spacer"></div><button class="submit" data-ob="finish">OPEN WALLET</button>`)
    return
  }
}

function commitWallet() {
  WALLETS.push({
    id: ob.name.toLowerCase().replace(/\s+/g, '-'),
    name: ob.name.toUpperCase(),
    // A new wallet holds nothing; it starts tracking the coins most people fund first.
    tracked: ob.mode === 'restore' ? ['BTC', 'ETH', 'USDC'] : ['BTC', 'ETH'],
    ledger: [],
  })
  activeWallet = WALLETS.length - 1
  selected = wallet().tracked[0]
  rebuildCurves()
}

onboard.addEventListener('click', (e) => {
  const hit = e.target.closest('[data-ob]')
  if (!hit || !ob) return
  const action = hit.dataset.ob
  ob.error = ''

  if (action === 'cancel') { closeOnboarding(); return }

  if (action === 'create' || action === 'restore') {
    ob.mode = action
    ob.step = 'name'
    renderOnboard()
    return
  }

  if (action === 'back') {
    ob.step = ob.step === 'name' ? 'choose'
      : ob.step === 'phrase' || ob.step === 'restore' ? 'name'
      : ob.step === 'verify' ? 'phrase'
      : 'verify'
    renderOnboard()
    return
  }

  if (action === 'name-next') {
    const value = document.querySelector('#ob-name')?.value.trim() ?? ''
    if (!value) { ob.error = 'Give the wallet a name.'; renderOnboard(); return }
    if (WALLETS.some((w) => w.name === value.toUpperCase())) {
      ob.error = 'A wallet with that name already exists.'
      renderOnboard()
      return
    }
    ob.name = value
    if (ob.mode === 'create') {
      ob.phrase = newPhrase()
      ob.checks = pickChecks()
      ob.step = 'phrase'
    } else {
      ob.step = 'restore'
    }
    renderOnboard()
    return
  }

  if (action === 'copy-phrase') {
    navigator.clipboard?.writeText(ob.phrase.join(' '))
    hit.textContent = 'COPIED'
    setTimeout(() => { hit.textContent = 'COPY' }, 1400)
    return
  }

  if (action === 'phrase-next') { ob.step = 'verify'; renderOnboard(); return }

  if (action === 'verify-next') {
    ob.checks = ob.checks.map((c, n) => ({
      ...c,
      value: document.querySelector(`[data-check="${n}"]`)?.value.trim().toLowerCase() ?? '',
    }))
    const wrong = ob.checks.some((c) => c.value !== ob.phrase[c.i])
    if (wrong) { ob.error = 'Those do not match the phrase. Check your notes.'; renderOnboard(); return }
    ob.step = ob.firstRun ? 'passphrase' : 'done'
    if (!ob.firstRun) commitWallet()
    renderOnboard()
    return
  }

  if (action === 'restore-next') {
    ob.restore = ob.restore.map((_, i) => document.querySelector(`[data-word="${i}"]`)?.value.trim().toLowerCase() ?? '')
    if (ob.restore.some((w) => !w)) { ob.error = 'All twelve words are needed.'; renderOnboard(); return }
    ob.step = ob.firstRun ? 'passphrase' : 'done'
    if (!ob.firstRun) commitWallet()
    renderOnboard()
    return
  }

  if (action === 'pass-next') {
    const a = document.querySelector('#ob-pass')?.value ?? ''
    const b = document.querySelector('#ob-pass2')?.value ?? ''
    if (a.length < 6) { ob.error = 'Use at least six characters.'; renderOnboard(); return }
    if (a !== b) { ob.error = 'The two entries do not match.'; renderOnboard(); return }
    commitWallet()
    ob.step = 'done'
    renderOnboard()
    return
  }

  if (action === 'finish') {
    closeOnboarding()
    show('portfolio')
  }
})

/** Pasting a whole phrase into the first box should fill the rest. */
onboard.addEventListener('input', (e) => {
  const box = e.target.closest('[data-word]')
  if (!box || !ob) return
  const words = box.value.trim().toLowerCase().split(/\s+/)
  const start = Number(box.dataset.word)
  if (words.length > 1) {
    words.slice(0, 12 - start).forEach((w, k) => { ob.restore[start + k] = w })
    renderOnboard()
    document.querySelector(`[data-word="${Math.min(start + words.length, 11)}"]`)?.focus()
  } else {
    ob.restore[start] = box.value
  }
})

// ── Stage interaction ──────────────────────────────────────────────────────────
document.querySelector('#stage').addEventListener('click', (e) => {
  const receive = e.target.closest('[data-receive]')
  if (receive) { openReceive(receive.dataset.receive || selected); return }

  const send = e.target.closest('[data-send]')
  if (send) { selected = send.dataset.send; show('send'); return }

  const row = e.target.closest('.asset-row[data-sym]')
  if (row) { selected = row.dataset.sym; show('coin'); return }

  const tx = e.target.closest('.tx-row')
  if (tx) {
    const rows = [...tx.parentElement.querySelectorAll('.tx-row')]
    openTx(rows.indexOf(tx), tx.dataset.filter || null)
    return
  }

  const review = e.target.closest('#review')
  if (review && !review.disabled) { submitSend(); return }

  const pick = e.target.closest('[data-pick]')
  if (pick) { selected = pick.dataset.pick; RENDER[current](); return }

  const go = e.target.closest('[data-go]')
  if (go) { show(go.dataset.go); return }

  const r = e.target.closest('[data-range]')
  if (r) { range = r.dataset.range; renderPortfolio(); return }

  const fee = e.target.closest('[data-fee]')
  if (fee) { feeTier = fee.dataset.fee; renderSend(); return }

  const switchTo = e.target.closest('[data-switch]')
  if (switchTo) { switchWallet(Number(switchTo.dataset.switch)); return }

  const del = e.target.closest('[data-delete]')
  if (del && !del.disabled) { deleteWallet(Number(del.dataset.delete)); return }

  const toggle = e.target.closest('[data-toggle]')
  if (toggle) {
    SETTINGS[toggle.dataset.toggle] = !SETTINGS[toggle.dataset.toggle]
    renderSettings()
    return
  }

  const choice = e.target.closest('[data-choice]')
  if (choice) {
    const { choice: key, value } = choice.dataset
    SETTINGS[key] = value
    if (key === 'theme') document.documentElement.setAttribute('data-theme', value.toLowerCase())
    if (key === 'currency') currency = value
    renderSettings()
    return
  }

  const act = e.target.closest('[data-act]')
  if (act?.dataset.act === 'add-token') { catalogueFilter = ''; openCatalogue(); return }
  if (act?.dataset.act === 'new-wallet') { requestNewWallet() }
})

/** Adding a wallet under an existing app still goes through the app passphrase. */
function requestNewWallet() {
  askPassphrase(
    {
      title: 'ADD A WALLET',
      note: 'A new key set joins this KORA. It is unlocked by the passphrase you already use.',
      confirmLabel: 'CONTINUE',
    },
    () => openOnboarding({ firstRun: false }),
  )
}

/** Deleting keys is irreversible, so it asks for the passphrase like every other exit. */
function deleteWallet(index) {
  const target = WALLETS[index]
  if (!target || WALLETS.length < 2) return
  askPassphrase(
    {
      title: `DELETE ${target.name}`,
      note: `This removes the local keys for ${target.name} and its ${target.ledger.length} recorded transactions. Without that wallet's recovery phrase it cannot be brought back.`,
      confirmLabel: 'DELETE WALLET',
      danger: true,
    },
    () => {
      const wasActive = index === activeWallet
      WALLETS.splice(index, 1)
      if (wasActive) activeWallet = 0
      else if (index < activeWallet) activeWallet -= 1
      if (!wallet().tracked.includes(selected)) selected = wallet().tracked[0] ?? 'BTC'
      rebuildCurves()
      renderSettings()
    },
  )
}

/** The send itself, gated by the setting that says nothing leaves without the passphrase. */
function submitSend() {
  const c = coins.get(selected)
  const amount = Number(document.querySelector('#amount')?.value ?? 0)
  const to = document.querySelector('#to')?.value.trim() ?? ''
  const done = () => {
    ledger().push({
      sym: c.sym,
      date: new Date().toISOString().slice(0, 10),
      ts: Date.now(),
      qty: -amount,
      peer: to,
    })
    ledger().sort((a, b) => a.ts - b.ts)
    rebuildCurves()
    show('history')
  }

  if (!SETTINGS.confirmSend) { done(); return }
  askPassphrase(
    {
      title: `SEND ${qtyText(amount)} ${c.sym}`,
      note: `To ${short(to)} on ${c.network}. Once broadcast this cannot be recalled.`,
      confirmLabel: 'SIGN AND SEND',
    },
    done,
  )
}

document.querySelector('#stage').addEventListener('input', () => {
  const to = document.querySelector('#to')
  const amount = document.querySelector('#amount')
  const review = document.querySelector('#review')
  if (!to || !amount || !review) return
  const c = coins.get(selected)
  const q = held(c.sym)
  const value = Number(amount.value)
  const enough = value > 0 && value <= q
  const hint = document.querySelector('#amount-hint')
  if (hint) {
    hint.textContent = !amount.value
      ? '—'
      : !enough
        ? `More than the ${qtyText(q)} ${c.sym} available`
        : `${money(c.price == null ? null : value * c.price)} at the current price`
    hint.style.color = amount.value && !enough ? 'var(--down)' : ''
  }
  review.disabled = !(to.value.trim().length > 20 && enough)
})

// ── Live prices ────────────────────────────────────────────────────────────────
function commit() {
  if (current === 'portfolio') {
    const total = document.querySelector('[data-total]')
    if (total) total.textContent = money(totalValue())
    const d = document.querySelector('[data-total-delta]')
    if (d) {
      const delta = totalDelta()
      d.textContent = `${pct(delta)} · 24H`
      d.classList.toggle('up', delta >= 0)
      d.classList.toggle('down', delta < 0)
    }
    for (const sym of wallet().tracked) {
      const c = coins.get(sym)
      const row = document.querySelector(`.asset-row[data-sym="${sym}"]`)
      if (!row || !c) continue
      const q = held(sym)
      row.querySelector('[data-price]').textContent = money(c.price)
      row.querySelector('[data-value]').textContent = c.price == null ? '—' : money(c.price * q)
      const delta = row.querySelector('[data-delta]')
      delta.textContent = pct(c.delta)
      delta.classList.toggle('up', c.delta >= 0)
      delta.classList.toggle('down', c.delta < 0)
    }
  } else if (current === 'coin') {
    const c = coins.get(selected)
    const value = document.querySelector('[data-coin-value]')
    const price = document.querySelector('[data-coin-price]')
    if (value && c.price != null) value.textContent = money(c.price * held(c.sym))
    if (price) price.textContent = money(c.price)
  }
}

async function bootstrap() {
  try {
    const list = JSON.stringify(Object.keys(CATALOGUE).map(pair))
    const res = await fetch(`${REST}/ticker/24hr?symbols=${encodeURIComponent(list)}`)
    for (const row of await res.json()) {
      const c = coins.get(row.symbol.replace(/USDT$/, ''))
      if (!c) continue
      c.price = Number(row.lastPrice)
      c.delta = Number(row.priceChangePercent)
    }
  } catch { /* the curve still draws from history; only the live figures go missing */ }

  await loadHistory()
  rebuildCurves()
  walletName.textContent = wallet().name
  show('portfolio')
}

let retry = 0
function connect() {
  const streams = Object.keys(CATALOGUE).map((s) => `${pair(s).toLowerCase()}@ticker`).join('/')
  const socket = new WebSocket(WS + streams)
  socket.onopen = () => { retry = 0 }
  socket.onmessage = (event) => {
    const d = JSON.parse(event.data).data
    if (!d?.s) return
    const c = coins.get(d.s.replace(/USDT$/, ''))
    if (!c) return
    c.price = Number(d.c)
    c.delta = Number(d.P)
  }
  socket.onclose = () => {
    retry = Math.min(retry + 1, 5)
    setTimeout(connect, retry * 1200)
  }
  socket.onerror = () => { try { socket.close() } catch {} }
}

setInterval(commit, BEAT_MS)

// ── Chrome ─────────────────────────────────────────────────────────────────────
function toggleTheme() {
  const next = document.documentElement.getAttribute('data-theme') === 'light' ? 'dark' : 'light'
  document.documentElement.setAttribute('data-theme', next)
  SETTINGS.theme = next.toUpperCase()
  if (current === 'settings') renderSettings()
}
document.querySelector('#theme').addEventListener('click', toggleTheme)
document.querySelector('#theme-lab').addEventListener('click', toggleTheme)

const splash = document.querySelector('#splash')
function runSplash() {
  splash.classList.remove('gone')
  requestAnimationFrame(() => splash.classList.add('load'))
  setTimeout(() => { splash.classList.add('gone'); splash.classList.remove('load') }, 2100)
}
document.querySelector('#replay').addEventListener('click', runSplash)

// A lab control, not a product one: the real app reaches this state by having no wallets.
document.querySelector('#first-run').addEventListener('click', () => {
  modal.hidden = true
  openOnboarding({ firstRun: true })
})

if (!document.querySelector('#chart-keys')) {
  const style = document.createElement('style')
  style.id = 'chart-keys'
  style.textContent = '@keyframes draw{to{stroke-dashoffset:0}}@keyframes fadeIn{to{opacity:1}}'
  document.head.append(style)
}

// ── Start ──────────────────────────────────────────────────────────────────────
document.documentElement.setAttribute('data-theme', 'dark')
runSplash()
requestAnimationFrame(moveMarker)
await bootstrap()
connect()

/**
 * KORA Market — interaction prototype on live Binance data.
 *
 * Nothing here is simulated: prices come from the exchange over WebSocket and charts from
 * the klines endpoint. The point of prototyping against the real feed is that the motion
 * has to survive real behaviour — bursts on liquid pairs, long silences on quiet ones, and
 * a connection that can drop — rather than a tidy random walk that always looks good.
 */

// The approved K monogram, inlined so it can act as a CSS mask and take the theme's ink.
const MARK = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect x="17" y="16" width="7" height="32"/>
  <path d="M28 32 L45 16 L45 25 L37 32 L45 39 L45 48 Z"/></svg>`
document.documentElement.style.setProperty(
  '--mark-url',
  `url("data:image/svg+xml;utf8,${encodeURIComponent(MARK)}")`,
)

// MATIC is gone: Binance lists MATICUSDT as BREAK since Polygon migrated to POL. The old
// pair would sit frozen on the grid forever.
const SYMBOLS = [
  'BTC', 'ETH', 'BNB', 'SOL', 'XRP', 'ADA', 'DOGE', 'AVAX', 'LINK', 'DOT',
  'POL', 'LTC', 'BCH', 'ETC', 'TRX', 'UNI', 'ATOM', 'ALGO', 'USDC', 'FIL',
]

const NAMES = {
  BTC: 'Bitcoin', ETH: 'Ethereum', BNB: 'BNB', SOL: 'Solana', XRP: 'XRP',
  ADA: 'Cardano', DOGE: 'Dogecoin', AVAX: 'Avalanche', LINK: 'Chainlink',
  DOT: 'Polkadot', POL: 'Polygon', LTC: 'Litecoin', BCH: 'Bitcoin Cash',
  ETC: 'Ethereum Classic', TRX: 'Tron', UNI: 'Uniswap', ATOM: 'Cosmos',
  ALGO: 'Algorand', USDC: 'USD Coin', FIL: 'Filecoin',
}

/**
 * Binance cannot report a market capitalisation: it knows the price of a pair, not how many
 * coins exist. Circulating supply and the all-time high come from CoinGecko once, and the
 * numbers built on them are recomputed here from the live price — so the capitalisation on
 * screen always equals the price on screen times the supply, and moves with every beat.
 */
const REST = 'https://api.binance.com/api/v3'
const WS = 'wss://stream.binance.com:9443/stream?streams='
const GECKO = 'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&per_page=250&ids='
const GECKO_IDS = {
  BTC: 'bitcoin', ETH: 'ethereum', BNB: 'binancecoin', SOL: 'solana', XRP: 'ripple',
  ADA: 'cardano', DOGE: 'dogecoin', AVAX: 'avalanche-2', LINK: 'chainlink', DOT: 'polkadot',
  POL: 'polygon-ecosystem-token', LTC: 'litecoin', BCH: 'bitcoin-cash', ETC: 'ethereum-classic',
  TRX: 'tron', UNI: 'uniswap', ATOM: 'cosmos', ALGO: 'algorand', USDC: 'usd-coin', FIL: 'filecoin',
}
const pair = (s) => `${s}USDT`

/** Live state, keyed by symbol. */
const coins = new Map(
  SYMBOLS.map((sym, i) => [
    sym,
    {
      sym, name: NAMES[sym] ?? sym, rank: i + 1,
      price: null, delta: 0, vol: 0, high: null, low: null, history: [],
      supply: null, ath: null,
    },
  ]),
)

// ── Formatting ─────────────────────────────────────────────────────────────────
/**
 * Places scale with magnitude, and never below two above a dollar.
 *
 * Rounding four-figure prices to whole dollars hid the ticking entirely: ETH moves a few
 * cents at a time, so at zero decimals the number sat frozen while the socket was in fact
 * delivering. A live price has to show the movement it is claiming to have.
 */
const places = (v) => (v >= 1 ? 2 : v >= 0.01 ? 4 : 6)
const dollars = (v, p) => '$' + v.toLocaleString('en-US', { minimumFractionDigits: p, maximumFractionDigits: p })

function money(v) {
  return v == null ? '—' : dollars(v, places(v))
}

/**
 * A change carries the precision of the price it was measured against, not its own.
 * Sizing by the difference made a 21-cent move on a $73 coin print as "0.2100" — four
 * decimals of authority on a number whose own price only ever shows two.
 */
function moneyDiff(diff, reference) {
  const p = places(Math.abs(reference))
  return (diff >= 0 ? '+' : '−') + dollars(Math.abs(diff), p)
}
const pct = (v) => (v >= 0 ? '+' : '') + v.toFixed(2) + '%'
function volume(v) {
  if (v >= 1e9) return '$' + (v / 1e9).toFixed(1) + 'B'
  if (v >= 1e6) return '$' + (v / 1e6).toFixed(1) + 'M'
  return '$' + (v / 1e3).toFixed(0) + 'K'
}

/** Trillions down to units, with the decimals thinning out as the number grows. */
function compact(v) {
  if (v == null || !isFinite(v)) return '—'
  const a = Math.abs(v)
  const [unit, suffix] =
    a >= 1e12 ? [1e12, 'T'] : a >= 1e9 ? [1e9, 'B'] : a >= 1e6 ? [1e6, 'M'] : a >= 1e3 ? [1e3, 'K'] : [1, '']
  const n = v / unit
  return n.toFixed(Math.abs(n) >= 100 ? 0 : Math.abs(n) >= 10 ? 1 : 2) + suffix
}

function sparkline(history, w = 66, h = 20) {
  if (history.length < 2) return `<svg class="spark" width="${w}" height="${h}"></svg>`
  const min = Math.min(...history)
  const max = Math.max(...history)
  const mid = (max + min) / 2
  /*
   * A floor under the vertical scale, because pure auto-scaling turns nothing into drama:
   * USDC is pinned to a dollar, and stretching its hundredth-of-a-cent wobble to full height
   * drew a violent sawtooth on the calmest asset on the grid. Below a quarter percent of
   * range the line stays flat, which is what actually happened.
   */
  const span = Math.max(max - min, Math.abs(mid) * 0.0025) || 1
  const step = w / (history.length - 1)
  const d = history
    .map((v, i) => `${i ? 'L' : 'M'}${(i * step).toFixed(1)} ${(h / 2 - ((v - mid) / span) * h).toFixed(1)}`)
    .join('')
  const rising = history[history.length - 1] >= history[0]
  return `<svg class="spark" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" fill="none">
    <path d="${d}" stroke="${rising ? 'var(--up)' : 'var(--down)'}" stroke-width="1.25"
          stroke-linejoin="round" stroke-linecap="round"/></svg>`
}

// ── Views ──────────────────────────────────────────────────────────────────────
const marketView = document.querySelector('#view-market')
const tableView = document.querySelector('#view-table')
const chartView = document.querySelector('#view-chart')

function renderMarket() {
  marketView.innerHTML = `<div class="grid">${[...coins.values()].map(
    (c, i) => `
    <article class="cell" data-sym="${c.sym}" style="--d:${i * 22}ms" title="Open ${c.sym} in the chart">
      <span class="open" aria-hidden="true"></span>
      <div class="cell-head">
        <span class="sym">${c.sym}</span>
        <span class="name">${c.name}</span>
        <span class="rank">${String(c.rank).padStart(2, '0')}</span>
      </div>
      <div class="price" data-price>${money(c.price)}</div>
      <div class="cell-foot">
        <span class="delta ${c.delta >= 0 ? 'up' : 'down'}" data-delta>${pct(c.delta)}</span>
        <!-- The line and the percentage answer different questions: a month of direction
             beside a day of change. Left unlabelled they contradict each other on any coin
             that fell today inside a rising month. -->
        <span class="span">30D</span>
        <span data-spark>${sparkline(c.history)}</span>
      </div>
    </article>`,
  ).join('')}</div>`
}

function renderTable() {
  tableView.innerHTML = `<table class="tbl">
    <thead><tr>
      <th class="idx">#</th><th>Coin</th>
      <th class="num">Price</th><th class="num">24h</th><th class="num">Volume 24h</th>
    </tr></thead>
    <tbody>${[...coins.values()].map(
      (c, i) => `
      <tr data-sym="${c.sym}" style="--d:${i * 16}ms" title="Open ${c.sym} in the chart">
        <td class="idx">${String(c.rank).padStart(2, '0')}</td>
        <td><span class="coin"><span class="sym">${c.sym}</span><span class="name">${c.name}</span></span></td>
        <td class="num" data-price>${money(c.price)}</td>
        <td class="num delta ${c.delta >= 0 ? 'up' : 'down'}" data-delta>${pct(c.delta)}</td>
        <td class="num vol">${volume(c.vol)}</td>
      </tr>`,
    ).join('')}</tbody></table>`
}

// ── Chart ──────────────────────────────────────────────────────────────────────
/**
 * Each range maps to the coarsest candle that still fills the window with detail. A
 * fifteen-minute view on one-minute candles is fifteen points and looks like a sketch, so
 * it uses one-second candles instead — the shortest Binance publishes.
 */
const RANGES = {
  '15M': { interval: '1s', limit: 900 },
  '1H': { interval: '1m', limit: 60 },
  '24H': { interval: '15m', limit: 96 },
  '7D': { interval: '1h', limit: 168 },
  '30D': { interval: '4h', limit: 180 },
  '1Y': { interval: '1d', limit: 365 },
}

/**
 * How a moment is written depends on how much of it is on screen. A one-second candle needs
 * seconds to be identifiable; a daily candle reading "14:32" would be noise.
 */
const STAMP = {
  '15M': { hour: '2-digit', minute: '2-digit', second: '2-digit' },
  '1H': { hour: '2-digit', minute: '2-digit' },
  '24H': { hour: '2-digit', minute: '2-digit' },
  '7D': { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' },
  '30D': { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' },
  '1Y': { day: '2-digit', month: 'short', year: 'numeric' },
}
const stamp = (t) => new Date(t).toLocaleString('en-GB', STAMP[range]).replace(',', ' ·')

let selected = 'BTC'
let range = '24H'
let chartSeries = []
let chartLoading = false
/** Value-to-pixel mapping of the drawn plot, kept so the scrub can invert it. */
let plotGeom = null

function renderChart() {
  const c = coins.get(selected)
  chartView.innerHTML = `
    <div class="chart-wrap">
      <div class="chart-head">
        <div class="chart-price" data-chart-price>${money(c.price)}</div>
        <div class="chart-meta">
          <span class="chart-sym">${c.sym}</span>
          <span class="chart-name">${c.name}</span>
        </div>
        <span class="chart-delta ${c.delta >= 0 ? 'up' : 'down'}">${pct(c.delta)}</span>
        <div class="ranges">
          ${Object.keys(RANGES).map((r) => `<button data-range="${r}" class="${r === range ? 'on' : ''}">${r}</button>`).join('')}
        </div>
      </div>
      <div class="plot" data-plot>${chartLoading ? '<div class="plot-empty">LOADING</div>' : bigChart(chartSeries)}</div>
      <div class="picker">
        ${SYMBOLS.map((s) => `<button data-pick="${s}" class="${s === selected ? 'on' : ''}">${s}</button>`).join('')}
      </div>
      <div class="stats">
        ${STATS.map((s) => `
          <div class="stat">
            <span class="stat-k">${s.label}</span>
            <span class="stat-v" data-stat="${s.key}">—</span>
          </div>`).join('')}
      </div>
    </div>`
  paintStats(c)
}

/**
 * Six figures, and no more: the ones that change what you think about a coin you are
 * already looking at. Four of them are recomputed from the live price on every beat, so the
 * band is part of the quote rather than a static footnote under it.
 */
const STATS = [
  { key: 'cap', label: 'MARKET CAP' },
  { key: 'vol', label: '24H VOLUME' },
  { key: 'high', label: '24H HIGH' },
  { key: 'low', label: '24H LOW' },
  { key: 'supply', label: 'CIRCULATING' },
  { key: 'ath', label: 'FROM ATH' },
]

function paintStats(c) {
  const set = (key, text, tone) => {
    const el = chartView.querySelector(`[data-stat="${key}"]`)
    if (!el) return
    el.textContent = text
    el.classList.toggle('up', tone === 'up')
    el.classList.toggle('down', tone === 'down')
  }
  const cap = c.supply != null && c.price != null ? c.supply * c.price : null
  const fromAth = c.ath && c.price != null ? (c.price / c.ath - 1) * 100 : null

  set('cap', cap == null ? '—' : '$' + compact(cap))
  set('vol', c.vol ? '$' + compact(c.vol) : '—')
  set('high', c.high == null ? '—' : money(c.high))
  set('low', c.low == null ? '—' : money(c.low))
  set('supply', c.supply == null ? '—' : `${compact(c.supply)} ${c.sym}`)
  set('ath', fromAth == null ? '—' : pct(fromAth), fromAth == null ? null : fromAth >= 0 ? 'up' : 'down')
}

function bigChart(series, w = 1030, h = 300) {
  if (series.length < 2) { plotGeom = null; return '<div class="plot-empty">NO DATA</div>' }
  const closes = series.map((p) => p.c)
  const min = Math.min(...closes)
  const max = Math.max(...closes)
  const span = max - min || 1
  const step = w / (series.length - 1)
  const y = (v) => h - ((v - min) / span) * h
  plotGeom = { min, max, span, n: series.length }
  const line = closes.map((v, i) => `${i ? 'L' : 'M'}${(i * step).toFixed(1)} ${y(v).toFixed(1)}`).join('')
  const rising = closes[closes.length - 1] >= closes[0]
  const stroke = rising ? 'var(--up)' : 'var(--down)'
  // The line draws itself in, so switching coin or range reads as a redraw rather than a
  // swap — the eye follows the change instead of hunting for what moved.
  return `<svg viewBox="0 0 ${w} ${h}" width="100%" height="${h}" preserveAspectRatio="none" fill="none">
    <defs><linearGradient id="fade" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${stroke}" stop-opacity=".14"/>
      <stop offset="1" stop-color="${stroke}" stop-opacity="0"/>
    </linearGradient></defs>
    ${[0.25, 0.5, 0.75].map((f) => `<line x1="0" y1="${(h * f).toFixed(0)}" x2="${w}" y2="${(h * f).toFixed(0)}" stroke="var(--border)" stroke-width="1"/>`).join('')}
    <path d="${line}L${w} ${h}L0 ${h}Z" fill="url(#fade)" style="opacity:0;animation:fadeIn .7s .25s var(--ease) forwards"/>
    <path d="${line}" stroke="${stroke}" stroke-width="1.6" stroke-linejoin="round"
          pathLength="1" style="stroke-dasharray:1;stroke-dashoffset:1;animation:draw 1s var(--ease) forwards"/>
  </svg>
  <div class="plot-scale"><span>${money(max)}</span><span>${money(min)}</span></div>
  <div class="cross" data-cross hidden>
    <span class="cross-v"></span><span class="cross-h"></span><span class="cross-dot"></span>
    <div class="readout" data-readout></div>
  </div>
  <div class="plot-hint">HOLD AND DRAG TO INSPECT</div>
  <style>@keyframes draw{to{stroke-dashoffset:0}}@keyframes fadeIn{to{opacity:1}}</style>`
}

async function loadChart() {
  const { interval, limit } = RANGES[range]
  chartLoading = true
  renderChart()
  try {
    const res = await fetch(`${REST}/klines?symbol=${pair(selected)}&interval=${interval}&limit=${limit}`)
    const rows = await res.json()
    // Open time travels with the close price: without it the scrub could show a value but
    // never say when it happened, which is most of what the reading is for.
    chartSeries = Array.isArray(rows) ? rows.map((r) => ({ t: r[0], c: Number(r[4]) })) : []
  } catch {
    chartSeries = []
  }
  chartLoading = false
  renderChart()
}

// ── Chart scrubbing ────────────────────────────────────────────────────────────
/**
 * Press and drag reads the series back out: the moment under the cursor, the price there,
 * and how far it had moved from the start of the range by that point. The last part is the
 * reason to scrub at all — a price alone says nothing without something to measure it from.
 */
let scrubbing = false

function scrub(clientX) {
  const svg = chartView.querySelector('[data-plot] svg')
  const cross = chartView.querySelector('[data-cross]')
  if (!svg || !cross || !plotGeom || !chartSeries.length) return

  const box = svg.getBoundingClientRect()
  const t = Math.min(1, Math.max(0, (clientX - box.left) / box.width))
  const i = Math.round(t * (plotGeom.n - 1))
  const point = chartSeries[i]
  if (!point) return

  const x = (i / (plotGeom.n - 1)) * box.width
  const y = ((plotGeom.max - point.c) / plotGeom.span) * box.height
  const first = chartSeries[0].c
  const diff = point.c - first
  const share = first ? (diff / first) * 100 : 0
  const dir = diff >= 0 ? 'up' : 'down'

  cross.hidden = false
  cross.style.setProperty('--x', `${x}px`)
  cross.style.setProperty('--y', `${y}px`)
  // The panel flips away from the cursor near the edges so it is never clipped, and away
  // from the line vertically so it never covers the point it is describing.
  cross.classList.toggle('flip-x', t > 0.62)
  cross.classList.toggle('flip-y', y < box.height / 2)
  cross.querySelector('.cross-dot').dataset.dir = dir

  cross.querySelector('[data-readout]').innerHTML = `
    <div class="ro-time">${stamp(point.t)}</div>
    <div class="ro-price">${money(point.c)}</div>
    <div class="ro-delta ${dir}">${pct(share)} · ${moneyDiff(diff, point.c)}</div>
    <div class="ro-note">SINCE ${range} OPEN</div>`
}

chartView.addEventListener('pointerdown', (e) => {
  const plot = e.target.closest('[data-plot]')
  if (!plot || e.button !== 0 || !plotGeom) return
  scrubbing = true
  // Capture keeps the reading attached to the pointer even when it leaves the plot, so a
  // fast drag does not drop the panel mid-gesture. It is an enhancement, not a
  // prerequisite: without it the drag still tracks, so a refusal must not abort the read.
  try { plot.setPointerCapture(e.pointerId) } catch {}
  scrub(e.clientX)
  e.preventDefault()
})

chartView.addEventListener('pointermove', (e) => { if (scrubbing) scrub(e.clientX) })

function endScrub() {
  if (!scrubbing) return
  scrubbing = false
  const cross = chartView.querySelector('[data-cross]')
  if (cross) cross.hidden = true
}
chartView.addEventListener('pointerup', endScrub)
chartView.addEventListener('pointercancel', endScrub)

// ── Tabs ───────────────────────────────────────────────────────────────────────
const tabs = document.querySelector('#tabs')
const underline = document.querySelector('#underline')
const views = [...document.querySelectorAll('.view')]
const ORDER = ['market', 'chart', 'table']
let current = 'market'

function moveUnderline() {
  const active = tabs.querySelector('.tab.on')
  underline.style.width = `${active.offsetWidth}px`
  underline.style.transform = `translateX(${active.offsetLeft}px)`
}

function show(next) {
  if (next === current) return
  // Direction comes from the tab order, so a view always arrives from its own side.
  const forward = ORDER.indexOf(next) > ORDER.indexOf(current)
  for (const view of views) {
    view.style.setProperty('--enter', `${forward ? 20 : -20}px`)
    view.classList.toggle('on', view.dataset.view === next)
  }
  tabs.querySelectorAll('.tab').forEach((t) => t.classList.toggle('on', t.dataset.view === next))
  current = next
  moveUnderline()
  if (next === 'market') renderMarket()
  if (next === 'table') renderTable()
  if (next === 'chart') renderChart()
}

tabs.addEventListener('click', (e) => {
  const tab = e.target.closest('.tab')
  if (tab) show(tab.dataset.view)
})

// A coin — in either view — is a way into the chart; that is the only thing anyone wants
// from a price they have just noticed moving.
function openInChart(sym) {
  selected = sym
  show('chart')
  loadChart()
}

tableView.addEventListener('click', (e) => {
  const row = e.target.closest('tr[data-sym]')
  if (row) openInChart(row.dataset.sym)
})

marketView.addEventListener('click', (e) => {
  const cell = e.target.closest('.cell[data-sym]')
  if (cell) openInChart(cell.dataset.sym)
})

chartView.addEventListener('click', (e) => {
  const pick = e.target.closest('[data-pick]')
  if (pick && pick.dataset.pick !== selected) { selected = pick.dataset.pick; loadChart(); return }
  const r = e.target.closest('[data-range]')
  if (r && r.dataset.range !== range) { range = r.dataset.range; loadChart() }
})

// ── Live paint ─────────────────────────────────────────────────────────────────
/**
 * The socket runs at full speed; the screen commits on a ten-second beat.
 *
 * At fifty updates a second a price is a blur — legible as motion, useless as a number.
 * Holding the newest value and committing every ten seconds turns the same feed into
 * something readable, and it gives the flash a real meaning: it marks where a coin moved
 * over the last ten seconds, rather than announcing that a packet arrived.
 */
const BEAT_MS = 10_000
let streaming = true
let ticksThisSecond = 0

function commit() {
  if (!streaming) return
  for (const coin of coins.values()) {
    if (coin.price == null) continue
    // Direction and change are measured against what is currently on screen, not against
    // the previous message, so they describe the whole interval the user just watched.
    coin.changed = coin.shown != null && coin.price !== coin.shown
    coin.rising = coin.shown == null || coin.price >= coin.shown
    coin.shown = coin.price
    /*
     * The sparkline is a month of daily closes, and the last of those days is today — a
     * candle that has not closed yet. Overwriting its close with the live price extends the
     * month to this second without ever putting two different time bases on one line, which
     * is what an appended live sample would have done.
     */
    if (coin.history.length) coin.history[coin.history.length - 1] = coin.price
    paint(coin)
  }
  restartBeat()
}

function paint(coin) {
  if (!coin) return
  for (const root of [marketView, tableView]) {
    const node = root.querySelector(`[data-sym="${coin.sym}"]`)
    if (!node) continue
    const price = node.querySelector('[data-price]')
    if (price) price.textContent = money(coin.price)
    const delta = node.querySelector('[data-delta]')
    if (delta) {
      delta.textContent = pct(coin.delta)
      delta.classList.toggle('up', coin.delta >= 0)
      delta.classList.toggle('down', coin.delta < 0)
    }
    const vol = node.querySelector('.vol')
    if (vol) vol.textContent = volume(coin.vol)
    const spark = node.querySelector('[data-spark]')
    if (spark) spark.innerHTML = sparkline(coin.history)

    node.classList.remove('flash-up', 'flash-down')
    void node.offsetWidth // restart the flash instead of waiting for the current one
    // A coin that did not move must not flash: a flash on an unchanged number reads as
    // movement that never happened. Stablecoins sit still, and they should look it.
    if (coin.changed) node.classList.add(coin.rising ? 'flash-up' : 'flash-down')
  }
  if (current === 'chart' && coin.sym === selected) {
    const el = chartView.querySelector('[data-chart-price]')
    if (el) el.textContent = money(coin.price)
    paintStats(coin)
  }
}

// A hairline that fills across the beat, so the ten-second rhythm is visible rather than
// something the user has to infer from numbers that seem to have stopped.
const beatEl = document.querySelector('#beat i')
function restartBeat() {
  beatEl.style.animation = 'none'
  void beatEl.offsetWidth
  beatEl.style.animation = ''
}

// ── Connection ─────────────────────────────────────────────────────────────────
const statusEl = document.querySelector('#status')
const dotEl = document.querySelector('#livedot')
const rateEl = document.querySelector('#rate')

/** The indicator reports the socket, never an assumption: no stream, no LIVE. */
function setStatus(state) {
  statusEl.textContent = state
  dotEl.dataset.state = state
}

async function bootstrap() {
  setStatus('LOADING')
  const list = JSON.stringify(SYMBOLS.map(pair))
  try {
    const res = await fetch(`${REST}/ticker/24hr?symbols=${encodeURIComponent(list)}`)
    for (const row of await res.json()) {
      const sym = row.symbol.replace(/USDT$/, '')
      const coin = coins.get(sym)
      if (!coin) continue
      coin.price = Number(row.lastPrice)
      coin.delta = Number(row.priceChangePercent)
      coin.vol = Number(row.quoteVolume)
      coin.high = Number(row.highPrice)
      coin.low = Number(row.lowPrice)
    }
  } catch {
    setStatus('OFFLINE')
  }
  renderMarket()
  // A month of daily closes per coin. Seen twenty at a time the grid is not a tick display —
  // an hour of noise says nothing across twenty cards, while a month says which way each
  // coin has been going, which is the only question the grid can answer at a glance.
  await Promise.all(
    SYMBOLS.map(async (sym) => {
      try {
        const res = await fetch(`${REST}/klines?symbol=${pair(sym)}&interval=1d&limit=30`)
        const rows = await res.json()
        if (Array.isArray(rows)) coins.get(sym).history = rows.map((r) => Number(r[4]))
      } catch { /* a missing sparkline is not worth failing the load over */ }
    }),
  )
  commit()
  loadSupply()
}

/**
 * Supply and all-time high change on the scale of weeks; polling them hard would spend the
 * free tier's budget to watch numbers stand still. Fetched on load and refreshed rarely,
 * they are only the constants the live figures are computed against.
 */
async function loadSupply() {
  try {
    const res = await fetch(GECKO + Object.values(GECKO_IDS).join(','))
    if (!res.ok) return
    const byId = new Map((await res.json()).map((r) => [r.id, r]))
    for (const [sym, id] of Object.entries(GECKO_IDS)) {
      const row = byId.get(id)
      const coin = coins.get(sym)
      if (!row || !coin) continue
      coin.supply = row.circulating_supply
      coin.ath = row.ath
    }
    if (current === 'chart') paintStats(coins.get(selected))
  } catch { /* the band degrades to the figures Binance alone can answer */ }
}
setInterval(loadSupply, 15 * 60 * 1000)

let socket = null
let retry = 0

function connect() {
  // Two streams with different jobs: bookTicker moves fast enough to feel live, while
  // ticker carries the 24-hour change and volume that bookTicker does not include.
  const streams = SYMBOLS.flatMap((s) => [`${pair(s).toLowerCase()}@bookTicker`, `${pair(s).toLowerCase()}@ticker`]).join('/')
  setStatus(retry ? 'RECONNECTING' : 'CONNECTING')
  socket = new WebSocket(WS + streams)

  socket.onopen = () => { retry = 0; setStatus('LIVE') }

  socket.onmessage = (event) => {
    const msg = JSON.parse(event.data)
    const d = msg.data
    if (!d?.s) return
    const coin = coins.get(d.s.replace(/USDT$/, ''))
    if (!coin) return
    ticksThisSecond++

    // State absorbs every message; only the beat decides when any of it reaches the screen.
    if (d.b && d.a) {
      // Mid-price between best bid and ask: the number a quote screen shows between trades.
      coin.price = (Number(d.b) + Number(d.a)) / 2
    } else if (d.c) {
      coin.price = Number(d.c)
      coin.delta = Number(d.P)
      coin.vol = Number(d.q)
      coin.high = Number(d.h)
      coin.low = Number(d.l)
    }
  }

  socket.onclose = () => {
    setStatus('RECONNECTING')
    // Back off so a Binance-side outage is not hammered, but recover quickly from a blip.
    retry = Math.min(retry + 1, 5)
    setTimeout(connect, retry * 1200)
  }

  socket.onerror = () => { try { socket.close() } catch {} }
}

setInterval(commit, BEAT_MS)

setInterval(() => {
  // The rate still counts raw socket messages: it is the proof the connection is alive in
  // the nine seconds when nothing on screen is moving.
  rateEl.textContent = streaming ? `${ticksThisSecond}/s` : ''
  ticksThisSecond = 0
  beatEl.style.animationPlayState = streaming ? 'running' : 'paused'
  document.querySelector('#clock').textContent = new Date().toLocaleTimeString('en-GB')
}, 1000)

// ── Window controls ────────────────────────────────────────────────────────────
document.querySelector('#theme').addEventListener('click', () => {
  const next = document.documentElement.getAttribute('data-theme') === 'light' ? 'dark' : 'light'
  document.documentElement.setAttribute('data-theme', next)
})

const pauseBtn = document.querySelector('#ticking')
pauseBtn.addEventListener('click', () => {
  streaming = !streaming
  pauseBtn.classList.toggle('on', streaming)
  pauseBtn.textContent = streaming ? 'Pause stream' : 'Resume stream'
})

const splash = document.querySelector('#splash')
function runSplash() {
  splash.classList.remove('gone')
  requestAnimationFrame(() => splash.classList.add('load'))
  setTimeout(() => { splash.classList.add('gone'); splash.classList.remove('load') }, 2100)
}
document.querySelector('#replay').addEventListener('click', runSplash)

// ── Start ──────────────────────────────────────────────────────────────────────
document.documentElement.setAttribute('data-theme', 'dark')
renderMarket()
document.querySelector('#view-market').classList.add('on')
requestAnimationFrame(moveUnderline)
runSplash()
await bootstrap()
connect()
loadChart()

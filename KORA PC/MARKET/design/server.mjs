import { createServer } from 'node:http'
import { readFile } from 'node:fs/promises'
import { extname, join, normalize, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

// fileURLToPath rather than URL.pathname: on Windows the latter yields /C:/... with
// forward slashes, which never matches the backslashes path.join produces, and the
// containment check below would then reject every request.
const ROOT = resolve(fileURLToPath(new URL('.', import.meta.url)))
const PORT = 5182

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
}

createServer(async (req, res) => {
  const path = decodeURIComponent((req.url ?? '/').split('?')[0])
  const file = resolve(join(ROOT, normalize(path === '/' ? '/index.html' : path)))
  if (!file.startsWith(ROOT)) {
    res.writeHead(403).end('forbidden')
    return
  }
  try {
    const body = await readFile(file)
    res.writeHead(200, {
      'Content-Type': TYPES[extname(file)] ?? 'application/octet-stream',
      'Cache-Control': 'no-store',
    })
    res.end(body)
  } catch {
    res.writeHead(404).end('not found')
  }
}).listen(PORT, () => console.log(`market lab on http://localhost:${PORT}`))

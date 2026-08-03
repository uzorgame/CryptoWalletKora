/**
 * Installs the approved icon packs into every project.
 *
 * The packs ship Android and iOS assets only, so the three Windows .ico files are built
 * here from each pack's largest raster. One script, so a re-export of any pack can be
 * reinstalled the same way instead of by hand.
 */
import { cp, mkdir, readdir, writeFile, stat } from 'node:fs/promises'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import sharp from 'sharp'
import pngToIco from 'png-to-ico'

// The approved packs live beside this script rather than in a temp folder, so reinstalling
// never depends on something that gets cleaned up.
const PACKS = resolve(fileURLToPath(new URL('./packs', import.meta.url)))
const W = 'C:/Work/Wallet'

const log = []

async function exists(p) {
  try { await stat(p); return true } catch { return false }
}

/** Android: mipmap folders wholesale, but only the one file we own inside values/. */
async function android(pack, projectRes) {
  const src = join(PACKS, pack, 'android')
  for (const entry of await readdir(src, { withFileTypes: true })) {
    if (!entry.isDirectory() || !entry.name.startsWith('mipmap')) continue
    await cp(join(src, entry.name), join(projectRes, entry.name), { recursive: true, force: true })
    log.push(`android ${entry.name}`)
  }
  // values/ also holds colors.xml and styles.xml, which are not ours to replace.
  const bg = join(src, 'values/ic_launcher_background.xml')
  if (await exists(bg)) {
    await cp(bg, join(projectRes, 'values/ic_launcher_background.xml'), { force: true })
    log.push('android values/ic_launcher_background.xml')
  }
}

async function ios(pack, appIconSet) {
  const src = join(PACKS, pack, 'ios/AppIcon.appiconset')
  if (!(await exists(src)) || !(await exists(appIconSet))) { log.push('ios skipped'); return }
  await cp(src, appIconSet, { recursive: true, force: true })
  log.push(`ios AppIcon.appiconset (${(await readdir(src)).length} files)`)
}

/** Windows wants a multi-resolution .ico; the packs stop at PNG. */
async function ico(pack, destination) {
  const source = join(PACKS, pack, 'android/playstore-icon.png')
  const sizes = [16, 24, 32, 48, 64, 128, 256]
  const frames = await Promise.all(
    sizes.map((s) =>
      sharp(source).resize(s, s, { fit: 'contain', kernel: 'lanczos3' }).png().toBuffer(),
    ),
  )
  await mkdir(dirname(destination), { recursive: true })
  await writeFile(destination, await pngToIco(frames))
  log.push(`ico ${destination.replace(W + '/', '')} (${sizes.join(', ')})`)
}

// Wallet — the mobile app and the Windows wallet.
//
// These paths were left pointing at kora/ and kora_windows/, which stopped existing when the
// repository was reorganised into 'KORA Mobile' and 'KORA PC'. Nothing failed loudly: the
// script was simply never run again, so the Windows wallet kept whatever .ico had been copied
// there last — which was Market's chart mark, not its own.
await android('wallet', join(W, 'KORA Mobile/android/app/src/main/res'))
await ios('wallet', join(W, 'KORA Mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset'))
await ico('wallet', join(W, 'KORA PC/WALLET/windows/runner/resources/app_icon.ico'))

// Market — Windows only; it has no mobile build.
await ico('market', join(W, 'KORA PC/MARKET/windows/runner/resources/app_icon.ico'))

// Installer — its own mark, so a setup file never looks like the installed app.
await ico('installer', join(W, 'KORA PC/WALLET/windows/runner/resources/installer_icon.ico'))

console.log(log.map((l) => '  ' + l).join('\n'))
console.log(`\n${log.length} steps completed`)

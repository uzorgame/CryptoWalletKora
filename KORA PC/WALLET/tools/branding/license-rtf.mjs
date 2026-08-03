// Turns the plain-text policy into RTF carrying its own colour.
//
// The installer's licence box is a rich edit control. Inno loads a .txt into it as plain
// text, and plain text has no colour of its own — it renders in the control's default
// character format, which is black. Setting TRichEditViewer.Font.Color from [Code] afterwards
// does not reach text that is already loaded, so on the #0A0A0A wizard page the whole policy
// came out black on near-black and was unreadable.
//
// RTF carries a colour table, and the control honours it. That makes legibility a property of
// the document rather than of a repaint pass that happens to run at the right moment.
//
// Usage:  node tools/branding/license-rtf.mjs
// Reads:  privacy_policy.txt          Writes: privacy_policy.rtf

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const source = join(root, 'privacy_policy.txt');
const target = join(root, 'privacy_policy.rtf');

/** RTF reserves three characters, and anything above ASCII needs a numeric escape. */
function escape(line) {
  let out = '';
  for (const ch of line) {
    const code = ch.codePointAt(0);
    if (ch === '\\' || ch === '{' || ch === '}') out += '\\' + ch;
    else if (code < 128) out += ch;
    // \uN? — N as a signed 16-bit value, with an ASCII fallback for readers that ignore it.
    else if (code <= 0xffff) out += `\\u${code > 32767 ? code - 65536 : code}?`;
    else out += '?';
  }
  return out;
}

const text = readFileSync(source, 'utf8').replace(/\r\n/g, '\n').replace(/\n$/, '');

// Colour 1 is #F0F0F0, the same ink the rest of the wizard uses. The leading semicolon is
// required: index 0 in an RTF colour table means "auto", and is not a colour.
const rtf = [
  '{\\rtf1\\ansi\\ansicpg1252\\deff0',
  '{\\fonttbl{\\f0\\fmodern\\fcharset0 Consolas;}}',
  '{\\colortbl ;\\red240\\green240\\blue240;}',
  '\\viewkind4\\uc1\\pard\\cf1\\f0\\fs16',
  ...text.split('\n').map((line) => escape(line) + '\\par'),
  '}',
  '',
].join('\n');

writeFileSync(target, rtf, 'ascii');
console.log(`privacy_policy.rtf — ${text.split('\n').length} lines, ${rtf.length} bytes`);

// Runs in CI after every build step, on every deploy (including the hourly
// article-refresh cron), so it has to stay cheap: no browser, just checks
// the files that are about to be uploaded to Pages. Catches the class of
// bug verify-css.mjs doesn't: a page that got truncated, a link or image
// pointing at a path that doesn't exist in the build output, or JSON-LD
// that no longer parses -- all things that (like the empty-CSS incident)
// would otherwise ship silently because nothing here makes the build step
// itself fail.
//
// Scope excludes crm/ and its assets -- that is a separate system this
// script has no business inspecting, let alone failing a deploy over.

import { readFile, stat } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();

const PAGES = [
  ['index.html', 3000],
  ['portal/index.html', 3000],
  ['review/index.html', 3000],
  ['adminupload/index.html', 3000],
  ['program/downloader/index.html', 3000],
  ['businesscard/index.html', 3000],
  ['businesscard.ttt/index.html', 3000],
  ['404.html', 1000],
];
let ok = true;
const fail = (msg) => { console.error(`✗ ${msg}`); ok = false; };

function extractLocalPaths(html, attr) {
  const re = new RegExp(`${attr}="([^"]+)"`, 'g');
  const found = [];
  let m;
  while ((m = re.exec(html))) {
    const v = m[1];
    if (/^(https?:)?\/\//.test(v) || v.startsWith('mailto:') || v.startsWith('tel:') || v.startsWith('#') || v.startsWith('data:') || v.startsWith('javascript:')) continue;
    if (v.startsWith('/crm')) continue;
    // Not a literal path -- a JS template-literal placeholder (this attribute
    // is being built at runtime inside a `<script>` string), which can't be
    // checked statically.
    if (v.includes('${')) continue;
    found.push(v.split('#')[0].split('?')[0]);
  }
  return found;
}

function resolveLocalPath(p) {
  if (p === '') return null;
  const clean = p.startsWith('/') ? p.slice(1) : p;
  if (clean === '') return ROOT;
  return path.join(ROOT, clean);
}

// A bare directory reference (e.g. "/portal") maps to portal/index.html on
// GitHub Pages; anything with a file extension must exist exactly as named.
function localPathExists(p) {
  const resolved = resolveLocalPath(p);
  if (!resolved) return true;
  if (existsSync(resolved)) return true;
  if (!path.extname(resolved) && existsSync(path.join(resolved, 'index.html'))) return true;
  return false;
}

for (const [page, minBytes] of PAGES) {
  const full = path.join(ROOT, page);
  if (!existsSync(full)) {
    fail(`${page}: expected output file is missing`);
    continue;
  }
  const st = await stat(full);
  if (st.size < minBytes) {
    fail(`${page}: only ${st.size} bytes (expected at least ${minBytes}) -- looks truncated`);
    continue;
  }
  const html = await readFile(full, 'utf8');

  for (const href of extractLocalPaths(html, 'href')) {
    if (!localPathExists(href)) fail(`${page}: <a>/<link> points at "${href}", which doesn't exist in the build output`);
  }
  for (const src of extractLocalPaths(html, 'src')) {
    if (!localPathExists(src)) fail(`${page}: an <img>/<script> src points at "${src}", which doesn't exist in the build output`);
  }

  for (const ldMatch of html.matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g)) {
    try {
      JSON.parse(ldMatch[1]);
    } catch (e) {
      fail(`${page}: JSON-LD block does not parse: ${e.message}`);
    }
  }
}

if (ok) {
  console.log(`✓ verified ${PAGES.length} page(s): sizes look right, internal links/images resolve, JSON-LD parses`);
} else {
  console.error('\nBuild verification failed -- aborting deploy rather than shipping a broken page.');
  process.exit(1);
}

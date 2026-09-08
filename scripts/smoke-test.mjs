// Runs in CI only on pushes/manual runs, not the hourly article-refresh
// cron (see deploy.yml) -- it needs a real browser, which is too slow and
// wasteful to install ~24 times a day just to notice nothing code-related
// changed. scripts/verify-css.mjs and scripts/verify-build.mjs cover the
// cheap, no-browser checks that DO run on every deploy.
//
// This checks the things only a real browser can: nothing throws while a
// page loads, and the handful of interactions that broke silently before
// in this project (a click-only drop zone with no keyboard path, a lock
// overlay that never received focus) stay fixed.
//
// Expects a static file server for the built site already running at
// SMOKE_TEST_BASE_URL (defaults to http://localhost:8080).

import { chromium } from 'playwright';

const BASE = process.env.SMOKE_TEST_BASE_URL || 'http://localhost:8080';
let ok = true;
const fail = (msg) => { console.error(`✗ ${msg}`); ok = false; };
const pass = (msg) => console.log(`✓ ${msg}`);

const browser = await chromium.launch();

// Browser-level "couldn't fetch this resource" complaints are connectivity
// noise, not a code bug -- a flaky CDN shouldn't fail the whole deploy. The
// two ReferenceErrors are what every page throws next as a direct
// consequence (the Supabase SDK script tag didn't load, so neither global
// it sets ever gets defined) -- still a network symptom, not a first-party
// bug, so they're excluded too. Anything else still fails the check.
const isNetworkNoise = (text) =>
  /^Failed to load resource: net::/.test(text) ||
  /ReferenceError: (supabase|dcbcSupabase) is not defined/.test(text);

async function newPage() {
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  const errors = [];
  page.on('console', (msg) => { if (msg.type() === 'error' && !isNetworkNoise(msg.text())) errors.push(msg.text()); });
  page.on('pageerror', (err) => { const text = String(err); if (!isNetworkNoise(text)) errors.push(text); });
  return { page, errors };
}

// 1. Every page loads without a console/page error.
const PAGES = [
  '/index.html',
  '/portal/index.html',
  '/review/index.html',
  '/adminupload/index.html',
  '/program/downloader/index.html',
  '/businesscard/index.html',
  '/businesscard.ttt/index.html',
  '/articles/index.html',
];
for (const path of PAGES) {
  const { page, errors } = await newPage();
  await page.goto(BASE + path, { waitUntil: 'networkidle' });
  if (errors.length === 0) pass(`${path} loads with no console errors`);
  else fail(`${path} logged console errors: ${JSON.stringify(errors)}`);
  await page.close();
}

// 2. adminupload: the file-upload drop zone must be reachable and
// operable from the keyboard, not just a mouse click target.
{
  const { page } = await newPage();
  await page.goto(BASE + '/adminupload/index.html', { waitUntil: 'networkidle' });
  const result = await page.evaluate(() => {
    const zone = document.getElementById('drop-zone');
    const input = document.getElementById('admin-file');
    if (!zone || !input) return { ok: false, reason: 'drop-zone or admin-file missing from the page' };
    let clicked = false;
    input.addEventListener('click', () => { clicked = true; });
    zone.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true, cancelable: true }));
    return { ok: clicked && zone.getAttribute('role') === 'button' && zone.getAttribute('tabindex') === '0' };
  });
  if (result.ok) pass('adminupload #drop-zone is keyboard-operable (Enter opens the file picker)');
  else fail('adminupload #drop-zone keyboard access regressed: ' + JSON.stringify(result));
  await page.close();
}

// 3. portal + adminupload: the login overlay is a real dialog and grabs
// focus, instead of leaving keyboard users to tab past it into the page.
for (const [path, overlayId, expectedFocusId] of [
  ['/portal/index.html', 'portal-lock-overlay', 'portal-lock-code'],
  ['/adminupload/index.html', 'admin-lock-overlay', 'admin-lock-email'],
]) {
  const { page } = await newPage();
  await page.goto(BASE + path, { waitUntil: 'networkidle' });
  const result = await page.evaluate(({ overlayId, expectedFocusId }) => {
    const overlay = document.getElementById(overlayId);
    return {
      role: overlay?.getAttribute('role'),
      ariaModal: overlay?.getAttribute('aria-modal'),
      focused: document.activeElement?.id === expectedFocusId,
    };
  }, { overlayId, expectedFocusId });
  if (result.role === 'dialog' && result.ariaModal === 'true' && result.focused) {
    pass(`${path}: lock overlay has dialog semantics and starting focus`);
  } else {
    fail(`${path}: lock overlay regressed: ${JSON.stringify(result)}`);
  }
  await page.close();
}

// 4. homepage: the LINE/Facebook contact cards must be real links, not
// click-handler-only <div>s search engines and keyboard users can't reach.
{
  const { page } = await newPage();
  await page.goto(BASE + '/index.html', { waitUntil: 'networkidle' });
  const hasLine = await page.locator('a[href="https://line.me/R/ti/p/@dcbc"]').count();
  const hasFb = await page.locator('a[href*="facebook.com/profile.php?id=61576885766816"]').count();
  if (hasLine > 0 && hasFb > 0) pass('homepage LINE/Facebook contact cards are real <a href> links');
  else fail(`homepage contact links regressed: line=${hasLine} fb=${hasFb}`);
  await page.close();
}

// 5. businesscard: the language switch buttons toggle aria-pressed.
{
  const { page } = await newPage();
  await page.goto(BASE + '/businesscard/index.html', { waitUntil: 'networkidle' });
  await page.click('button[data-lang="en"]');
  const result = await page.evaluate(() => ({
    th: document.querySelector('button[data-lang="th"]')?.getAttribute('aria-pressed'),
    en: document.querySelector('button[data-lang="en"]')?.getAttribute('aria-pressed'),
  }));
  if (result.th === 'false' && result.en === 'true') pass('businesscard language switch toggles aria-pressed correctly');
  else fail('businesscard aria-pressed regressed: ' + JSON.stringify(result));
  await page.close();
}

await browser.close();

if (ok) {
  console.log('\n=== SMOKE TEST PASSED ===');
} else {
  console.error('\n=== SMOKE TEST FAILED -- aborting deploy ===');
  process.exit(1);
}

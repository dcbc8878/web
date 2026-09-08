// Runs in CI right after the Tailwind build step. Tailwind's CLI exits 0
// even when its content-scanning config can't find the pages it's meant to
// scan, and just silently emits the base reset with none of the utility
// classes -- that shipped a near-empty stylesheet to production once (see
// the comment at the top of tailwind.site.js for the full story). This
// makes that failure loud instead of silent: it checks the freshly-built
// site.css/card.css for both a minimum size and a handful of utility
// classes that can only be present if the real pages were actually
// scanned, and fails the build if either check comes up short.

import { readFile } from 'node:fs/promises';

const CHECKS = [
  { file: 'site.css', minBytes: 15000, mustContain: ['.flex{', '.bg-brand{', '.rounded-3xl{'] },
  { file: 'card.css', minBytes: 4000, mustContain: ['.flex{', '.bg-brand{'] },
];

let ok = true;

for (const { file, minBytes, mustContain } of CHECKS) {
  const css = await readFile(file, 'utf8');
  if (css.length < minBytes) {
    console.error(`✗ ${file} is only ${css.length} bytes (expected at least ${minBytes}) -- looks like the Tailwind content scan matched few or no files`);
    ok = false;
  }
  const missing = mustContain.filter((selector) => !css.includes(selector));
  if (missing.length > 0) {
    console.error(`✗ ${file} is missing expected selector(s): ${missing.join(', ')} -- utility classes are not being generated`);
    ok = false;
  }
  if (css.length >= minBytes && missing.length === 0) {
    console.log(`✓ ${file}: ${css.length} bytes, all expected selectors present`);
  }
}

if (!ok) {
  console.error('\nCSS build verification failed -- aborting deploy rather than shipping a broken stylesheet.');
  process.exit(1);
}

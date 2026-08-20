// Runs in CI after the Tailwind build step, in the checked-out workspace
// only — never committed back to the repo.
//
// The compiled stylesheets were linked as separate files
// (<link rel="stylesheet" href="/site.css?v=1">), but something about how
// GitHub Pages served those two specific root-level .css files stayed
// broken across multiple deploys and cache-busted URLs even though the
// files themselves were verified byte-correct in the repository and in
// the deployed HTML's markup, and requests for them came back HTTP 200.
// Rather than keep chasing that (unreproducible outside the live
// environment), this sidesteps it entirely: paste the CSS directly into
// each page's <head> as a <style> block. Whatever was special about
// serving a standalone /site.css or /card.css no longer matters, because
// there's no longer a separate request for it — the styling rides inside
// the same HTML response already confirmed to load correctly.
//
// Source files keep the <link> tag (readable diffs, works for local
// preview via `npx tailwindcss@3 ...`); only the CI-built copies that
// actually get deployed are rewritten here.

import { readFile, writeFile } from 'node:fs/promises';

const SITE_TARGETS = [
    'index.html',
    'portal/index.html',
    'review/index.html',
    'adminupload/index.html',
    'program/downloader/index.html',
];
const CARD_TARGETS = [
    'businesscard/index.html',
    'businesscard.ttt/index.html',
];

function linkPattern(href) {
    // Matches the exact <link> tag regardless of the ?v= cache-bust value,
    // so bumping the version later doesn't silently break this script.
    const escaped = href.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    return new RegExp(`<link rel="stylesheet" href="${escaped}(?:\\?v=\\d+)?">`);
}

async function inline(target, cssPath, hrefToReplace) {
    const [html, css] = await Promise.all([readFile(target, 'utf8'), readFile(cssPath, 'utf8')]);
    const pattern = linkPattern(hrefToReplace);
    if (!pattern.test(html)) {
        throw new Error(`${target}: expected <link> tag for ${hrefToReplace} not found — inlining would silently no-op`);
    }
    const inlined = html.replace(pattern, () => `<style>\n${css}\n</style>`);
    await writeFile(target, inlined, 'utf8');
    console.log(`  ✓ inlined ${cssPath} into ${target}`);
}

async function main() {
    console.log(`Inlining site.css into ${SITE_TARGETS.length} page(s)`);
    for (const target of SITE_TARGETS) {
        await inline(target, 'site.css', '/site.css');
    }
    console.log(`Inlining card.css into ${CARD_TARGETS.length} page(s)`);
    for (const target of CARD_TARGETS) {
        await inline(target, 'card.css', '/card.css');
    }
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});

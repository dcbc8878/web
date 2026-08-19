// Build config for the main site pages. They pull the Tailwind Play CDN,
// which is JavaScript: it has to download, run and scan the DOM before the
// page has any styling at all, so on a phone the page painted white and
// unstyled first — the same problem already fixed for the two business-card
// pages (see tailwind.cards.js) via a compiled stylesheet instead.
//
// The output (site.css) is committed so it's always present at deploy time,
// but CI also rebuilds and overwrites it fresh on every deploy (see
// .github/workflows/deploy.yml) so a forgotten manual rebuild never ships
// stale. Regenerate it locally after changing Tailwind classes on any of
// the pages below so local previews and diffs stay accurate:
//   npx tailwindcss@3 -c scripts/tailwind.site.js -i scripts/tailwind.site.in.css -o site.css --minify
//
// The theme below must stay in step with what the pages used to declare
// inline; nothing else reads it. supabase-client.js and build-articles.mjs
// are included because they generate markup with Tailwind classes at
// runtime (document/review lists, article pages) — the classes only exist
// as literal strings in those files, never assembled from pieces, so the
// content scanner below finds them the same way it finds classes in HTML.
module.exports = {
  content: [
    '/home/user/web/index.html',
    '/home/user/web/portal/index.html',
    '/home/user/web/review/index.html',
    '/home/user/web/adminupload/index.html',
    '/home/user/web/program/downloader/index.html',
    '/home/user/web/supabase-client.js',
    '/home/user/web/scripts/build-articles.mjs',
  ],
  theme: {
    extend: {
      fontFamily: { sans: ['Prompt', 'sans-serif'] },
      colors: { brand: { light: '#FFF2E8', DEFAULT: '#FFB88C', dark: '#E5976A', text: '#4A4A4A' } },
    },
  },
};

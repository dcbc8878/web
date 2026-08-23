// Build config for the two business-card pages. They used to pull the
// Tailwind Play CDN, which is JavaScript: on a real phone the page paints
// white and unstyled until it downloads, executes and scans the DOM — the
// visible flash when moving between the two cards. This produces a plain
// stylesheet instead, so the first frame is already right.
//
// The output (card.css) is committed so it's always present at deploy time,
// but CI also rebuilds and overwrites it fresh on every deploy (see
// .github/workflows/deploy.yml) so a forgotten manual rebuild never ships
// stale. Regenerate it after changing either card's markup so local
// previews and diffs stay accurate:
//   npx tailwindcss@3 -c scripts/tailwind.cards.js -i scripts/tailwind.cards.in.css -o card.css --minify
//
// content paths are resolved from THIS FILE's location (via __dirname), not
// a hardcoded machine-specific path — see tailwind.site.js for why: an
// absolute path baked in from one developer's checkout matches nothing on
// any other machine (including every CI runner), so Tailwind silently
// scans zero files and ships only the base reset. __dirname always points
// at this file's real location on disk, so it works wherever the repo is
// checked out.
//
// The theme below must stay in step with what the pages used to declare
// inline; nothing else reads it.
const path = require('node:path');
const root = (...segments) => path.join(__dirname, '..', ...segments);

module.exports = {
  content: [
    root('businesscard/index.html'),
    root('businesscard.ttt/index.html'),
  ],
  theme: {
    extend: {
      fontFamily: { sans: ['Prompt', 'Noto Sans SC', 'PingFang SC', 'Microsoft YaHei', 'sans-serif'] },
      colors: { brand: { light: '#FFF2E8', DEFAULT: '#FFB88C', dark: '#E5976A', text: '#4A4A4A' } },
    },
  },
};

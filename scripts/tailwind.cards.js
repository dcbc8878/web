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
// The theme below must stay in step with what the pages used to declare
// inline; nothing else reads it.
module.exports = {
  content: [
    '/home/user/web/businesscard/index.html',
    '/home/user/web/businesscard.ttt/index.html',
  ],
  theme: {
    extend: {
      fontFamily: { sans: ['Prompt', 'Noto Sans SC', 'PingFang SC', 'Microsoft YaHei', 'sans-serif'] },
      colors: { brand: { light: '#FFF2E8', DEFAULT: '#FFB88C', dark: '#E5976A', text: '#4A4A4A' } },
    },
  },
};

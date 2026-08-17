// Generates static article pages from the Supabase `articles` table.
//
// Runs in CI before the Pages artifact is uploaded, so the published
// output is plain HTML. That matters: most AI crawlers (GPTBot,
// ClaudeBot, PerplexityBot) do not execute JavaScript, so an article
// that only renders client-side is invisible to exactly the audience
// this blog exists to reach.
//
// Nothing is committed back to the repo — files are written into the
// working tree and picked up by the upload-pages-artifact step.

import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

const SUPABASE_URL = 'https://dqegkyobclqqichhnxfm.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_4U_v9BIrQjKppfchaevA6Q_zWj3zkxE';
const SITE_URL = 'https://www.dcbc.co.th';
const OUT_ROOT = process.cwd();

const escapeHtml = (s) =>
    String(s ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');

const escapeAttr = escapeHtml;

// Minimal markdown subset. Everything is escaped first, so article text
// can never inject markup — the only tags present are the ones added here.
// `label` (an article slug) is only used to make the console warning below
// useful when this runs unattended in CI across many articles.
function renderContent(raw, label) {
    const lines = String(raw ?? '').replace(/\r\n/g, '\n').split('\n');
    const out = [];
    let listOpen = false;
    let paragraph = [];

    const flushParagraph = () => {
        if (!paragraph.length) return;
        out.push(`<p>${inline(paragraph.join(' '))}</p>`);
        paragraph = [];
    };
    const closeList = () => {
        if (listOpen) { out.push('</ul>'); listOpen = false; }
    };

    for (const line of lines) {
        const t = line.trim();

        if (!t) { flushParagraph(); closeList(); continue; }

        // Block image on its own line: ![คำบรรยาย](url)
        // Only http(s) is allowed through, so a javascript: or data: URL
        // pasted into the editor can never become a live src.
        const image = t.match(/^!\[([^\]]*)\]\(\s*([^)\s]+)\s*\)$/);
        if (image) {
            flushParagraph(); closeList();
            const [, alt, url] = image;
            if (/^https?:\/\//i.test(url)) {
                out.push(
                    `<figure>` +
                    `<img src="${escapeAttr(url)}" alt="${escapeAttr(alt)}" loading="lazy">` +
                    (alt ? `<figcaption>${escapeHtml(alt)}</figcaption>` : '') +
                    `</figure>`
                );
            } else {
                // Rather than silently vanishing (the only trace being a CI
                // log line nobody who writes articles ever sees), leave a
                // visible marker in the published page itself.
                console.error(`⚠ [${label || 'unknown'}] Dropping image with non-http(s) URL: ${JSON.stringify(url)}`);
                out.push(`<p class="text-red-500">[รูปภาพไม่แสดง: ลิงก์ต้องขึ้นต้นด้วย https:// — ${escapeHtml(url)}]</p>`);
            }
            continue;
        }

        const heading = t.match(/^(#{2,3})\s+(.*)$/);
        if (heading) {
            flushParagraph(); closeList();
            const level = heading[1].length; // ## -> h2, ### -> h3
            out.push(`<h${level}>${inline(heading[2])}</h${level}>`);
            continue;
        }

        const bullet = t.match(/^[-*]\s+(.*)$/);
        if (bullet) {
            flushParagraph();
            if (!listOpen) { out.push('<ul>'); listOpen = true; }
            out.push(`<li>${inline(bullet[1])}</li>`);
            continue;
        }

        closeList();
        paragraph.push(t);
    }
    flushParagraph();
    closeList();
    return out.join('\n');
}

// Inline formatting, applied to already-escaped text.
function inline(text) {
    let s = escapeHtml(text);
    s = s.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    s = s.replace(
        /(https?:\/\/[^\s<]+)/g,
        '<a href="$1" target="_blank" rel="noopener" class="text-brand hover:underline break-all">$1</a>'
    );
    return s;
}

const publicUrl = (bucket, path) =>
    `${SUPABASE_URL}/storage/v1/object/public/${bucket}/${path}`;

const thaiDate = (iso) =>
    iso
        ? new Date(iso).toLocaleDateString('th-TH', { year: 'numeric', month: 'long', day: 'numeric' })
        : '';

function layout({ title, description, canonical, head = '', body }) {
    return `<!DOCTYPE html>
<html lang="th" class="scroll-smooth">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="${escapeAttr(description)}">
    <title>${escapeHtml(title)}</title>
    <link rel="canonical" href="${escapeAttr(canonical)}">
    <link rel="icon" type="image/png" sizes="32x32" href="/favicon-32.png">
    <link rel="icon" type="image/png" sizes="16x16" href="/favicon-16.png">
    <link rel="apple-touch-icon" sizes="180x180" href="/favicon-180.png">
    <link rel="shortcut icon" href="/favicon.ico">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Prompt:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <!-- Compiled Tailwind stylesheet, rebuilt fresh on every deploy (see
         scripts/tailwind.site.js) — not the Play CDN, which is JavaScript
         that has to download, run and scan the DOM before the page has any
         styling, producing a flash of unstyled content on first load. -->
    <link rel="stylesheet" href="/site.css">
    <style>
        ::-webkit-scrollbar { width: 8px; }
        ::-webkit-scrollbar-track { background: #f1f1f1; }
        ::-webkit-scrollbar-thumb { background: #FFB88C; border-radius: 10px; }
        ::-webkit-scrollbar-thumb:hover { background: #E5976A; }
        .article-body h2 { font-size: 1.5rem; font-weight: 700; color: #111827; margin: 2rem 0 0.75rem; }
        .article-body h3 { font-size: 1.2rem; font-weight: 600; color: #1f2937; margin: 1.5rem 0 0.5rem; }
        .article-body p { margin-bottom: 1.1rem; line-height: 1.9; color: #4b5563; font-weight: 300; }
        .article-body ul { margin: 0 0 1.1rem 1.25rem; list-style: disc; }
        .article-body li { margin-bottom: 0.5rem; line-height: 1.8; color: #4b5563; font-weight: 300; }
        .article-body strong { font-weight: 600; color: #1f2937; }
        .article-body figure { margin: 1.75rem 0; }
        .article-body figure img { width: 100%; height: auto; border-radius: 1rem; display: block; }
        .article-body figcaption { margin-top: 0.6rem; font-size: 0.8rem; color: #9ca3af; text-align: center; font-weight: 300; }
    </style>
${head}
</head>
<body class="text-brand-text bg-white antialiased flex flex-col min-h-screen">

    <nav class="w-full bg-brand-light/90 backdrop-blur-md z-50 border-b border-brand-light sticky top-0">
        <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="flex justify-between items-center h-20">
                <a href="/" class="flex items-center gap-2">
                    <img src="/logo.png" alt="เด็กชายบัญชี" class="h-12 w-12 object-contain">
                    <span class="font-bold text-2xl tracking-tight text-gray-800">เด็กชายบัญชี</span>
                </a>
                <div class="flex items-center gap-5 text-sm">
                    <a href="/articles" class="text-gray-600 hover:text-brand font-medium hidden sm:inline">บทความ</a>
                    <a href="/" class="text-brand font-medium hover:underline flex items-center gap-2">
                        <i class="fa-solid fa-arrow-left"></i> กลับหน้าหลัก
                    </a>
                </div>
            </div>
        </div>
    </nav>

${body}

    <footer class="bg-gray-800 text-white py-12 border-t border-gray-700 mt-auto">
        <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-8 mb-8 pb-8 border-b border-gray-700">
                <div>
                    <div class="flex items-center gap-3 mb-4">
                        <img src="/logo.png" alt="เด็กชายบัญชี" class="w-9 h-9 object-contain">
                        <span class="font-bold text-xl tracking-tight">บริษัท เด็กชายบัญชี จำกัด</span>
                    </div>
                    <p class="text-gray-400 text-sm font-light mb-2">DEKCHAIBUNCHEE CO.,LTD.</p>
                    <p class="text-brand text-sm font-medium"><i class="fa-solid fa-id-card mr-2"></i>เลขประจำตัวผู้เสียภาษีอากร: 0555569000181</p>
                </div>
                <div class="md:text-right">
                    <h5 class="text-white font-semibold mb-3">ติดต่อเรา</h5>
                    <p class="text-gray-400 text-sm font-light leading-relaxed">
                        โทร. <a href="tel:0888788648" class="hover:text-brand">088-878-8648</a><br>
                        <a href="mailto:contact@dcbc.co.th" class="hover:text-brand">contact@dcbc.co.th</a><br>
                        เลขที่ 2 ซอยทุ่งเศรษฐี แยก 21<br>แขวงดอกไม้ เขตประเวศ กรุงเทพมหานคร 10250
                    </p>
                </div>
            </div>
            <div class="flex flex-col sm:flex-row justify-between items-center gap-4 text-xs text-gray-500 font-light">
                <p>&copy; 2026 บริษัท เด็กชายบัญชี จำกัด. All Rights Reserved.</p>
                <div class="flex gap-4">
                    <a href="mailto:contact@dcbc.co.th" aria-label="อีเมล" class="hover:text-brand transition-colors"><i class="fa-regular fa-envelope text-base"></i></a>
                    <a href="https://www.dcbc.co.th" class="hover:text-brand transition-colors"><i class="fa-solid fa-globe text-base"></i></a>
                    <a href="https://line.me/R/ti/p/@dcbc" target="_blank" rel="noopener" class="hover:text-brand transition-colors"><i class="fa-brands fa-line text-base"></i></a>
                    <a href="https://www.facebook.com/profile.php?id=61576885766816" target="_blank" rel="noopener" aria-label="Facebook" class="hover:text-brand transition-colors"><i class="fa-brands fa-facebook text-base"></i></a>
                </div>
            </div>
        </div>
    </footer>
</body>
</html>
`;
}

function articlePage(a) {
    const url = `${SITE_URL}/articles/${a.slug}`;
    const cover = a.cover_path ? publicUrl('article-images', a.cover_path) : null;
    const description = a.excerpt || String(a.content).slice(0, 150);

    const jsonLd = {
        '@context': 'https://schema.org',
        '@type': 'BlogPosting',
        headline: a.title,
        description,
        datePublished: a.published_at || a.created_at,
        dateModified: a.updated_at || a.published_at || a.created_at,
        mainEntityOfPage: { '@type': 'WebPage', '@id': url },
        author: { '@type': 'Organization', name: 'บริษัท เด็กชายบัญชี จำกัด' },
        publisher: {
            '@type': 'Organization',
            name: 'บริษัท เด็กชายบัญชี จำกัด',
            logo: { '@type': 'ImageObject', url: `${SITE_URL}/logo.png` }
        },
        ...(cover ? { image: cover } : {})
    };

    const head = `    <meta property="og:type" content="article">
    <meta property="og:title" content="${escapeAttr(a.title)}">
    <meta property="og:description" content="${escapeAttr(description)}">
    <meta property="og:url" content="${escapeAttr(url)}">
${cover ? `    <meta property="og:image" content="${escapeAttr(cover)}">\n` : ''}    <script type="application/ld+json">
${JSON.stringify(jsonLd, null, 2)}
    </script>`;

    const body = `    <main class="flex-grow bg-brand-light/30 py-10 md:py-16">
        <article class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="bg-white rounded-3xl shadow-[0_10px_35px_rgb(255,184,140,0.12)] border border-gray-100 overflow-hidden">
${cover ? `                <img src="${escapeAttr(cover)}" alt="${escapeAttr(a.title)}" class="w-full h-56 md:h-72 object-cover">\n` : ''}                <div class="p-7 md:p-10">
                    <a href="/articles" class="text-xs text-brand font-medium hover:underline inline-flex items-center gap-1.5 mb-4">
                        <i class="fa-solid fa-arrow-left text-[10px]"></i> บทความทั้งหมด
                    </a>
                    <h1 class="text-2xl md:text-3xl font-bold text-gray-900 leading-snug mb-3">${escapeHtml(a.title)}</h1>
                    <p class="text-xs text-gray-400 font-light mb-7">
                        <i class="fa-regular fa-calendar mr-1"></i>เผยแพร่เมื่อ ${escapeHtml(thaiDate(a.published_at || a.created_at))}
                    </p>
                    <div class="article-body">
${renderContent(a.content, a.slug)}
                    </div>
${a.source_url ? `                    <p class="mt-8 pt-5 border-t border-gray-100 text-xs text-gray-400 font-light">
                        โพสต์ต้นฉบับ: <a href="${escapeAttr(a.source_url)}" target="_blank" rel="noopener" class="text-brand hover:underline">ดูบน Facebook</a>
                    </p>\n` : ''}                </div>
            </div>

            <div class="bg-white rounded-3xl border border-brand/20 p-7 md:p-8 mt-6 text-center">
                <h2 class="text-lg font-bold text-gray-900 mb-2">มีคำถามเรื่องบัญชีหรือภาษี?</h2>
                <p class="text-sm text-gray-500 font-light mb-5">ทีมงานเด็กชายบัญชียินดีให้คำปรึกษา</p>
                <div class="flex flex-col sm:flex-row justify-center gap-3">
                    <a href="/#contact" class="px-6 py-3 bg-brand text-white rounded-xl font-medium hover:bg-brand-dark transition-colors text-sm">ฝากข้อมูลติดต่อกลับ</a>
                    <a href="https://line.me/R/ti/p/@dcbc" target="_blank" rel="noopener" class="px-6 py-3 bg-white text-brand border border-brand rounded-xl font-medium hover:bg-brand-light transition-colors text-sm">
                        <i class="fa-brands fa-line"></i> ทักไลน์ @dcbc
                    </a>
                </div>
            </div>
        </article>
    </main>`;

    return layout({
        title: `${a.title} | เด็กชายบัญชี`,
        description,
        canonical: url,
        head,
        body
    });
}

function listingPage(articles) {
    const cards = articles.length
        ? articles.map((a) => {
              const cover = a.cover_path ? publicUrl('article-images', a.cover_path) : null;
              return `                <a href="/articles/${escapeAttr(a.slug)}" class="bg-white rounded-3xl border border-gray-100 shadow-sm hover:shadow-md transition-all overflow-hidden flex flex-col group">
${cover
                      ? `                    <img src="${escapeAttr(cover)}" alt="${escapeAttr(a.title)}" class="w-full h-44 object-cover">`
                      : `                    <div class="w-full h-44 bg-brand-light flex items-center justify-center text-brand text-4xl"><i class="fa-regular fa-newspaper"></i></div>`}
                    <div class="p-6 flex flex-col flex-grow">
                        <h2 class="font-bold text-gray-900 text-base leading-snug mb-2 group-hover:text-brand transition-colors">${escapeHtml(a.title)}</h2>
                        <p class="text-sm text-gray-500 font-light leading-relaxed flex-grow">${escapeHtml(a.excerpt || '')}</p>
                        <p class="text-xs text-gray-400 font-light mt-4">
                            <i class="fa-regular fa-calendar mr-1"></i>${escapeHtml(thaiDate(a.published_at || a.created_at))}
                        </p>
                    </div>
                </a>`;
          }).join('\n')
        : `                <div class="col-span-full bg-white rounded-3xl border border-gray-100 p-14 text-center">
                    <i class="fa-regular fa-newspaper text-4xl text-gray-300 mb-3"></i>
                    <p class="text-gray-500 text-sm font-medium">ยังไม่มีบทความในขณะนี้</p>
                    <p class="text-xs text-gray-400 font-light mt-1">ติดตามความรู้เรื่องบัญชีและภาษีได้เร็วๆ นี้</p>
                </div>`;

    const body = `    <main class="flex-grow bg-brand-light/30 py-12 md:py-16">
        <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="text-center mb-10">
                <div class="inline-block p-4 bg-brand-light rounded-2xl mb-4 text-brand">
                    <i class="fa-regular fa-newspaper text-3xl"></i>
                </div>
                <h1 class="text-3xl md:text-4xl font-bold text-gray-900">บทความความรู้</h1>
                <p class="mt-3 text-base text-gray-600 font-light">เรื่องบัญชี ภาษี และการทำธุรกิจ ที่ผู้ประกอบการควรรู้</p>
            </div>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
${cards}
            </div>
        </div>
    </main>`;

    return layout({
        title: 'บทความความรู้บัญชีและภาษี | เด็กชายบัญชี',
        description: 'รวมบทความความรู้เรื่องบัญชี ภาษี และการทำธุรกิจ จากบริษัท เด็กชายบัญชี จำกัด สำนักงานบัญชีในกรุงเทพมหานคร',
        canonical: `${SITE_URL}/articles`,
        body
    });
}

function sitemapXml(articles) {
    const urls = [
        { loc: `${SITE_URL}/`, priority: '1.0' },
        { loc: `${SITE_URL}/articles`, priority: '0.8' },
        { loc: `${SITE_URL}/portal`, priority: '0.6' },
        { loc: `${SITE_URL}/review`, priority: '0.5' },
        ...articles.map((a) => ({
            loc: `${SITE_URL}/articles/${a.slug}`,
            priority: '0.7',
            lastmod: (a.updated_at || a.published_at || a.created_at || '').slice(0, 10)
        }))
    ];

    return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls
    .map(
        (u) => `  <url>
    <loc>${u.loc}</loc>${u.lastmod ? `\n    <lastmod>${u.lastmod}</lastmod>` : ''}
    <changefreq>monthly</changefreq>
    <priority>${u.priority}</priority>
  </url>`
    )
    .join('\n')}
</urlset>
`;
}

async function fetchArticles() {
    const res = await fetch(
        `${SUPABASE_URL}/rest/v1/articles?is_published=eq.true&select=*&order=published_at.desc.nullslast,created_at.desc`,
        { headers: { apikey: SUPABASE_ANON_KEY, Authorization: `Bearer ${SUPABASE_ANON_KEY}` } }
    );
    if (!res.ok) {
        throw new Error(`Supabase returned ${res.status}: ${await res.text()}`);
    }
    return res.json();
}

async function main() {
    let articles = [];
    try {
        articles = await fetchArticles();
    } catch (err) {
        // A fetch failure must not take the whole site deploy down with it —
        // the rest of the pages are static and unaffected.
        console.error(`⚠ Could not load articles, publishing an empty list: ${err.message}`);
    }

    // Filtered once, up front, and reused everywhere below — otherwise the
    // listing page and sitemap can advertise a link to an article whose
    // page generation was skipped for a bad slug, which then 404s.
    const validArticles = articles.filter((a) => {
        const ok = a.slug && /^[a-z0-9-]+$/i.test(a.slug);
        if (!ok) console.error(`⚠ Skipping article with unusable slug: ${JSON.stringify(a.slug)}`);
        return ok;
    });

    console.log(`Building ${validArticles.length} article page(s)`);

    await mkdir(join(OUT_ROOT, 'articles'), { recursive: true });
    await writeFile(join(OUT_ROOT, 'articles', 'index.html'), listingPage(validArticles), 'utf8');

    for (const a of validArticles) {
        const dir = join(OUT_ROOT, 'articles', a.slug);
        await mkdir(dir, { recursive: true });
        await writeFile(join(dir, 'index.html'), articlePage(a), 'utf8');
        console.log(`  ✓ /articles/${a.slug}`);
    }

    await writeFile(join(OUT_ROOT, 'sitemap.xml'), sitemapXml(validArticles), 'utf8');
    console.log('  ✓ sitemap.xml');
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});

# บริษัท เด็กชายบัญชี จำกัด — เว็บไซต์

เว็บไซต์ static (HTML / Tailwind (compiled) / JavaScript) สำหรับโดเมน **www.dcbc.co.th**
ใช้ Supabase เป็นฐานข้อมูลและที่เก็บไฟล์

ตอน deploy ทุกครั้ง มี 2 อย่างที่ถูกสร้างขึ้นอัตโนมัติ (ไม่ต้องทำเอง ไม่ commit เข้า repo):
1. `site.css` / `card.css` — คอมไพล์จาก Tailwind (ดู `scripts/tailwind.site.js` และ
   `scripts/tailwind.cards.js`) แทนที่จะโหลด Tailwind CDN ซึ่งเป็น JavaScript ที่ทำให้
   หน้าขาวๆ แวบก่อนสไตล์จะขึ้น
2. `articles/` + `sitemap.xml` — `scripts/build-articles.mjs` ดึงบทความจาก Supabase มา
   สร้างเป็นหน้า HTML จริงไว้ล่วงหน้า (`/articles`, `/articles/<slug>`)

ไฟล์ HTML/JS อื่นๆ ทั้งหมดแก้ตรงๆ ได้เลย ไม่ต้อง build

## 📁 โครงสร้างไฟล์

ทุกหน้าใช้ URL แบบ **ไม่มี .html** โดยวางไฟล์เป็น `<ชื่อ>/index.html`

```
web/
├── index.html                    หน้าหลัก           → /
├── portal/index.html             ระบบเอกสารลูกค้า    → /portal
├── review/index.html             ฟอร์มส่งรีวิว        → /review
├── adminupload/index.html        ระบบจัดการหลังบ้าน   → /adminupload
├── program/downloader/index.html หน้าดาวน์โหลดโปรแกรม → /program/downloader
├── articles/                     หน้าบทความ → /articles — **สร้างอัตโนมัติตอน deploy อย่าแก้ไฟล์ในนี้ตรงๆ**
├── scripts/build-articles.mjs    สคริปต์ที่สร้างโฟลเดอร์ articles/ กับ sitemap.xml จากตาราง Supabase
├── scripts/tailwind.site.js      Tailwind config ของหน้าเว็บหลัก (index/portal/review/adminupload/downloader) → คอมไพล์เป็น site.css
├── scripts/tailwind.cards.js     Tailwind config ของหน้านามบัตร → คอมไพล์เป็น card.css
├── site.css / card.css           **ไม่ commit เข้า repo** สร้างอัตโนมัติตอน deploy จาก config ด้านบน
├── supabase-client.js            Supabase client + helper ที่ใช้ร่วมกันทุกหน้า
├── supabase-migration.sql        สคริปต์สร้างตาราง/policy (รันใน Supabase SQL Editor)
├── APP_UPDATE_API.md             เอกสาร API ตรวจสอบอัปเดตสำหรับตัวโปรแกรม
├── logo.png                      โลโก้บริษัท
├── favicon-*.png / favicon.ico   ไอคอนเว็บ
├── 404.html                      หน้าเมื่อไม่พบ URL (GitHub Pages บังคับชื่อนี้ที่ root)
├── CNAME                         ระบุโดเมน www.dcbc.co.th
├── robots.txt / sitemap.xml      สำหรับ search engine (sitemap.xml ถูกเขียนทับทุก deploy โดย build-articles.mjs)
├── .nojekyll                     ปิดการประมวลผล Jekyll
└── .github/workflows/deploy.yml  สร้าง site.css/card.css + articles/ แล้ว deploy ขึ้น GitHub Pages อัตโนมัติ ทุก push และทุกชั่วโมง
```

> **เพิ่มหน้าใหม่ในอนาคต:** สร้างเป็นโฟลเดอร์ `ชื่อหน้า/index.html` เสมอ ไม่ใช่ `ชื่อหน้า.html`
> และภายในไฟล์ให้อ้าง asset แบบ root-absolute (`/logo.png`, `/supabase-client.js`)
> เพราะไฟล์อยู่ลึกลงไปหนึ่งชั้น

## 🖥️ ดูเว็บบนเครื่อง (Local Preview)

หน้าส่วนใหญ่ (ที่ยังไม่ได้แก้ class ใหม่) ดูได้เลยโดยไม่ต้อง build:

```bash
python3 -m http.server 8000
# แล้วเปิด http://localhost:8000
```

ถ้าเพิ่ง**แก้ class ของ Tailwind ในหน้าไหน** ต้องสร้าง `site.css` / `card.css` ก่อน
(ไฟล์นี้ไม่ได้ commit เข้า repo ถูกสร้างอัตโนมัติเฉพาะตอน deploy):

```bash
npx tailwindcss@3 -c scripts/tailwind.site.js -i scripts/tailwind.site.in.css -o site.css --minify
npx tailwindcss@3 -c scripts/tailwind.cards.js -i scripts/tailwind.cards.in.css -o card.css --minify
```

## 🗄️ Supabase

ตาราง (ทุกตารางเปิด Row Level Security):

| ตาราง | ใช้ทำอะไร |
|---|---|
| `documents` | คลังเอกสารให้ลูกค้าดาวน์โหลด เรียงลำดับเองได้ด้วย `sort_order` |
| `reviews` | รีวิวลูกค้า ต้องผ่านการอนุมัติก่อนขึ้นเว็บ (ต้องมีอย่างน้อย 5 รายการ) |
| `portal_codes` | รหัส 4 หลักสำหรับเข้าหน้า /portal |
| `app_releases` | เวอร์ชันของโปรแกรมช่วยดาวน์โหลด |
| `articles` | บทความ — เนื้อหาต้นฉบับ (`scripts/build-articles.mjs` สร้างเป็นหน้า HTML จริงตอน deploy) |
| `admin_users` / `admin_invites` | บัญชีและสิทธิ์สำหรับเข้า /adminupload |

Storage buckets (ตั้งเป็น Public ทั้งหมด): `documents`, `review-logos`, `app-releases`, `article-images`

ฟังก์ชันที่เรียกได้จากภายนอก:
- `check_portal_code(input_code)` → คืน true/false เท่านั้น ไม่เปิดเผยรายการรหัส
- `get_portal_documents(input_code)` → คืนรายการเอกสารจริง เฉพาะเมื่อรหัสถูกต้อง (นี่คือสิ่งที่ล็อกหน้า /portal จริงๆ ไม่ใช่แค่หน้าจอกรอกรหัส)
- `get_latest_app_release()` → คืนเวอร์ชันล่าสุดเป็น JSON (ดู `APP_UPDATE_API.md`)

**การแก้ไขฐานข้อมูล:** แก้ที่ `supabase-migration.sql` แล้วรันทั้งไฟล์ใน Supabase SQL Editor
สคริปต์เขียนให้รันซ้ำได้ปลอดภัย (policy ทุกตัว drop ก่อน create)

## 🔒 หน้าแอดมิน

`/adminupload` ใช้ **Supabase Auth จริง** (อีเมล + รหัสผ่าน) ไม่ใช่รหัสผ่านฝังในหน้าเว็บ
บัญชีแอดมินสร้างจาก Supabase Dashboard → Authentication → Users

> **สำคัญ:** ต้องปิด "Allow new users to sign up" ใน Auth settings
> ไม่อย่างนั้นใครก็สมัครบัญชีเองแล้วเข้าหลังบ้านได้

แท็บในหน้าแอดมิน: เอกสาร · รีวิว · รหัสลูกค้า · โปรแกรม · บทความ · ผู้ใช้ (แท็บ "ผู้ใช้" เห็นเฉพาะเจ้าของระบบ)

## ✉️ ฟอร์มติดต่อ

ฟอร์มติดต่อในหน้าแรกส่งเข้าอีเมล **contact@dcbc.co.th** ผ่าน [FormSubmit](https://formsubmit.co)
ส่วนฟอร์มรีวิวบันทึกลง Supabase เป็นหลัก และส่งอีเมลแจ้งเตือนควบคู่ไปด้วย

## 🚀 Deploy

push ขึ้น branch แล้ว workflow `deploy.yml` จะ deploy ขึ้น GitHub Pages อัตโนมัติ

DNS ที่ตั้งไว้แล้ว:

```
CNAME   www   dcbc8878.github.io.
A       @     185.199.108.153
A       @     185.199.109.153
A       @     185.199.110.153
A       @     185.199.111.153
```

---

สร้างด้วย HTML/Tailwind (compiled)/JS — deploy อัตโนมัติสร้าง CSS + หน้าบทความให้ แก้ไขและดูแลง่าย

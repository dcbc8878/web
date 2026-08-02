# บริษัท เด็กชายบัญชี จำกัด — เว็บไซต์

เว็บไซต์ static (HTML / Tailwind CDN / JavaScript) สำหรับโดเมน **www.dcbc.co.th**
ใช้ Supabase เป็นฐานข้อมูลและที่เก็บไฟล์ ไม่มี build step

## 📁 โครงสร้างไฟล์

ทุกหน้าใช้ URL แบบ **ไม่มี .html** โดยวางไฟล์เป็น `<ชื่อ>/index.html`

```
web/
├── index.html                    หน้าหลัก           → /
├── portal/index.html             ระบบเอกสารลูกค้า    → /portal
├── review/index.html             ฟอร์มส่งรีวิว        → /review
├── adminupload/index.html        ระบบจัดการหลังบ้าน   → /adminupload
├── program/downloader/index.html หน้าดาวน์โหลดโปรแกรม → /program/downloader
├── supabase-client.js            Supabase client + helper ที่ใช้ร่วมกันทุกหน้า
├── supabase-migration.sql        สคริปต์สร้างตาราง/policy (รันใน Supabase SQL Editor)
├── APP_UPDATE_API.md             เอกสาร API ตรวจสอบอัปเดตสำหรับตัวโปรแกรม
├── logo.png                      โลโก้บริษัท
├── favicon-*.png / favicon.ico   ไอคอนเว็บ
├── 404.html                      หน้าเมื่อไม่พบ URL (GitHub Pages บังคับชื่อนี้ที่ root)
├── CNAME                         ระบุโดเมน www.dcbc.co.th
├── robots.txt / sitemap.xml      สำหรับ search engine
├── .nojekyll                     ปิดการประมวลผล Jekyll
└── .github/workflows/deploy.yml  Deploy อัตโนมัติขึ้น GitHub Pages
```

> **เพิ่มหน้าใหม่ในอนาคต:** สร้างเป็นโฟลเดอร์ `ชื่อหน้า/index.html` เสมอ ไม่ใช่ `ชื่อหน้า.html`
> และภายในไฟล์ให้อ้าง asset แบบ root-absolute (`/logo.png`, `/supabase-client.js`)
> เพราะไฟล์อยู่ลึกลงไปหนึ่งชั้น

## 🖥️ ดูเว็บบนเครื่อง (Local Preview)

```bash
python3 -m http.server 8000
# แล้วเปิด http://localhost:8000
```

## 🗄️ Supabase

ตาราง (ทุกตารางเปิด Row Level Security):

| ตาราง | ใช้ทำอะไร |
|---|---|
| `documents` | คลังเอกสารให้ลูกค้าดาวน์โหลด เรียงลำดับเองได้ด้วย `sort_order` |
| `reviews` | รีวิวลูกค้า ต้องผ่านการอนุมัติก่อนขึ้นเว็บ (ต้องมีอย่างน้อย 5 รายการ) |
| `portal_codes` | รหัส 4 หลักสำหรับเข้าหน้า /portal |
| `app_releases` | เวอร์ชันของโปรแกรมช่วยดาวน์โหลด |

Storage buckets (ตั้งเป็น Public ทั้งหมด): `documents`, `review-logos`, `app-releases`

ฟังก์ชันที่เรียกได้จากภายนอก:
- `check_portal_code(input_code)` → คืน true/false เท่านั้น ไม่เปิดเผยรายการรหัส
- `get_latest_app_release()` → คืนเวอร์ชันล่าสุดเป็น JSON (ดู `APP_UPDATE_API.md`)

**การแก้ไขฐานข้อมูล:** แก้ที่ `supabase-migration.sql` แล้วรันทั้งไฟล์ใน Supabase SQL Editor
สคริปต์เขียนให้รันซ้ำได้ปลอดภัย (policy ทุกตัว drop ก่อน create)

## 🔒 หน้าแอดมิน

`/adminupload` ใช้ **Supabase Auth จริง** (อีเมล + รหัสผ่าน) ไม่ใช่รหัสผ่านฝังในหน้าเว็บ
บัญชีแอดมินสร้างจาก Supabase Dashboard → Authentication → Users

> **สำคัญ:** ต้องปิด "Allow new users to sign up" ใน Auth settings
> ไม่อย่างนั้นใครก็สมัครบัญชีเองแล้วเข้าหลังบ้านได้

แท็บในหน้าแอดมิน: เอกสาร · รีวิว · รหัสลูกค้า · โปรแกรม

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

สร้างด้วย HTML/Tailwind CDN/JS — ไม่มี build step แก้ไขและดูแลง่าย

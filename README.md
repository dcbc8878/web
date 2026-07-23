# DCBC — เว็บไซต์บริษัท

เว็บไซต์ static (HTML / CSS / JavaScript) สำหรับโดเมน **dcbc.co.th**
ออกแบบให้โหลดเร็ว รองรับมือถือ (responsive) มีโหมดมืด (dark mode) อัตโนมัติ
และรองรับ SEO เบื้องต้น

## 📁 โครงสร้างไฟล์

```
web/
├── index.html          หน้าหลักของเว็บไซต์
├── styles.css          สไตล์ทั้งหมด (responsive + dark mode)
├── script.js           เมนูมือถือ + เอฟเฟกต์ scroll
├── 404.html            หน้าเมื่อไม่พบ URL
├── CNAME               ระบุโดเมน dcbc.co.th (สำหรับ GitHub Pages)
├── robots.txt          กติกาสำหรับ search engine
├── sitemap.xml         แผนผังเว็บไซต์
├── .nojekyll           ปิดการประมวลผล Jekyll บน GitHub Pages
└── .github/workflows/
    └── deploy.yml      Deploy อัตโนมัติขึ้น GitHub Pages
```

## 🖥️ ดูเว็บบนเครื่อง (Local Preview)

เปิดไฟล์ `index.html` ด้วยเบราว์เซอร์ได้เลย หรือรันเซิร์ฟเวอร์เล็ก ๆ:

```bash
# ถ้ามี Python
python3 -m http.server 8000
# แล้วเปิด http://localhost:8000
```

## ✏️ วิธีแก้ไขเนื้อหา

เนื้อหาทั้งหมดเป็นข้อความปกติในไฟล์ `index.html` แก้ได้ตรง ๆ ส่วนที่ควรปรับให้เป็นข้อมูลจริง:

| จุดที่ต้องแก้ | อยู่ตรงไหน |
|---|---|
| ชื่อบริษัท / โลโก้ | ค้นหา `DCBC` |
| ข้อความ hero / บริการ | ส่วน `<section class="hero">`, `#services` |
| อีเมล / เบอร์โทร / ที่อยู่ | ส่วน `#contact` และ footer |
| ตัวเลขสถิติ | `<dl class="hero-stats">` |
| สีแบรนด์ | ตัวแปร `--brand` ใน `styles.css` |

> **ฟอร์มติดต่อ:** ตอนนี้ตั้งค่าให้ส่งผ่าน [FormSubmit](https://formsubmit.co) ไปที่ `info@dcbc.co.th`
> ครั้งแรกต้องยืนยันอีเมลก่อนใช้งาน หรือจะเปลี่ยนไปใช้บริการอื่น (Formspree, Google Forms) ก็ได้

## 🚀 นำขึ้นโดเมน dcbc.co.th

ไฟล์ `CNAME` ตั้งค่าไว้ให้แล้ว รองรับหลายวิธี เลือกอย่างใดอย่างหนึ่ง:

### ตัวเลือก A — GitHub Pages (ฟรี, ตั้งค่าไว้แล้ว)

1. Push โค้ดขึ้น GitHub (branch นี้)
2. ไปที่ **Settings → Pages** ของ repo
   - Source: เลือก **GitHub Actions** (workflow `deploy.yml` จะ deploy อัตโนมัติ)
   - Custom domain: ใส่ `dcbc.co.th` แล้วกด Save
3. ตั้งค่า DNS ที่ผู้ให้บริการโดเมน (.co.th มักเป็น T.H.NIC / ผู้รับจดในไทย):

   **แบบ apex domain (dcbc.co.th):** สร้าง A records ชี้ไปที่ IP ของ GitHub Pages
   ```
   A   @   185.199.108.153
   A   @   185.199.109.153
   A   @   185.199.110.153
   A   @   185.199.111.153
   ```
   **แบบ www:**
   ```
   CNAME   www   <username>.github.io.
   ```
4. รอ DNS propagate (ไม่กี่นาที–24 ชม.) แล้วเปิด **Enforce HTTPS** ใน Settings → Pages

### ตัวเลือก B — Cloudflare Pages / Netlify / Vercel

1. เชื่อม repo กับบริการที่เลือก
2. Build command: *(ไม่ต้องมี)* — Output directory: `/` (root)
3. เพิ่ม custom domain `dcbc.co.th` ในแดชบอร์ด แล้วทำตามคำแนะนำ DNS ที่ระบบให้มา

### ตัวเลือก C — โฮสติ้งทั่วไป (cPanel / FTP)

อัปโหลดไฟล์ทั้งหมดในโฟลเดอร์นี้ไปที่ `public_html/` ของโฮสต์ที่ผูกกับ dcbc.co.th ได้เลย
(ไฟล์ `CNAME`, `.nojekyll`, `.github/` ไม่จำเป็นสำหรับวิธีนี้ จะลบออกก็ได้)

## 📝 หมายเหตุเรื่องโดเมน .co.th

โดเมน `.co.th` จดทะเบียนผ่าน **T.H.NIC** และต้องมีเอกสารนิติบุคคล (เช่น หนังสือรับรองบริษัท
หรือเครื่องหมายการค้า) การตั้งค่า DNS ทำได้ที่หน้าจัดการโดเมนของผู้รับจดที่คุณใช้บริการ

---

สร้างด้วย HTML/CSS/JS ล้วน ไม่มี dependency — แก้ไขและดูแลง่าย

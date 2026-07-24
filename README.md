# บริษัท เด็กชายบัญชี จำกัด — เว็บไซต์

เว็บไซต์ static (HTML / Tailwind CDN / JavaScript) สำหรับโดเมน **www.dcbc.co.th**
รองรับมือถือ (responsive) มีโหมดมืดอัตโนมัติ ฟอนต์ Prompt ตามคู่มือแบรนด์

## 📁 โครงสร้างไฟล์

```
web/
├── index.html          หน้าหลัก (บริการ, รีวิว, ฟอร์มติดต่อ)
├── portal.html          ระบบเอกสารลูกค้า (ดาวน์โหลดฟอร์ม + อัปโหลดเอกสาร)
├── review.html          ฟอร์มให้ลูกค้าส่งรีวิว
├── adminupload.html      หน้าอัปโหลดเอกสารของแอดมิน (มีรหัสผ่านป้องกัน)
├── logo.jpg             โลโก้บริษัท
├── 404.html             หน้าเมื่อไม่พบ URL
├── CNAME                ระบุโดเมน www.dcbc.co.th (สำหรับ GitHub Pages)
├── robots.txt           กติกาสำหรับ search engine
├── sitemap.xml          แผนผังเว็บไซต์
├── .nojekyll            ปิดการประมวลผล Jekyll บน GitHub Pages
└── .github/workflows/
    └── deploy.yml       Deploy อัตโนมัติขึ้น GitHub Pages
```

## 🖥️ ดูเว็บบนเครื่อง (Local Preview)

```bash
python3 -m http.server 8000
# แล้วเปิด http://localhost:8000
```

## ✉️ ฟอร์มต่างๆ

ฟอร์มทั้ง 3 จุด (ติดต่อในหน้าแรก, อัปโหลดเอกสารใน portal.html, รีวิวใน review.html,
และอัปโหลดของแอดมิน) ส่งเข้าอีเมล **contact@dcbc.co.th** ผ่านบริการ [FormSubmit](https://formsubmit.co)
(ฟรี ไม่ต้องมี backend)

> **สำคัญ:** การส่งฟอร์มครั้งแรกหลัง deploy จะมีอีเมลยืนยัน (one-time activation)
> ส่งไปที่ `contact@dcbc.co.th` ต้องกดยืนยันในอีเมลนั้นก่อน ฟอร์มถึงจะส่งข้อมูลมาถึงจริง

## 🔒 หน้าแอดมิน

`adminupload.html` มีหน้าจอถามรหัสผ่านก่อนเข้าใช้งาน (ป้องกันแบบพื้นฐาน ไม่ใช่ระบบความปลอดภัยระดับสูง)
รหัสผ่านตั้งต้น: `dekchai2026` — แก้ไขได้ที่ตัวแปร `ADMIN_PANEL_PASSWORD` ในไฟล์ `adminupload.html`

## 🚀 นำขึ้นโดเมน www.dcbc.co.th

ไฟล์ `CNAME` ตั้งค่าเป็น `www.dcbc.co.th` ไว้แล้ว ใช้ GitHub Pages (ฟรี):

1. **เปิด GitHub Pages:** ไปที่ repo → **Settings → Pages**
   - Source: เลือก **GitHub Actions** (workflow `deploy.yml` จะ deploy อัตโนมัติทุกครั้งที่ push)
   - Custom domain: ใส่ `www.dcbc.co.th` แล้วกด Save

2. **ตั้งค่า DNS** ที่หน้าจัดการโดเมนของผู้รับจด `.co.th` (เช่น T.H.NIC หรือผู้ให้บริการที่คุณจดไว้):

   **Record สำหรับ www (โดเมนหลักที่จะใช้งานจริง):**
   ```
   CNAME   www   dcbc8878.github.io.
   ```

   **Record สำหรับ apex/root (dcbc.co.th ไม่มี www)** — ใส่ไว้ด้วยเพื่อให้ GitHub Pages
   รีไดเรกต์จาก `dcbc.co.th` ไป `www.dcbc.co.th` ให้อัตโนมัติ:
   ```
   A   @   185.199.108.153
   A   @   185.199.109.153
   A   @   185.199.110.153
   A   @   185.199.111.153
   ```

3. รอ DNS propagate (ปกติไม่กี่นาที บางที่นานถึง 24 ชม.)

4. กลับไปที่ **Settings → Pages** อีกครั้ง รอสถานะ DNS ขึ้นเป็นถูกต้อง (✓) แล้วเปิด
   **Enforce HTTPS** เพื่อบังคับใช้ HTTPS

## 📝 หมายเหตุเรื่องโดเมน .co.th

โดเมน `.co.th` จดทะเบียนผ่าน **T.H.NIC** และต้องมีเอกสารนิติบุคคล (เช่น หนังสือรับรองบริษัท)
การตั้งค่า DNS ทำได้ที่หน้าจัดการโดเมนของผู้รับจดที่คุณใช้บริการอยู่

---

สร้างด้วย HTML/Tailwind CDN/JS — ไม่มี build step แก้ไขและดูแลง่าย

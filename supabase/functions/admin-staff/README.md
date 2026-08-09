# admin-staff Edge Function — วิธี Deploy

ฟังก์ชันนี้ทำ 2 อย่างที่ต้องใช้สิทธิ์ระดับแอดมิน (service role) ซึ่ง**ห้ามฝังไว้ในเว็บที่เปิดในเบราว์เซอร์**:

1. `create` — สร้างพนักงานใหม่ (สร้างบัญชี login + รหัสผ่านเริ่มต้น `1234`)
2. `reset` — รีเซ็ทรหัสผ่านพนักงานคนอื่นกลับเป็น `1234`

ทั้งสองอย่างตรวจสิทธิ์คนเรียกใหม่ที่ฝั่งเซิร์ฟเวอร์เสมอ (ไม่เชื่อ role ที่ส่งมาจากเว็บ)

## วิธี Deploy (ผ่าน Supabase Dashboard เท่านั้น ไม่ต้องใช้ CLI)

1. เข้า [Supabase Dashboard](https://supabase.com/dashboard) → เลือกโปรเจกต์ CRM
2. เมนูซ้าย → **Edge Functions**
3. กด **Create a new function**
4. ตั้งชื่อ: `admin-staff` (ต้องตรงตัวนี้เป๊ะๆ เพราะเว็บเรียกชื่อนี้)
5. เปิดไฟล์ `index.ts` ในโฟลเดอร์นี้ (`supabase/functions/admin-staff/index.ts`) → copy โค้ดทั้งหมด
6. วางแทนโค้ด template ในหน้า Dashboard
7. กด **Deploy**

ไม่ต้องตั้งค่า secret ใดๆ เพิ่ม — `SUPABASE_URL` และ `SUPABASE_SERVICE_ROLE_KEY` ระบบใส่ให้อัตโนมัติทุก Edge Function อยู่แล้ว

## ทดสอบว่า deploy สำเร็จ

หลัง deploy เสร็จ กลับไปที่เว็บ CRM → หน้า "ทีมงาน" (ต้อง login เป็น LV1-3) → กด "+ เพิ่มพนักงาน" → กรอกข้อมูล → กด "เพิ่ม"

ถ้าขึ้น error แบบ `Failed to send a request to the Edge Function` แปลว่ายังไม่ได้ deploy หรือชื่อฟังก์ชันไม่ตรง

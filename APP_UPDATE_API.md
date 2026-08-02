# Update-check API สำหรับโปรแกรมช่วยดาวน์โหลด

เอกสารนี้สำหรับคนเขียนตัวโปรแกรม (desktop app) ไม่เกี่ยวกับเว็บไซต์
ตัวโปรแกรมไม่ต้องอยู่ใน repo นี้ — อัปโหลดไฟล์ build ผ่านหน้าแอดมิน
(`adminupload.html` → แท็บ **โปรแกรม**) แล้วระบบจะจัดการเอง

---

## Endpoint

```
POST https://dqegkyobclqqichhnxfm.supabase.co/rest/v1/rpc/get_latest_app_release
```

**Headers**

```
apikey: sb_publishable_4U_v9BIrQjKppfchaevA6Q_zWj3zkxE
Content-Type: application/json
```

**Body**

```json
{}
```

คีย์นี้เป็น publishable key เปิดเผยได้ ฝังในโปรแกรมได้เลย
สิทธิ์ทั้งหมดถูกจำกัดด้วย RLS ฝั่งฐานข้อมูล — เรียกได้เฉพาะฟังก์ชันนี้
และอ่านได้เฉพาะเวอร์ชันที่เผยแพร่แล้วเท่านั้น

---

## Response

ถ้ามีเวอร์ชันที่เผยแพร่:

```json
{
  "version": "1.0.3",
  "notes": "แก้ไขปัญหาดาวน์โหลดค้าง",
  "file_name": "DCBC-Downloader-1.0.3.exe",
  "file_size": 8421376,
  "download_url": "https://dqegkyobclqqichhnxfm.supabase.co/storage/v1/object/public/app-releases/1753...-DCBC-Downloader-1.0.3.exe",
  "released_at": "2026-08-02T10:15:00+00:00"
}
```

ถ้ายังไม่มีเวอร์ชันที่เผยแพร่ จะได้ `null`

`download_url` เป็นลิงก์ตรงดาวน์โหลดได้ทันที ไม่ต้องใช้ token

---

## ตัวอย่างโค้ด

### C# (.NET)

```csharp
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

const string SupabaseUrl = "https://dqegkyobclqqichhnxfm.supabase.co";
const string AnonKey = "sb_publishable_4U_v9BIrQjKppfchaevA6Q_zWj3zkxE";
const string CurrentVersion = "1.0.0";   // เปลี่ยนตามเวอร์ชันของ build นี้

async Task CheckForUpdateAsync()
{
    using var http = new HttpClient();
    http.DefaultRequestHeaders.Add("apikey", AnonKey);

    var content = new StringContent("{}", Encoding.UTF8, "application/json");
    var res = await http.PostAsync($"{SupabaseUrl}/rest/v1/rpc/get_latest_app_release", content);
    var json = await res.Content.ReadAsStringAsync();

    if (string.IsNullOrWhiteSpace(json) || json == "null") return;  // ยังไม่มีเวอร์ชัน

    using var doc = JsonDocument.Parse(json);
    var latest = doc.RootElement.GetProperty("version").GetString();

    if (IsNewer(latest, CurrentVersion))
    {
        var url = doc.RootElement.GetProperty("download_url").GetString();
        var notes = doc.RootElement.GetProperty("notes").GetString();
        // แจ้งผู้ใช้ว่ามีเวอร์ชันใหม่ แล้วเปิด url เพื่อดาวน์โหลด
    }
}

// เทียบเวอร์ชันแบบตัวเลข ไม่ใช่เทียบ string
// (ถ้าเทียบ string "1.10" จะน้อยกว่า "1.9" ซึ่งผิด)
static bool IsNewer(string latest, string current)
    => Version.TryParse(latest, out var l)
       && Version.TryParse(current, out var c)
       && l > c;
```

### Python

```python
import requests
from packaging import version

SUPABASE_URL = "https://dqegkyobclqqichhnxfm.supabase.co"
ANON_KEY = "sb_publishable_4U_v9BIrQjKppfchaevA6Q_zWj3zkxE"
CURRENT_VERSION = "1.0.0"

def check_for_update():
    res = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/get_latest_app_release",
        headers={"apikey": ANON_KEY, "Content-Type": "application/json"},
        json={},
        timeout=10,
    )
    res.raise_for_status()
    latest = res.json()

    if not latest:
        return None

    if version.parse(latest["version"]) > version.parse(CURRENT_VERSION):
        return latest      # dict มี version, notes, download_url, file_size
    return None
```

---

## ข้อควรรู้

**เวอร์ชันไหนคือ "ล่าสุด"**
ระบบยึด **ลำดับเวลาที่อัปโหลด** (แถวที่เผยแพร่และใหม่ที่สุด) ไม่ได้เทียบตัวเลขเวอร์ชัน
ดังนั้นถ้าอัปโหลด 1.0.5 แล้วค่อยอัปโหลด 1.0.4 ทีหลัง ระบบจะถือว่า 1.0.4 คือล่าสุด
ให้อัปโหลดเรียงตามลำดับจริง หรือใช้ปุ่ม "หยุดเผยแพร่" กับตัวที่ไม่ต้องการ

**การเทียบเวอร์ชันในโปรแกรม**
ต้องเทียบแบบตัวเลข อย่าเทียบ string ตรงๆ เพราะ `"1.10" < "1.9"` ในการเทียบ string
ตัวอย่างด้านบนใช้ `Version.TryParse` (C#) และ `packaging.version` (Python) จัดการให้แล้ว

**การพักเวอร์ชันไว้ก่อน**
ตอนอัปโหลดสามารถไม่ติ๊ก "เผยแพร่ทันที" เพื่อเตรียมไฟล์ไว้ก่อน
ลูกค้าและโปรแกรมจะยังไม่เห็นจนกว่าจะกดเผยแพร่

**ความถี่ในการเช็ก**
แนะนำเช็กตอนเปิดโปรแกรม ไม่ต้องเช็กถี่กว่านั้น และควรใส่ timeout
พร้อมจับ exception ไว้ เพื่อไม่ให้โปรแกรมค้างถ้าเน็ตมีปัญหา

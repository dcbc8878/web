-- ============================================================
-- CRM Billing Migration — เด็กชายบัญชี Staff Portal
-- Run AFTER crm-migration.sql in Supabase SQL Editor
-- SAFE TO RE-RUN — all statements are idempotent
-- ============================================================

-- ──────────────────────────────────────────────────────────
-- Add billing & contact fields to crm_clients
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.crm_clients
  ADD COLUMN IF NOT EXISTS billing_type  text    NOT NULL DEFAULT 'monthly'
    CHECK (billing_type IN ('monthly','annual','filing')),
  ADD COLUMN IF NOT EXISTS monthly_fee   numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS has_wht       boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS client_email  text    NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS line_group_id text    NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS fa_contact_id text    NOT NULL DEFAULT '';

COMMENT ON COLUMN public.crm_clients.billing_type  IS 'monthly | annual | filing';
COMMENT ON COLUMN public.crm_clients.monthly_fee   IS 'ค่าบริการต่อเดือน (บาท) — สำหรับ filing ใช้เป็นค่ายื่นแบบ';
COMMENT ON COLUMN public.crm_clients.has_wht        IS 'ลูกค้าหัก ณ ที่จ่าย 3% หรือไม่';
COMMENT ON COLUMN public.crm_clients.client_email   IS 'อีเมลส่งใบเสร็จ';
COMMENT ON COLUMN public.crm_clients.line_group_id  IS 'LINE Group ID สำหรับส่งใบแจ้งหนี้';
COMMENT ON COLUMN public.crm_clients.fa_contact_id  IS 'FlowAccount Contact ID (กรอกหลัง API พร้อมใช้)';

-- ──────────────────────────────────────────────────────────
-- crm_billing_contracts — บันทึกประวัติเมื่อค่าบริการเปลี่ยน
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_billing_contracts (
  id             bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  client_id      bigint      NOT NULL REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  effective_from date        NOT NULL DEFAULT CURRENT_DATE,
  effective_to   date,                                    -- NULL = ยังใช้อยู่
  billing_type   text        NOT NULL DEFAULT 'monthly',
  fee_amount     numeric     NOT NULL DEFAULT 0,
  has_wht        boolean     NOT NULL DEFAULT true,
  notes          text        NOT NULL DEFAULT '',
  created_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.crm_billing_contracts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS crm_bc_sel ON public.crm_billing_contracts;
CREATE POLICY crm_bc_sel ON public.crm_billing_contracts FOR SELECT
  USING (crm_get_role() IN ('owner','senior'));

DROP POLICY IF EXISTS crm_bc_ins ON public.crm_billing_contracts;
CREATE POLICY crm_bc_ins ON public.crm_billing_contracts FOR INSERT
  WITH CHECK (crm_get_role() = 'owner');

DROP POLICY IF EXISTS crm_bc_upd ON public.crm_billing_contracts;
CREATE POLICY crm_bc_upd ON public.crm_billing_contracts FOR UPDATE
  USING (crm_get_role() = 'owner');

DROP POLICY IF EXISTS crm_bc_del ON public.crm_billing_contracts;
CREATE POLICY crm_bc_del ON public.crm_billing_contracts FOR DELETE
  USING (crm_get_role() = 'owner');

-- ──────────────────────────────────────────────────────────
-- crm_invoices — ใบแจ้งหนี้ + ใบเสร็จ per client per month
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_invoices (
  id                  bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  client_id           bigint      NOT NULL REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  year                int         NOT NULL,
  month               int         NOT NULL CHECK (month BETWEEN 1 AND 12),
  billing_type        text        NOT NULL DEFAULT 'monthly',
  fee_amount          numeric     NOT NULL DEFAULT 0,        -- ค่าบริการเต็ม
  wht_amount          numeric     NOT NULL DEFAULT 0,        -- หัก ณ ที่จ่าย 3%
  expected_payment    numeric     NOT NULL DEFAULT 0,        -- ที่คาดว่าจะรับ (fee - wht)
  -- FlowAccount (กรอกหลัง API พร้อม 17 ส.ค.)
  fa_invoice_id       text        NOT NULL DEFAULT '',
  fa_invoice_no       text        NOT NULL DEFAULT '',
  fa_receipt_id       text        NOT NULL DEFAULT '',
  fa_receipt_no       text        NOT NULL DEFAULT '',
  -- สถานะ
  status              text        NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','sent','paid','cancelled')),
  invoice_sent_at     timestamptz,                          -- ส่ง LINE แล้ว
  payment_received_at timestamptz,                          -- ยืนยันรับเงินแล้ว
  payment_amount      numeric,                              -- จำนวนที่รับจริง
  receipt_sent_at     timestamptz,                          -- ส่งใบเสร็จทาง email แล้ว
  notes               text        NOT NULL DEFAULT '',
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (client_id, year, month)
);

ALTER TABLE public.crm_invoices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS crm_inv_sel ON public.crm_invoices;
CREATE POLICY crm_inv_sel ON public.crm_invoices FOR SELECT
  USING (
    crm_get_role() IN ('owner','senior')
    OR EXISTS (
      SELECT 1 FROM public.crm_staff_clients
      WHERE staff_id = auth.uid() AND client_id = crm_invoices.client_id
    )
  );

DROP POLICY IF EXISTS crm_inv_ins ON public.crm_invoices;
CREATE POLICY crm_inv_ins ON public.crm_invoices FOR INSERT
  WITH CHECK (crm_get_role() IN ('owner','senior'));

DROP POLICY IF EXISTS crm_inv_upd ON public.crm_invoices;
CREATE POLICY crm_inv_upd ON public.crm_invoices FOR UPDATE
  USING (crm_get_role() IN ('owner','senior'));

DROP POLICY IF EXISTS crm_inv_del ON public.crm_invoices;
CREATE POLICY crm_inv_del ON public.crm_invoices FOR DELETE
  USING (crm_get_role() = 'owner');

DROP TRIGGER IF EXISTS crm_inv_upd_at ON public.crm_invoices;
CREATE TRIGGER crm_inv_upd_at
  BEFORE UPDATE ON public.crm_invoices
  FOR EACH ROW EXECUTE FUNCTION public.crm_set_updated_at();

-- ──────────────────────────────────────────────────────────
-- crm_year_end_tasks — งานปลายปี per client per year
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_year_end_tasks (
  id          bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  client_id   bigint      NOT NULL REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  year        int         NOT NULL,
  -- ภ.ง.ด.51  ประมาณการกลางปี (บริษัทที่มีกำไร)
  pnd51       text        NOT NULL DEFAULT 'na'   CHECK (pnd51   IN ('done','todo','na')),
  -- ภ.ง.ด.50  ภาษีเงินได้นิติบุคคลปลายปี
  pnd50       text        NOT NULL DEFAULT 'todo' CHECK (pnd50   IN ('done','todo','na')),
  -- งบการเงิน
  fin_stmt    text        NOT NULL DEFAULT 'todo' CHECK (fin_stmt IN ('done','todo','na')),
  -- ตรวจสอบบัญชี (ผู้สอบบัญชีรับอนุญาต — บริษัทส่วนใหญ่ต้องมี)
  audit       text        NOT NULL DEFAULT 'na'   CHECK (audit   IN ('done','todo','na')),
  -- ส่ง DBD (สำนักงานพัฒนาธุรกิจการค้า)
  dbd_submit  text        NOT NULL DEFAULT 'todo' CHECK (dbd_submit IN ('done','todo','na')),
  notes       text        NOT NULL DEFAULT '',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (client_id, year)
);

ALTER TABLE public.crm_year_end_tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS crm_yet_sel ON public.crm_year_end_tasks;
CREATE POLICY crm_yet_sel ON public.crm_year_end_tasks FOR SELECT
  USING (
    crm_get_role() IN ('owner','senior')
    OR EXISTS (
      SELECT 1 FROM public.crm_staff_clients
      WHERE staff_id = auth.uid() AND client_id = crm_year_end_tasks.client_id
    )
  );

DROP POLICY IF EXISTS crm_yet_ins ON public.crm_year_end_tasks;
CREATE POLICY crm_yet_ins ON public.crm_year_end_tasks FOR INSERT
  WITH CHECK (crm_get_role() IN ('owner','senior'));

DROP POLICY IF EXISTS crm_yet_upd ON public.crm_year_end_tasks;
CREATE POLICY crm_yet_upd ON public.crm_year_end_tasks FOR UPDATE
  USING (crm_get_role() IN ('owner','senior'));

DROP POLICY IF EXISTS crm_yet_del ON public.crm_year_end_tasks;
CREATE POLICY crm_yet_del ON public.crm_year_end_tasks FOR DELETE
  USING (crm_get_role() = 'owner');

DROP TRIGGER IF EXISTS crm_yet_upd_at ON public.crm_year_end_tasks;
CREATE TRIGGER crm_yet_upd_at
  BEFORE UPDATE ON public.crm_year_end_tasks
  FOR EACH ROW EXECUTE FUNCTION public.crm_set_updated_at();

-- ──────────────────────────────────────────────────────────
-- เพิ่ม invoice_id FK ใน crm_tax_tasks
-- (ใช้เชื่อมสถานะ Acct Fee กับใบแจ้งหนี้ — สำหรับ LINE bot ใช้ update พร้อมกัน)
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.crm_tax_tasks
  ADD COLUMN IF NOT EXISTS invoice_id bigint
    REFERENCES public.crm_invoices(id) ON DELETE SET NULL;

-- ============================================================
-- Convenience function: คำนวณยอดที่คาดว่าจะรับ
-- ใช้ใน application logic (dashboard จะคำนวณ client-side)
-- ============================================================
CREATE OR REPLACE FUNCTION public.crm_calc_expected(fee numeric, has_wht boolean)
RETURNS numeric LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN has_wht THEN ROUND(fee * 0.97, 2) ELSE fee END;
$$;

-- ============================================================
-- USAGE NOTES
-- ============================================================
--
-- 1. หลัง run migration นี้แล้ว ต้องไปอัปเดตค่าบริการแต่ละลูกค้า:
--    UPDATE public.crm_clients
--    SET billing_type='monthly', monthly_fee=XXXX, has_wht=true,
--        client_email='xxx@xxx.com', line_group_id='C...'
--    WHERE code='XXXX';
--
-- 2. ใบแจ้งหนี้ status flow:
--    draft → sent (ส่ง LINE) → paid (ยืนยันสลิป) → [receipt sent via email]
--    หรือ draft/sent → cancelled
--
-- 3. FlowAccount fields (fa_invoice_id, fa_receipt_id, fa_contact_id)
--    จะ populate หลัง sandbox เปิด 17 ส.ค. 2569
--
-- 4. LINE Bot (GAS) จะ:
--    - รับสลิป → ตรวจ Gemini Vision → match ยอด (fee*0.97 ±20 บาท)
--    - ถ้าตรง → UPDATE crm_invoices SET status='paid', payment_received_at=NOW()
--              → UPDATE crm_tax_tasks SET acct_fee='done', invoice_id=<id>
--    - ถ้าไม่ตรง → ส่งแจ้งเตือนห้อง admin
-- ============================================================

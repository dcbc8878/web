-- ============================================================
-- CRM Fields Migration — เพิ่มคอลัมน์ใหม่
-- Run AFTER supabase-crm-migration.sql และ supabase-crm-billing-migration.sql
-- SAFE TO RE-RUN — all statements use IF NOT EXISTS
-- ============================================================

-- ──────────────────────────────────────────────────────────
-- เพิ่ม pnd54 ใน crm_tax_tasks (ภ.ง.ด.54)
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.crm_tax_tasks
  ADD COLUMN IF NOT EXISTS pnd54 text NOT NULL DEFAULT 'todo'
    CHECK (pnd54 IN ('done','todo','na'));

COMMENT ON COLUMN public.crm_tax_tasks.pnd54 IS 'ภ.ง.ด.54 — ภาษีเงินได้หัก ณ ที่จ่าย (บริษัทต่างประเทศ)';

-- ──────────────────────────────────────────────────────────
-- เพิ่มคอลัมน์ปลายปีใน crm_year_end_tasks
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.crm_year_end_tasks
  ADD COLUMN IF NOT EXISTS pnd1k text NOT NULL DEFAULT 'todo'
    CHECK (pnd1k IN ('done','todo','na')),
  ADD COLUMN IF NOT EXISTS kt26k text NOT NULL DEFAULT 'todo'
    CHECK (kt26k IN ('done','todo','na')),
  ADD COLUMN IF NOT EXISTS boj5  text NOT NULL DEFAULT 'todo'
    CHECK (boj5  IN ('done','todo','na'));

COMMENT ON COLUMN public.crm_year_end_tasks.pnd1k IS 'ภ.ง.ด.1ก — สรุปการหักภาษี ณ ที่จ่ายรายปี';
COMMENT ON COLUMN public.crm_year_end_tasks.kt26k IS 'กท.26ก — รายงานเงินสมทบประกันสังคมประจำปี';
COMMENT ON COLUMN public.crm_year_end_tasks.boj5  IS 'บอจ.5 — รายงานการประชุมผู้ถือหุ้นประจำปี (ส่ง DBD)';

-- ──────────────────────────────────────────────────────────
-- เพิ่มรหัสผ่าน SVS และ กยศ ใน crm_client_credentials
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.crm_client_credentials
  ADD COLUMN IF NOT EXISTS svs_username text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS svs_password text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS kys_username text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS kys_password text NOT NULL DEFAULT '';

COMMENT ON COLUMN public.crm_client_credentials.svs_username IS 'กองทุนพัฒนาฝีมือแรงงาน (SVS)';
COMMENT ON COLUMN public.crm_client_credentials.kys_username IS 'กองทุนเงินให้กู้ยืมเพื่อการศึกษา (กยศ)';

-- ──────────────────────────────────────────────────────────
-- เพิ่ม sent/paid ต่อกลุ่มภาษี (TAX1 / SSO / TAX2) ใน crm_tax_tasks
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.crm_tax_tasks
  ADD COLUMN IF NOT EXISTS tax1_sent       boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS tax1_paid       boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS sso_sent        boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS sso_client_paid boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS tax2_sent       boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS tax2_paid       boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.crm_tax_tasks.tax1_sent       IS 'TAX1 — ส่งบิลให้ลูกค้าแล้ว';
COMMENT ON COLUMN public.crm_tax_tasks.tax1_paid       IS 'TAX1 — ลูกค้าชำระแล้ว';
COMMENT ON COLUMN public.crm_tax_tasks.sso_sent        IS 'SSO — ส่งบิลให้ลูกค้าแล้ว';
COMMENT ON COLUMN public.crm_tax_tasks.sso_client_paid IS 'SSO — ลูกค้าชำระแล้ว';
COMMENT ON COLUMN public.crm_tax_tasks.tax2_sent       IS 'TAX2 — ส่งบิลให้ลูกค้าแล้ว';
COMMENT ON COLUMN public.crm_tax_tasks.tax2_paid       IS 'TAX2 — ลูกค้าชำระแล้ว';

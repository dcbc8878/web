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

-- ============================================================
-- CRM Fiscal Year Migration
-- Adds "รอบบัญชี" (fiscal year-end date) to crm_clients, stored as
-- "DD/MM" text (e.g. "31/12" = ปิดรอบ 31 ธันวาคม).
-- SAFE TO RE-RUN — also cleans up the old month-only column if this
-- was already run once before the dd/mm change.
-- ============================================================

ALTER TABLE public.crm_clients
  ADD COLUMN IF NOT EXISTS fiscal_year_end text NOT NULL DEFAULT '31/12';

COMMENT ON COLUMN public.crm_clients.fiscal_year_end IS
  'วันที่ปิดรอบบัญชี รูปแบบ DD/MM เช่น 31/12';

ALTER TABLE public.crm_clients DROP COLUMN IF EXISTS fiscal_year_end_month;

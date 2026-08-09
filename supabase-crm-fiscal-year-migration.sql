-- ============================================================
-- CRM Fiscal Year Migration
-- Adds "รอบงบการเงิน" (fiscal year-end month) to crm_clients.
-- SAFE TO RE-RUN
-- ============================================================

ALTER TABLE public.crm_clients
  ADD COLUMN IF NOT EXISTS fiscal_year_end_month text NOT NULL DEFAULT '12';

COMMENT ON COLUMN public.crm_clients.fiscal_year_end_month IS
  'เดือนที่ปิดรอบบัญชี (1-12, ค่าเริ่มต้น 12 = ธันวาคม)';

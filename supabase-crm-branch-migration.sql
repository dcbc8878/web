-- ============================================================
-- CRM Branch Field Migration
-- Adds "สาขา" (branch) to crm_clients, shown right after TAX ID
-- in the ข้อมูลทั่วไป tab.
-- SAFE TO RE-RUN
-- ============================================================

ALTER TABLE public.crm_clients
  ADD COLUMN IF NOT EXISTS branch text NOT NULL DEFAULT '';

COMMENT ON COLUMN public.crm_clients.branch IS 'สาขา เช่น สำนักงานใหญ่ หรือ สาขาที่ 00001';

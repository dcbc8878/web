-- ============================================================
-- CRM Own Company Migration
-- Adds a flag to mark a crm_clients row as "our own company"
-- (tracked for tax filing like a client, but excluded from the
-- client list and revenue/billing reports)
-- SAFE TO RE-RUN — uses IF NOT EXISTS
-- ============================================================

ALTER TABLE public.crm_clients
  ADD COLUMN IF NOT EXISTS is_own_company boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.crm_clients.is_own_company IS
  'true = บริษัทของตัวเอง (เด็กชายบัญชี) ไม่ใช่ลูกค้า — ไม่นับในรายชื่อลูกค้า/รายได้';

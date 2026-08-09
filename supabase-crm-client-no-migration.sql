-- ============================================================
-- CRM Client NO. Migration
-- Splits "NO." (the systematic M001/Y002/T003-style identifier)
-- away from "CODE" (a free-form alias like "EPED") — previously
-- both were the same crm_clients.code column, so a client with a
-- custom code lost its systematic NO. entirely.
--
-- billing_type already exists (รายเดือน/รายปี/ยื่นแบบเปล่า —
-- monthly/annual/filing); this just adds the numeric sequence part.
-- SAFE TO RE-RUN
-- ============================================================

ALTER TABLE public.crm_clients
  ADD COLUMN IF NOT EXISTS seq_num integer;

COMMENT ON COLUMN public.crm_clients.seq_num IS
  'ลำดับที่ (1-999) ใช้คู่กับ billing_type แสดงเป็น NO. เช่น M001';

-- Backfill: for clients whose code still matches the M/Y/T+3-digit
-- pattern (i.e. they never set a custom alias), recover the sequence
-- number from it so existing NO. values aren't lost.
UPDATE public.crm_clients
SET seq_num = substring(code from '^[MYT](\d{3})$')::integer
WHERE seq_num IS NULL
  AND code ~ '^[MYT]\d{3}$';

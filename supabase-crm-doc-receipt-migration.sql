-- ============================================================
-- CRM Document Receipt Redesign Migration
-- Splits "รับเอกสาร" into two tracked categories:
--   1. Bank Statement — per bank account configured on the client
--   2. เอกสารประกอบการบันทึกบัญชี (other docs) — existing doc_items/
--      doc_item_templates columns, unchanged in shape
-- SAFE TO RE-RUN
-- ============================================================

-- ──────────────────────────────────────────────────────────
-- crm_client_bank_accounts — static per-client bank list
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_client_bank_accounts (
  id          bigserial   PRIMARY KEY,
  client_id   bigint      NOT NULL REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  bank_name   text        NOT NULL DEFAULT '',
  account_no  text        NOT NULL DEFAULT '',
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.crm_client_bank_accounts ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crm_client_bank_accounts' AND policyname = 'Active staff can view bank accounts'
  ) THEN
    CREATE POLICY "Active staff can view bank accounts"
      ON public.crm_client_bank_accounts FOR SELECT
      USING (EXISTS (SELECT 1 FROM public.crm_staff WHERE id = auth.uid() AND is_active = true));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crm_client_bank_accounts' AND policyname = 'LV1-3 can insert bank accounts'
  ) THEN
    CREATE POLICY "LV1-3 can insert bank accounts"
      ON public.crm_client_bank_accounts FOR INSERT
      WITH CHECK (crm_get_role() IN ('owner','manager','senior'));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crm_client_bank_accounts' AND policyname = 'LV1-3 can delete bank accounts'
  ) THEN
    CREATE POLICY "LV1-3 can delete bank accounts"
      ON public.crm_client_bank_accounts FOR DELETE
      USING (crm_get_role() IN ('owner','manager','senior'));
  END IF;
END $$;

-- ──────────────────────────────────────────────────────────
-- crm_tax_tasks — which bank accounts sent their statement this month
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.crm_tax_tasks
  ADD COLUMN IF NOT EXISTS doc_items_bank text NOT NULL DEFAULT '';

COMMENT ON COLUMN public.crm_tax_tasks.doc_items_bank IS
  'comma-separated crm_client_bank_accounts.id values received this month';

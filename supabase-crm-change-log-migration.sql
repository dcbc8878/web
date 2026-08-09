-- ============================================================
-- CRM Client Change Log Migration
-- Run AFTER supabase-crm-fields-migration.sql
-- SAFE TO RE-RUN — uses IF NOT EXISTS
-- ============================================================

-- ──────────────────────────────────────────────────────────
-- เพิ่ม address ใน crm_clients
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.crm_clients
  ADD COLUMN IF NOT EXISTS address text NOT NULL DEFAULT '';

COMMENT ON COLUMN public.crm_clients.address IS 'ที่อยู่บริษัท';

-- ──────────────────────────────────────────────────────────
-- crm_client_change_log
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_client_change_log (
  id          bigserial   PRIMARY KEY,
  client_id   bigint      NOT NULL REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  change_type text        NOT NULL DEFAULT '',
  change_date text        NOT NULL DEFAULT '',
  new_value   text        NOT NULL DEFAULT '',
  note        text        NOT NULL DEFAULT '',
  created_by  uuid        REFERENCES auth.users(id),
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.crm_client_change_log ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crm_client_change_log'
      AND policyname = 'Active staff can view change log'
  ) THEN
    CREATE POLICY "Active staff can view change log"
      ON public.crm_client_change_log FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM public.crm_staff
          WHERE id = auth.uid() AND is_active = true
        )
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crm_client_change_log'
      AND policyname = 'Non-staff can insert change log'
  ) THEN
    CREATE POLICY "Non-staff can insert change log"
      ON public.crm_client_change_log FOR INSERT
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM public.crm_staff
          WHERE id = auth.uid() AND is_active = true AND role <> 'staff'
        )
      );
  END IF;
END $$;

-- ============================================================
-- CRM Custom Credential Items Migration
-- Lets staff add extra username/password entries per client
-- from the web app itself (e.g. "ระบบ e-Filing", "FlowAccount")
-- without a developer adding new Supabase columns each time.
-- Run AFTER supabase-crm-5level-roles-migration.sql
-- SAFE TO RE-RUN
-- ============================================================

CREATE TABLE IF NOT EXISTS public.crm_client_credential_items (
  id          bigserial   PRIMARY KEY,
  client_id   bigint      NOT NULL REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  label       text        NOT NULL DEFAULT '',
  username    text        NOT NULL DEFAULT '',
  password    text        NOT NULL DEFAULT '',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS crm_cred_items_upd_at ON public.crm_client_credential_items;
CREATE TRIGGER crm_cred_items_upd_at
  BEFORE UPDATE ON public.crm_client_credential_items
  FOR EACH ROW EXECUTE FUNCTION public.crm_set_updated_at();

ALTER TABLE public.crm_client_credential_items ENABLE ROW LEVEL SECURITY;

-- Everyone active can view (same as the fixed RD/DBD/SSO/SVS/กยศ fields)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crm_client_credential_items' AND policyname = 'Active staff can view cred items'
  ) THEN
    CREATE POLICY "Active staff can view cred items"
      ON public.crm_client_credential_items FOR SELECT
      USING (EXISTS (SELECT 1 FROM public.crm_staff WHERE id = auth.uid() AND is_active = true));
  END IF;
END $$;

-- Owner/manager/senior (LV1-3) can add/edit/delete
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crm_client_credential_items' AND policyname = 'LV1-3 can insert cred items'
  ) THEN
    CREATE POLICY "LV1-3 can insert cred items"
      ON public.crm_client_credential_items FOR INSERT
      WITH CHECK (crm_get_role() IN ('owner','manager','senior'));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crm_client_credential_items' AND policyname = 'LV1-3 can update cred items'
  ) THEN
    CREATE POLICY "LV1-3 can update cred items"
      ON public.crm_client_credential_items FOR UPDATE
      USING (crm_get_role() IN ('owner','manager','senior'));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crm_client_credential_items' AND policyname = 'LV1-3 can delete cred items'
  ) THEN
    CREATE POLICY "LV1-3 can delete cred items"
      ON public.crm_client_credential_items FOR DELETE
      USING (crm_get_role() IN ('owner','manager','senior'));
  END IF;
END $$;

-- ============================================================
-- CRM Base Migration — เด็กชายบัญชี Staff Portal
-- Run this FIRST in Supabase SQL Editor
-- SAFE TO RE-RUN — all statements are idempotent
-- ============================================================

-- ──────────────────────────────────────────────────────────
-- Helper: updated_at trigger function
-- ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crm_set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

-- ──────────────────────────────────────────────────────────
-- Helper: get current user's role from crm_staff
-- ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crm_get_role()
RETURNS text LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT role FROM public.crm_staff WHERE id = auth.uid() AND is_active = true LIMIT 1;
$$;

-- ──────────────────────────────────────────────────────────
-- crm_staff — CRM staff accounts (linked to auth.users)
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_staff (
  id           uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text        NOT NULL DEFAULT '',
  role         text        NOT NULL DEFAULT 'staff'
    CHECK (role IN ('owner','senior','staff')),
  is_active    boolean     NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.crm_staff ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS crm_staff_sel ON public.crm_staff;
CREATE POLICY crm_staff_sel ON public.crm_staff FOR SELECT
  USING (is_active = true OR crm_get_role() = 'owner');

DROP POLICY IF EXISTS crm_staff_upd ON public.crm_staff;
CREATE POLICY crm_staff_upd ON public.crm_staff FOR UPDATE
  USING (crm_get_role() = 'owner');

-- ──────────────────────────────────────────────────────────
-- crm_clients — accounting clients
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_clients (
  id          bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code        text        NOT NULL DEFAULT '' UNIQUE,
  thai_name   text        NOT NULL DEFAULT '',
  eng_name    text        NOT NULL DEFAULT '',
  tax_number  text        NOT NULL DEFAULT '',
  category    text        NOT NULL DEFAULT '',
  type        text        NOT NULL DEFAULT '',
  start_date  date,
  end_date    date,
  notes       text        NOT NULL DEFAULT '',
  is_active   boolean     NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS crm_clients_upd_at ON public.crm_clients;
CREATE TRIGGER crm_clients_upd_at
  BEFORE UPDATE ON public.crm_clients
  FOR EACH ROW EXECUTE FUNCTION public.crm_set_updated_at();

ALTER TABLE public.crm_clients ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS crm_cli_sel ON public.crm_clients;
CREATE POLICY crm_cli_sel ON public.crm_clients FOR SELECT
  USING (
    crm_get_role() IN ('owner','senior')
    OR EXISTS (
      SELECT 1 FROM public.crm_staff_clients
      WHERE staff_id = auth.uid() AND client_id = crm_clients.id
    )
  );

DROP POLICY IF EXISTS crm_cli_ins ON public.crm_clients;
CREATE POLICY crm_cli_ins ON public.crm_clients FOR INSERT
  WITH CHECK (crm_get_role() IN ('owner','senior'));

DROP POLICY IF EXISTS crm_cli_upd ON public.crm_clients;
CREATE POLICY crm_cli_upd ON public.crm_clients FOR UPDATE
  USING (crm_get_role() IN ('owner','senior'));

DROP POLICY IF EXISTS crm_cli_del ON public.crm_clients;
CREATE POLICY crm_cli_del ON public.crm_clients FOR DELETE
  USING (crm_get_role() = 'owner');

-- ──────────────────────────────────────────────────────────
-- crm_staff_clients — which staff are assigned to which clients
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_staff_clients (
  staff_id   uuid   NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  client_id  bigint NOT NULL REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  PRIMARY KEY (staff_id, client_id)
);

ALTER TABLE public.crm_staff_clients ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS crm_sc_sel ON public.crm_staff_clients;
CREATE POLICY crm_sc_sel ON public.crm_staff_clients FOR SELECT
  USING (crm_get_role() IN ('owner','senior') OR staff_id = auth.uid());

DROP POLICY IF EXISTS crm_sc_ins ON public.crm_staff_clients;
CREATE POLICY crm_sc_ins ON public.crm_staff_clients FOR INSERT
  WITH CHECK (crm_get_role() = 'owner');

DROP POLICY IF EXISTS crm_sc_del ON public.crm_staff_clients;
CREATE POLICY crm_sc_del ON public.crm_staff_clients FOR DELETE
  USING (crm_get_role() = 'owner');

-- ──────────────────────────────────────────────────────────
-- crm_tax_tasks — monthly tax task checklist per client
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_tax_tasks (
  id          bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  client_id   bigint      NOT NULL REFERENCES public.crm_clients(id) ON DELETE CASCADE,
  year        int         NOT NULL,
  month       int         NOT NULL CHECK (month BETWEEN 1 AND 12),
  -- งานยื่นแบบรายเดือน
  stm         text        NOT NULL DEFAULT 'todo' CHECK (stm        IN ('done','todo','na')),
  pnd1        text        NOT NULL DEFAULT 'todo' CHECK (pnd1       IN ('done','todo','na')),
  pnd3        text        NOT NULL DEFAULT 'todo' CHECK (pnd3       IN ('done','todo','na')),
  pnd53       text        NOT NULL DEFAULT 'todo' CHECK (pnd53      IN ('done','todo','na')),
  pp36        text        NOT NULL DEFAULT 'todo' CHECK (pp36       IN ('done','todo','na')),
  pp36_paid   text        NOT NULL DEFAULT 'todo' CHECK (pp36_paid  IN ('done','todo','na')),
  sso         text        NOT NULL DEFAULT 'todo' CHECK (sso        IN ('done','todo','na')),
  sso_paid    text        NOT NULL DEFAULT 'todo' CHECK (sso_paid   IN ('done','todo','na')),
  pp30        text        NOT NULL DEFAULT 'todo' CHECK (pp30       IN ('done','todo','na')),
  pp30_paid   text        NOT NULL DEFAULT 'todo' CHECK (pp30_paid  IN ('done','todo','na')),
  rd_keyed    text        NOT NULL DEFAULT 'todo' CHECK (rd_keyed   IN ('done','todo','na')),
  acct_fee    text        NOT NULL DEFAULT 'todo' CHECK (acct_fee   IN ('done','todo','na')),
  doc_date    text        NOT NULL DEFAULT '',    -- วันที่รับเอกสาร (free-text)
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (client_id, year, month)
);

DROP TRIGGER IF EXISTS crm_tax_tasks_upd_at ON public.crm_tax_tasks;
CREATE TRIGGER crm_tax_tasks_upd_at
  BEFORE UPDATE ON public.crm_tax_tasks
  FOR EACH ROW EXECUTE FUNCTION public.crm_set_updated_at();

ALTER TABLE public.crm_tax_tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS crm_tt_sel ON public.crm_tax_tasks;
CREATE POLICY crm_tt_sel ON public.crm_tax_tasks FOR SELECT
  USING (
    crm_get_role() IN ('owner','senior')
    OR EXISTS (
      SELECT 1 FROM public.crm_staff_clients
      WHERE staff_id = auth.uid() AND client_id = crm_tax_tasks.client_id
    )
  );

DROP POLICY IF EXISTS crm_tt_ins ON public.crm_tax_tasks;
CREATE POLICY crm_tt_ins ON public.crm_tax_tasks FOR INSERT
  WITH CHECK (
    crm_get_role() IN ('owner','senior')
    OR EXISTS (
      SELECT 1 FROM public.crm_staff_clients
      WHERE staff_id = auth.uid() AND client_id = crm_tax_tasks.client_id
    )
  );

DROP POLICY IF EXISTS crm_tt_upd ON public.crm_tax_tasks;
CREATE POLICY crm_tt_upd ON public.crm_tax_tasks FOR UPDATE
  USING (
    crm_get_role() IN ('owner','senior')
    OR EXISTS (
      SELECT 1 FROM public.crm_staff_clients
      WHERE staff_id = auth.uid() AND client_id = crm_tax_tasks.client_id
    )
  );

DROP POLICY IF EXISTS crm_tt_del ON public.crm_tax_tasks;
CREATE POLICY crm_tt_del ON public.crm_tax_tasks FOR DELETE
  USING (crm_get_role() IN ('owner','senior'));

-- ──────────────────────────────────────────────────────────
-- crm_client_credentials — RD / DBD / SSO logins per client
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_client_credentials (
  id           bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  client_id    bigint      NOT NULL REFERENCES public.crm_clients(id) ON DELETE CASCADE UNIQUE,
  rd_username  text        NOT NULL DEFAULT '',
  rd_password  text        NOT NULL DEFAULT '',
  dbd_username text        NOT NULL DEFAULT '',
  dbd_password text        NOT NULL DEFAULT '',
  sso_username text        NOT NULL DEFAULT '',
  sso_password text        NOT NULL DEFAULT '',
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS crm_cred_upd_at ON public.crm_client_credentials;
CREATE TRIGGER crm_cred_upd_at
  BEFORE UPDATE ON public.crm_client_credentials
  FOR EACH ROW EXECUTE FUNCTION public.crm_set_updated_at();

ALTER TABLE public.crm_client_credentials ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS crm_cred_sel ON public.crm_client_credentials;
CREATE POLICY crm_cred_sel ON public.crm_client_credentials FOR SELECT
  USING (crm_get_role() IN ('owner','senior'));

DROP POLICY IF EXISTS crm_cred_ins ON public.crm_client_credentials;
CREATE POLICY crm_cred_ins ON public.crm_client_credentials FOR INSERT
  WITH CHECK (crm_get_role() = 'owner');

DROP POLICY IF EXISTS crm_cred_upd ON public.crm_client_credentials;
CREATE POLICY crm_cred_upd ON public.crm_client_credentials FOR UPDATE
  USING (crm_get_role() = 'owner');

DROP POLICY IF EXISTS crm_cred_del ON public.crm_client_credentials;
CREATE POLICY crm_cred_del ON public.crm_client_credentials FOR DELETE
  USING (crm_get_role() = 'owner');

-- ============================================================
-- SETUP NOTES
-- ============================================================
--
-- หลัง run migration นี้แล้ว:
--
-- 1. สร้าง staff accounts ใน Supabase Auth (Authentication → Users → Add User)
--    แล้ว insert เข้า crm_staff:
--    INSERT INTO public.crm_staff (id, display_name, role)
--    VALUES ('<user-uuid>', 'ชื่อพนักงาน', 'owner');
--
-- 2. รัน supabase-crm-billing-migration.sql ต่อได้เลย
-- ============================================================

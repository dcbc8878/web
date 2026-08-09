-- ============================================================
-- CRM 5-Level Role System Migration
-- Replaces the old 3-level role system (owner/senior/staff)
-- with 5 levels: owner / manager / senior / junior / parttime
-- (LV1 = owner highest ... LV5 = parttime lowest)
--
-- Also adds crm_activity_log for the future "ประวัติการแก้ไข"
-- audit page (LV1/LV2 can view; LV2 cannot see LV1's entries).
--
-- SAFE TO RE-RUN
-- ============================================================

-- ──────────────────────────────────────────────────────────
-- 1. Migrate existing 'staff' role → 'junior' BEFORE changing
--    the CHECK constraint (old constraint still allows 'staff'
--    at this point, new values are not yet allowed either way
--    so we widen the constraint first, then remap data).
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.crm_staff DROP CONSTRAINT IF EXISTS crm_staff_role_check;

ALTER TABLE public.crm_staff
  ADD CONSTRAINT crm_staff_role_check
  CHECK (role IN ('owner','manager','senior','junior','parttime','staff'));

UPDATE public.crm_staff SET role = 'junior' WHERE role = 'staff';

ALTER TABLE public.crm_staff DROP CONSTRAINT IF EXISTS crm_staff_role_check;

ALTER TABLE public.crm_staff
  ADD CONSTRAINT crm_staff_role_check
  CHECK (role IN ('owner','manager','senior','junior','parttime'));

-- ──────────────────────────────────────────────────────────
-- 2. crm_get_role() unchanged in shape — still returns the
--    role text. RLS policies below now check against the new
--    5-value set instead of the old 3-value set.
-- ──────────────────────────────────────────────────────────

-- crm_clients: edit/insert = owner/manager/senior (LV1-3); delete = owner only
DROP POLICY IF EXISTS crm_cli_ins ON public.crm_clients;
CREATE POLICY crm_cli_ins ON public.crm_clients FOR INSERT
  WITH CHECK (crm_get_role() IN ('owner','manager','senior'));

DROP POLICY IF EXISTS crm_cli_upd ON public.crm_clients;
CREATE POLICY crm_cli_upd ON public.crm_clients FOR UPDATE
  USING (crm_get_role() IN ('owner','manager','senior'));

-- crm_cli_sel / crm_cli_del unchanged (select: all active staff via crm_staff_clients;
-- delete: owner only) — no edit needed here.

-- crm_tax_tasks: edit = owner/manager/senior (LV1-3)
DROP POLICY IF EXISTS crm_tt_ins ON public.crm_tax_tasks;
CREATE POLICY crm_tt_ins ON public.crm_tax_tasks FOR INSERT
  WITH CHECK (
    crm_get_role() IN ('owner','manager','senior')
    OR EXISTS (
      SELECT 1 FROM public.crm_staff_clients
      WHERE staff_id = auth.uid() AND client_id = crm_tax_tasks.client_id
    )
  );

DROP POLICY IF EXISTS crm_tt_upd ON public.crm_tax_tasks;
CREATE POLICY crm_tt_upd ON public.crm_tax_tasks FOR UPDATE
  USING (
    crm_get_role() IN ('owner','manager','senior')
    OR EXISTS (
      SELECT 1 FROM public.crm_staff_clients
      WHERE staff_id = auth.uid() AND client_id = crm_tax_tasks.client_id
    )
  );

DROP POLICY IF EXISTS crm_tt_del ON public.crm_tax_tasks;
CREATE POLICY crm_tt_del ON public.crm_tax_tasks FOR DELETE
  USING (crm_get_role() IN ('owner','manager','senior'));

-- crm_client_credentials: everyone active can VIEW (read-only vs edit is
-- enforced in the app for junior/parttime); edit = owner/manager/senior
DROP POLICY IF EXISTS crm_cred_sel ON public.crm_client_credentials;
CREATE POLICY crm_cred_sel ON public.crm_client_credentials FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.crm_staff WHERE id = auth.uid() AND is_active = true)
  );

DROP POLICY IF EXISTS crm_cred_ins ON public.crm_client_credentials;
CREATE POLICY crm_cred_ins ON public.crm_client_credentials FOR INSERT
  WITH CHECK (crm_get_role() IN ('owner','manager','senior'));

DROP POLICY IF EXISTS crm_cred_upd ON public.crm_client_credentials;
CREATE POLICY crm_cred_upd ON public.crm_client_credentials FOR UPDATE
  USING (crm_get_role() IN ('owner','manager','senior'));

-- crm_client_change_log: view = all active staff; insert/delete = owner/manager/senior
DROP POLICY IF EXISTS "Non-staff can insert change log" ON public.crm_client_change_log;
CREATE POLICY "Non-staff can insert change log"
  ON public.crm_client_change_log FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.crm_staff
      WHERE id = auth.uid() AND is_active = true AND role IN ('owner','manager','senior')
    )
  );

DROP POLICY IF EXISTS "Non-staff can delete change log" ON public.crm_client_change_log;
CREATE POLICY "Non-staff can delete change log"
  ON public.crm_client_change_log FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.crm_staff
      WHERE id = auth.uid() AND is_active = true AND role IN ('owner','manager','senior')
    )
  );

-- crm_staff: owner/manager can update other staff rows (role, name, active flag)
DROP POLICY IF EXISTS crm_staff_upd ON public.crm_staff;
CREATE POLICY crm_staff_upd ON public.crm_staff FOR UPDATE
  USING (crm_get_role() IN ('owner','manager'));

-- ──────────────────────────────────────────────────────────
-- 3. crm_activity_log — generic audit trail. LV1/LV2 (owner/
--    manager) can read; the app additionally hides LV1's own
--    entries from LV2 viewers.
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crm_activity_log (
  id           bigserial   PRIMARY KEY,
  actor_id     uuid        REFERENCES auth.users(id),
  actor_role   text        NOT NULL DEFAULT '',
  action       text        NOT NULL DEFAULT '',
  entity_type  text        NOT NULL DEFAULT '',
  entity_id    text        NOT NULL DEFAULT '',
  summary      text        NOT NULL DEFAULT '',
  created_at   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.crm_activity_log ENABLE ROW LEVEL SECURITY;

-- Owner sees everything; manager sees everything EXCEPT entries logged by an owner.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crm_activity_log' AND policyname = 'Owner/manager can view activity log'
  ) THEN
    CREATE POLICY "Owner/manager can view activity log"
      ON public.crm_activity_log FOR SELECT
      USING (
        crm_get_role() = 'owner'
        OR (crm_get_role() = 'manager' AND actor_role <> 'owner')
      );
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crm_activity_log' AND policyname = 'Active staff can insert activity log'
  ) THEN
    CREATE POLICY "Active staff can insert activity log"
      ON public.crm_activity_log FOR INSERT
      WITH CHECK (
        EXISTS (SELECT 1 FROM public.crm_staff WHERE id = auth.uid() AND is_active = true)
      );
  END IF;
END $$;

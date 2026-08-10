-- ============================================================
-- CRM Staff SELECT RLS Fix
-- crm_staff_sel's "is_active = true" branch was evaluated on the
-- TARGET row only — it never checked who the caller was. Since
-- the policy carries no "TO authenticated" clause, it applied to
-- the anon role too, so anyone holding the public anon key (it's
-- shipped in crm/index.html by design, protection is meant to
-- come from RLS, not secrecy) could read every active staff row
-- with ZERO login — including birthdate, staff_code, and
-- must_change_password (which flags accounts still on the
-- default password) added by later migrations.
--
-- Fix: the "see active staff" branch now also requires the
-- caller to be an authenticated, active staff member themselves
-- (crm_get_role() IS NOT NULL). Owners keep seeing every row,
-- active or not, same as before.
--
-- SAFE TO RE-RUN
-- ============================================================

DROP POLICY IF EXISTS crm_staff_sel ON public.crm_staff;
CREATE POLICY crm_staff_sel ON public.crm_staff FOR SELECT
  USING (
    crm_get_role() = 'owner'
    OR (is_active = true AND crm_get_role() IS NOT NULL)
  );

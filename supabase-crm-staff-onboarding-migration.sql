-- ============================================================
-- CRM Staff Onboarding Migration
-- Adds the "must change password on first login" flag + a safe
-- self-service RPC for a brand-new staff member to complete
-- their own onboarding (set display name, clear the flag) WITHOUT
-- granting a broad self-UPDATE policy on crm_staff (which would
-- let anyone promote their own role/is_active).
-- Run AFTER supabase-crm-5level-roles-migration.sql
-- SAFE TO RE-RUN
-- ============================================================

ALTER TABLE public.crm_staff
  ADD COLUMN IF NOT EXISTS must_change_password boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.crm_staff.must_change_password IS
  'true = just created with the default password (1234), must set a real password + display name before using the app';

CREATE OR REPLACE FUNCTION public.crm_complete_first_login(new_display_name text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.crm_staff
  SET display_name = COALESCE(NULLIF(trim(new_display_name), ''), display_name),
      must_change_password = false
  WHERE id = auth.uid();
END;
$$;

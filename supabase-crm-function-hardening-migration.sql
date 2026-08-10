-- ============================================================
-- CRM Function Hardening Migration
-- Two issues surfaced by Supabase's built-in security advisor:
--
-- 1. search_path not pinned on 4 CRM functions (crm_set_updated_at,
--    crm_get_role, crm_calc_expected, crm_complete_first_login) —
--    lets a malicious search_path fool the function into resolving
--    an unqualified name to the wrong object. All 4 already use
--    fully-qualified table names (or none at all), so pinning to
--    an empty search_path is safe.
--
-- 2. crm_complete_first_login was reachable by anyone, logged in
--    or not — its EXECUTE grant came from the default PUBLIC grant
--    Postgres adds to every new function, not a direct grant. It's
--    a SECURITY DEFINER function meant only for a brand-new staff
--    member finishing their own onboarding, so PUBLIC is revoked
--    and EXECUTE is re-granted to `authenticated` only.
--
-- Already applied directly to the live project via the Supabase
-- MCP connector on 2026-08-10. Kept here for the change history —
-- SAFE TO RE-RUN.
-- ============================================================

ALTER FUNCTION public.crm_set_updated_at() SET search_path = '';
ALTER FUNCTION public.crm_get_role() SET search_path = '';
ALTER FUNCTION public.crm_calc_expected(numeric, boolean) SET search_path = '';
ALTER FUNCTION public.crm_complete_first_login(text) SET search_path = '';

REVOKE EXECUTE ON FUNCTION public.crm_complete_first_login(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.crm_complete_first_login(text) TO authenticated;

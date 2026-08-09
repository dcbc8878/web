-- ============================================================
-- CRM Staff Self-Service Profile Migration
-- Adds birthdate to crm_staff so every staff member can maintain
-- their own name/username/password/birthdate from ตั้งค่า.
-- (username/email changes go through the admin-staff Edge Function
-- since they touch auth.users, which client-side RLS can't reach.)
-- SAFE TO RE-RUN
-- ============================================================

ALTER TABLE public.crm_staff
  ADD COLUMN IF NOT EXISTS birthdate date;

COMMENT ON COLUMN public.crm_staff.birthdate IS 'วันเดือนปีเกิด';

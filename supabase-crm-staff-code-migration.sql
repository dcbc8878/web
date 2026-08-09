-- ============================================================
-- CRM Staff Code Migration
-- Adds "รหัสพนักงาน" (staff_code) — a business-facing unique staff
-- identifier, editable only by LV1-2 (owner/manager) in the app.
-- The real primary key (crm_staff.id, tied to auth.users) is left
-- untouched — changing that would break every foreign key in the
-- schema. staff_code plays the same role for staff that "code"
-- (M001/Y002/...) already plays for crm_clients.
-- SAFE TO RE-RUN
-- ============================================================

ALTER TABLE public.crm_staff
  ADD COLUMN IF NOT EXISTS staff_code text NOT NULL DEFAULT '';

COMMENT ON COLUMN public.crm_staff.staff_code IS
  'รหัสพนักงาน — แก้ไขได้เฉพาะ LV1-2 (บังคับในแอป ไม่ใช่ RLS)';

-- Partial unique index (blank codes don't collide with each other)
DROP INDEX IF EXISTS crm_staff_code_uidx;
CREATE UNIQUE INDEX crm_staff_code_uidx
  ON public.crm_staff (staff_code)
  WHERE staff_code <> '';

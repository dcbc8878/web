-- ============================================================
-- CRM RLS Fix Migration
-- The 5-level-roles migration updated INSERT/UPDATE/DELETE
-- policies but missed several SELECT policies that still only
-- checked for the literal roles 'owner'/'senior' — so 'manager',
-- 'junior', and 'parttime' got ZERO rows back from crm_clients,
-- crm_tax_tasks, and crm_year_end_tasks (RLS fails closed), even
-- though the app now lets LV4-5 reach those pages. This is why
-- LV4 saw an empty ลูกค้า page instead of an error.
--
-- Run AFTER supabase-crm-5level-roles-migration.sql
-- SAFE TO RE-RUN
-- ============================================================

-- crm_clients — everyone active can view (tracking/yearend/clients
-- pages are open to all 5 levels)
DROP POLICY IF EXISTS crm_cli_sel ON public.crm_clients;
CREATE POLICY crm_cli_sel ON public.crm_clients FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.crm_staff WHERE id = auth.uid() AND is_active = true)
  );

-- crm_tax_tasks — everyone active can view (needed for the งานภาษี page)
DROP POLICY IF EXISTS crm_tt_sel ON public.crm_tax_tasks;
CREATE POLICY crm_tt_sel ON public.crm_tax_tasks FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.crm_staff WHERE id = auth.uid() AND is_active = true)
  );

-- crm_year_end_tasks — everyone active can view (needed for the ปลายปี page)
DROP POLICY IF EXISTS crm_yet_sel ON public.crm_year_end_tasks;
CREATE POLICY crm_yet_sel ON public.crm_year_end_tasks FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.crm_staff WHERE id = auth.uid() AND is_active = true)
  );

-- crm_invoices — LV1-3 (owner/manager/senior), matches canEdit() which
-- gates when the app even calls loadInvoices()/batch invoice actions
DROP POLICY IF EXISTS crm_inv_sel ON public.crm_invoices;
CREATE POLICY crm_inv_sel ON public.crm_invoices FOR SELECT
  USING (crm_get_role() IN ('owner','manager','senior'));

DROP POLICY IF EXISTS crm_inv_ins ON public.crm_invoices;
CREATE POLICY crm_inv_ins ON public.crm_invoices FOR INSERT
  WITH CHECK (crm_get_role() IN ('owner','manager','senior'));

DROP POLICY IF EXISTS crm_inv_upd ON public.crm_invoices;
CREATE POLICY crm_inv_upd ON public.crm_invoices FOR UPDATE
  USING (crm_get_role() IN ('owner','manager','senior'));

-- crm_billing_contracts — LV1-3 can view (dashboard/reporting context)
DROP POLICY IF EXISTS crm_bc_sel ON public.crm_billing_contracts;
CREATE POLICY crm_bc_sel ON public.crm_billing_contracts FOR SELECT
  USING (crm_get_role() IN ('owner','manager','senior'));

-- crm_staff_clients — LV1-2 (owner/manager) can view all assignments,
-- everyone can still see their own (unchanged)
DROP POLICY IF EXISTS crm_sc_sel ON public.crm_staff_clients;
CREATE POLICY crm_sc_sel ON public.crm_staff_clients FOR SELECT
  USING (crm_get_role() IN ('owner','manager') OR staff_id = auth.uid());

-- ============================================================
-- DCBC: documents library + reviews moderation
-- Run this once in Supabase SQL Editor, top to bottom.
-- Prerequisite: create the two storage buckets first via
-- Dashboard -> Storage (documents, review-logos) so the
-- bucket_id values referenced below already exist.
-- ============================================================

create extension if not exists pgcrypto; -- gen_random_uuid()

-- ---------- documents ----------
create table if not exists public.documents (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  description  text not null,
  file_path    text not null,      -- storage object key inside 'documents' bucket
  file_name    text not null,      -- original filename (for download attr + display)
  file_size    bigint,             -- bytes, optional, for UI display parity
  sort_order   integer,            -- manual display order, admin can reorder
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- Adds sort_order to a documents table that already existed before this
-- column was introduced. Safe to re-run: no-ops if the column is already
-- there or already backfilled.
alter table public.documents add column if not exists sort_order integer;

with ranked as (
  select id, row_number() over (order by created_at desc) as rn
  from public.documents
  where sort_order is null
)
update public.documents d set sort_order = ranked.rn
from ranked where ranked.id = d.id;

alter table public.documents enable row level security;

create policy "documents_public_read"
  on public.documents for select
  to anon, authenticated
  using (true);

create policy "documents_admin_insert"
  on public.documents for insert
  to authenticated
  with check (true);

create policy "documents_admin_update"
  on public.documents for update
  to authenticated
  using (true) with check (true);

create policy "documents_admin_delete"
  on public.documents for delete
  to authenticated
  using (true);

-- ---------- reviews ----------
create table if not exists public.reviews (
  id             uuid primary key default gen_random_uuid(),
  display_name   text not null,
  business_type  text,
  message        text not null,
  logo_path      text,             -- storage key inside 'review-logos' bucket, nullable
  status         text not null default 'pending'
                 check (status in ('pending','approved','rejected')),
  created_at     timestamptz not null default now()
);

alter table public.reviews enable row level security;

-- Public site (index.html) may only ever see approved reviews
create policy "reviews_public_read_approved"
  on public.reviews for select
  to anon
  using (status = 'approved');

-- Admin dashboard sees everything (pending/approved/rejected)
create policy "reviews_admin_read_all"
  on public.reviews for select
  to authenticated
  using (true);

-- Public can submit a NEW review, but the row is force-locked to
-- 'pending' at the database level: WITH CHECK is evaluated against
-- the row being inserted, so an insert that omits `status` passes
-- (the column default fills in 'pending'), while any insert attempt
-- that explicitly sends status='approved' or 'rejected' is REJECTED
-- by Postgres regardless of what the client-side JS tries to send.
create policy "reviews_public_insert_pending"
  on public.reviews for insert
  to anon
  with check (status = 'pending');

-- Only the admin can approve/reject or edit a review
create policy "reviews_admin_update"
  on public.reviews for update
  to authenticated
  using (true) with check (true);

create policy "reviews_admin_delete"
  on public.reviews for delete
  to authenticated
  using (true);

-- ---------- Storage: documents bucket ----------
-- (bucket itself created via Dashboard, see manual steps)
create policy "documents_bucket_public_read"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'documents');

create policy "documents_bucket_admin_insert"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'documents');

create policy "documents_bucket_admin_update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'documents') with check (bucket_id = 'documents');

create policy "documents_bucket_admin_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'documents');

-- ---------- Storage: review-logos bucket ----------
-- Public INSERT is intentional: a customer submitting a pending
-- review from review.html uploads their own logo directly, before
-- any admin has logged in. Only admin can UPDATE/DELETE (moderation
-- cleanup); anon never gets those.
create policy "review_logos_bucket_public_read"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'review-logos');

create policy "review_logos_bucket_public_insert"
  on storage.objects for insert
  to anon, authenticated
  with check (bucket_id = 'review-logos');

create policy "review_logos_bucket_admin_update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'review-logos') with check (bucket_id = 'review-logos');

create policy "review_logos_bucket_admin_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'review-logos');

-- ---------- portal_codes ----------
-- Access codes for the client document portal (portal.html).
-- The codes themselves are NEVER exposed to anon — there is no
-- anon select policy on this table at all. The public page instead
-- calls the check_portal_code() function below, which only ever
-- returns true/false, so the code list can't be read off the network.
create table if not exists public.portal_codes (
  id           uuid primary key default gen_random_uuid(),
  code         text not null unique,   -- stored uppercase, 4 characters
  client_name  text,                   -- optional label, e.g. which client this code belongs to
  active       boolean not null default true,
  created_at   timestamptz not null default now()
);

alter table public.portal_codes enable row level security;

create policy "portal_codes_admin_select"
  on public.portal_codes for select
  to authenticated
  using (true);

create policy "portal_codes_admin_insert"
  on public.portal_codes for insert
  to authenticated
  with check (true);

create policy "portal_codes_admin_update"
  on public.portal_codes for update
  to authenticated
  using (true) with check (true);

create policy "portal_codes_admin_delete"
  on public.portal_codes for delete
  to authenticated
  using (true);

-- Callable by anon (and authenticated) from portal.html's lock screen.
-- SECURITY DEFINER lets it read the table despite anon having no
-- select policy above; it only ever leaks a boolean, never the codes.
create or replace function public.check_portal_code(input_code text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.portal_codes
    where code = upper(trim(input_code)) and active = true
  );
$$;

revoke all on function public.check_portal_code(text) from public;
grant execute on function public.check_portal_code(text) to anon, authenticated;

-- Seed the codes that were previously hardcoded in portal.html, so
-- access doesn't break the moment this migration runs. Safe to
-- re-run; manage/replace these from the admin panel afterwards.
insert into public.portal_codes (code) values
  ('DCBC'), ('EPED'), ('JYNE'), ('VTLB'), ('ACMS'), ('KKRB'), ('DCRG')
on conflict (code) do nothing;

-- ============================================================
-- DCBC: documents library + reviews moderation + portal codes
-- Run in Supabase SQL Editor, top to bottom.
--
-- SAFE TO RE-RUN. Every statement is idempotent: tables use
-- "if not exists", policies are dropped before being recreated
-- (Postgres has no "create policy if not exists"), and the
-- function uses "create or replace".
--
-- Prerequisite: create the two storage buckets first via
-- Dashboard -> Storage (documents, review-logos, app-releases) so the
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
-- column was introduced, then backfills it to preserve the previous
-- newest-first display order.
alter table public.documents add column if not exists sort_order integer;

with ranked as (
  select id, row_number() over (order by created_at desc) as rn
  from public.documents
  where sort_order is null
)
update public.documents d set sort_order = ranked.rn
from ranked where ranked.id = d.id;

-- Guard against any future insert (outside the admin UI) leaving this
-- NULL, which would sort unpredictably.
alter table public.documents alter column sort_order set default 0;
alter table public.documents alter column sort_order set not null;

alter table public.documents enable row level security;

drop policy if exists "documents_public_read" on public.documents;
create policy "documents_public_read"
  on public.documents for select
  to anon, authenticated
  using (true);

drop policy if exists "documents_admin_insert" on public.documents;
create policy "documents_admin_insert"
  on public.documents for insert
  to authenticated
  with check (true);

drop policy if exists "documents_admin_update" on public.documents;
create policy "documents_admin_update"
  on public.documents for update
  to authenticated
  using (true) with check (true);

drop policy if exists "documents_admin_delete" on public.documents;
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

-- Public site (homepage) may only ever see approved reviews
drop policy if exists "reviews_public_read_approved" on public.reviews;
create policy "reviews_public_read_approved"
  on public.reviews for select
  to anon
  using (status = 'approved');

-- Admin dashboard sees everything (pending/approved/rejected)
drop policy if exists "reviews_admin_read_all" on public.reviews;
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
drop policy if exists "reviews_public_insert_pending" on public.reviews;
create policy "reviews_public_insert_pending"
  on public.reviews for insert
  to anon
  with check (status = 'pending');

-- Only the admin can approve/reject or edit a review
drop policy if exists "reviews_admin_update" on public.reviews;
create policy "reviews_admin_update"
  on public.reviews for update
  to authenticated
  using (true) with check (true);

drop policy if exists "reviews_admin_delete" on public.reviews;
create policy "reviews_admin_delete"
  on public.reviews for delete
  to authenticated
  using (true);

-- ---------- portal_codes ----------
-- Access codes for the client document portal (/portal).
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

drop policy if exists "portal_codes_admin_select" on public.portal_codes;
create policy "portal_codes_admin_select"
  on public.portal_codes for select
  to authenticated
  using (true);

drop policy if exists "portal_codes_admin_insert" on public.portal_codes;
create policy "portal_codes_admin_insert"
  on public.portal_codes for insert
  to authenticated
  with check (true);

drop policy if exists "portal_codes_admin_update" on public.portal_codes;
create policy "portal_codes_admin_update"
  on public.portal_codes for update
  to authenticated
  using (true) with check (true);

drop policy if exists "portal_codes_admin_delete" on public.portal_codes;
create policy "portal_codes_admin_delete"
  on public.portal_codes for delete
  to authenticated
  using (true);

-- Callable by anon (and authenticated) from the portal lock screen.
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

-- Seed the codes that were previously hardcoded in the portal page, so
-- access doesn't break the moment this migration runs. Safe to
-- re-run; manage/replace these from the admin panel afterwards.
insert into public.portal_codes (code) values
  ('DCBC'), ('EPED'), ('JYNE'), ('VTLB'), ('ACMS'), ('KKRB'), ('DCRG')
on conflict (code) do nothing;

-- ---------- app_releases ----------
-- Versions of the downloadable helper program, served by the unlisted
-- /program/downloader page and by the program's own update check.
create table if not exists public.app_releases (
  id            uuid primary key default gen_random_uuid(),
  version       text not null,          -- e.g. '1.0.3'
  notes         text,                   -- what changed in this version
  file_path     text not null,          -- storage key inside 'app-releases' bucket
  file_name     text not null,          -- original filename, for the download attribute
  file_size     bigint,
  is_published  boolean not null default true,
  created_at    timestamptz not null default now()
);

alter table public.app_releases enable row level security;

-- Anyone (the download page, and the program checking for updates) may
-- read published releases. Unpublished ones stay admin-only, so a build
-- can be staged before it goes live.
drop policy if exists "app_releases_public_read_published" on public.app_releases;
create policy "app_releases_public_read_published"
  on public.app_releases for select
  to anon
  using (is_published = true);

drop policy if exists "app_releases_admin_read_all" on public.app_releases;
create policy "app_releases_admin_read_all"
  on public.app_releases for select
  to authenticated
  using (true);

drop policy if exists "app_releases_admin_insert" on public.app_releases;
create policy "app_releases_admin_insert"
  on public.app_releases for insert
  to authenticated
  with check (true);

drop policy if exists "app_releases_admin_update" on public.app_releases;
create policy "app_releases_admin_update"
  on public.app_releases for update
  to authenticated
  using (true) with check (true);

drop policy if exists "app_releases_admin_delete" on public.app_releases;
create policy "app_releases_admin_delete"
  on public.app_releases for delete
  to authenticated
  using (true);

-- The update-check endpoint the installed program calls. Returns the
-- newest published release as JSON (or null if none), including a ready
-- to use download URL. "Newest" = most recently added, so publishing
-- order is what decides it — not string-comparing version numbers,
-- which breaks as soon as you reach 1.10 vs 1.9.
create or replace function public.get_latest_app_release()
returns json
language sql
stable
security definer
set search_path = public
as $$
  select json_build_object(
    'version',      version,
    'notes',        notes,
    'file_name',    file_name,
    'file_size',    file_size,
    'download_url', 'https://dqegkyobclqqichhnxfm.supabase.co/storage/v1/object/public/app-releases/' || file_path,
    'released_at',  created_at
  )
  from public.app_releases
  where is_published = true
  order by created_at desc
  limit 1;
$$;

revoke all on function public.get_latest_app_release() from public;
grant execute on function public.get_latest_app_release() to anon, authenticated;

-- ---------- Storage: app-releases bucket ----------
-- Public bucket, so the installer downloads over its public URL with no
-- auth. Only the admin can upload or remove builds.
drop policy if exists "app_releases_bucket_admin_insert" on storage.objects;
create policy "app_releases_bucket_admin_insert"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'app-releases');

drop policy if exists "app_releases_bucket_admin_update" on storage.objects;
create policy "app_releases_bucket_admin_update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'app-releases') with check (bucket_id = 'app-releases');

drop policy if exists "app_releases_bucket_admin_delete" on storage.objects;
create policy "app_releases_bucket_admin_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'app-releases');

-- ---------- Storage: documents bucket ----------
-- (bucket itself created via Dashboard, see manual steps)
--
-- NOTE: there is deliberately NO public SELECT policy here. Both buckets
-- are PUBLIC, and a public bucket serves its files over the public URL
-- without consulting RLS at all — so downloads work regardless. Adding a
-- broad SELECT policy on storage.objects would additionally let anyone
-- LIST every object in the bucket, which Supabase's own advisor flags as
-- exposing more than intended. Dropped here in case an earlier run of
-- this migration created it.
drop policy if exists "documents_bucket_public_read" on storage.objects;

drop policy if exists "documents_bucket_admin_insert" on storage.objects;
create policy "documents_bucket_admin_insert"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'documents');

drop policy if exists "documents_bucket_admin_update" on storage.objects;
create policy "documents_bucket_admin_update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'documents') with check (bucket_id = 'documents');

drop policy if exists "documents_bucket_admin_delete" on storage.objects;
create policy "documents_bucket_admin_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'documents');

-- ---------- Storage: review-logos bucket ----------
-- Public INSERT is intentional: a customer submitting a pending
-- review from the review page uploads their own logo directly, before
-- any admin has logged in. Only admin can UPDATE/DELETE (moderation
-- cleanup); anon never gets those.
-- As with the documents bucket, no public SELECT policy — the bucket is
-- public so logos load fine over their public URL, and omitting it stops
-- anyone from listing the whole bucket.
drop policy if exists "review_logos_bucket_public_read" on storage.objects;

drop policy if exists "review_logos_bucket_public_insert" on storage.objects;
create policy "review_logos_bucket_public_insert"
  on storage.objects for insert
  to anon, authenticated
  with check (bucket_id = 'review-logos');

drop policy if exists "review_logos_bucket_admin_update" on storage.objects;
create policy "review_logos_bucket_admin_update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'review-logos') with check (bucket_id = 'review-logos');

drop policy if exists "review_logos_bucket_admin_delete" on storage.objects;
create policy "review_logos_bucket_admin_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'review-logos');

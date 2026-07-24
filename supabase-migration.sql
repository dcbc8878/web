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
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

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

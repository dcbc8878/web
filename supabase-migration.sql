-- ============================================================
-- DCBC: documents library + reviews moderation + portal codes
-- Run in Supabase SQL Editor, top to bottom.
--
-- SAFE TO RE-RUN. Every statement is idempotent: tables use
-- "if not exists", policies are dropped before being recreated
-- (Postgres has no "create policy if not exists"), and the
-- function uses "create or replace".
--
-- Prerequisite: create the four storage buckets first via
-- Dashboard -> Storage (documents, review-logos, app-releases,
-- article-images) so the bucket_id values referenced below already exist.
-- ============================================================

create extension if not exists pgcrypto; -- gen_random_uuid()

-- ============================================================
-- admin_users — who may log into the back office, and what each
-- of them is allowed to touch.
--
-- IMPORTANT: these permissions are enforced here, in RLS, not in
-- the browser. Hiding a tab in the admin page is only cosmetic —
-- anyone who can log in could otherwise call the API directly. The
-- policies further down all gate writes on has_perm(...), so a user
-- without a permission is refused by Postgres itself.
--
-- Logins themselves are still created in Supabase Dashboard ->
-- Authentication -> Users. The trigger below then adds the matching
-- row here automatically, with every permission off, so a new
-- account can see nothing until the owner grants it.
-- ============================================================
create table if not exists public.admin_users (
  id              uuid primary key references auth.users(id) on delete cascade,
  email           text not null,
  display_name    text,
  role            text not null default 'staff' check (role in ('owner', 'staff')),
  perm_documents  boolean not null default false,
  perm_reviews    boolean not null default false,
  perm_codes      boolean not null default false,
  perm_releases   boolean not null default false,
  perm_articles   boolean not null default false,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now()
);

-- Both helpers are SECURITY DEFINER so they can read admin_users
-- without tripping that table's own RLS (which would recurse).
create or replace function public.is_owner()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select role = 'owner' and is_active from public.admin_users where id = auth.uid()),
    false
  );
$$;

create or replace function public.has_perm(feature text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select is_active and case feature
      when 'documents' then perm_documents
      when 'reviews'   then perm_reviews
      when 'codes'     then perm_codes
      when 'releases'  then perm_releases
      when 'articles'  then perm_articles
      else false
    end
    from public.admin_users
    where id = auth.uid()
  ), false);
$$;

revoke all on function public.is_owner() from public;
revoke all on function public.has_perm(text) from public;
grant execute on function public.is_owner() to authenticated;
grant execute on function public.has_perm(text) to authenticated;

alter table public.admin_users enable row level security;

-- Every signed-in user may read their own row — the admin page needs
-- it to know which tabs to show.
drop policy if exists "admin_users_read_self" on public.admin_users;
create policy "admin_users_read_self"
  on public.admin_users for select
  to authenticated
  using (id = auth.uid());

drop policy if exists "admin_users_owner_read_all" on public.admin_users;
create policy "admin_users_owner_read_all"
  on public.admin_users for select
  to authenticated
  using (public.is_owner());

drop policy if exists "admin_users_owner_update" on public.admin_users;
create policy "admin_users_owner_update"
  on public.admin_users for update
  to authenticated
  using (public.is_owner())
  with check (public.is_owner());

-- An owner cannot delete their own row, which would otherwise leave
-- the system with no one able to manage users.
drop policy if exists "admin_users_owner_delete" on public.admin_users;
create policy "admin_users_owner_delete"
  on public.admin_users for delete
  to authenticated
  using (public.is_owner() and id <> auth.uid());

-- ---------- admin_invites ----------
-- The owner records who may join and what they'll be allowed to do
-- BEFORE the account exists. The invite email itself is sent from the
-- Supabase dashboard (that needs a service-role key, which must never
-- be put in a web page). When the invited person accepts and their
-- account is created, the trigger below applies these permissions and
-- clears the invite.
create table if not exists public.admin_invites (
  email           text primary key,
  display_name    text,
  perm_documents  boolean not null default false,
  perm_reviews    boolean not null default false,
  perm_codes      boolean not null default false,
  perm_releases   boolean not null default false,
  perm_articles   boolean not null default false,
  created_at      timestamptz not null default now()
);

alter table public.admin_invites enable row level security;

drop policy if exists "admin_invites_owner_all" on public.admin_invites;
create policy "admin_invites_owner_all"
  on public.admin_invites for all
  to authenticated
  using (public.is_owner())
  with check (public.is_owner());

-- Pre-approved company accounts, so they arrive with permissions already
-- set instead of an owner having to grant them afterwards.
insert into public.admin_invites (email, display_name, perm_documents, perm_reviews, perm_codes, perm_releases, perm_articles)
values
  ('center@dcbc.co.th', 'ศูนย์กลาง', true, true, true, true, true),
  ('tepmongkon.s@dcbc.co.th', 'คุณเทพมงคล ศรีคมศักดิ์', true, true, true, true, true)
on conflict (email) do nothing;

-- New Supabase Auth users automatically get a row here. An invited
-- address arrives with its permissions already applied; anyone else
-- lands with nothing enabled and has to be granted access explicitly.
create or replace function public.handle_new_admin_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  inv public.admin_invites%rowtype;
begin
  select * into inv from public.admin_invites where lower(email) = lower(new.email);

  insert into public.admin_users (
    id, email, display_name,
    perm_documents, perm_reviews, perm_codes, perm_releases, perm_articles
  )
  values (
    new.id, new.email, inv.display_name,
    coalesce(inv.perm_documents, false),
    coalesce(inv.perm_reviews, false),
    coalesce(inv.perm_codes, false),
    coalesce(inv.perm_releases, false),
    coalesce(inv.perm_articles, false)
  )
  on conflict (id) do nothing;

  delete from public.admin_invites where lower(email) = lower(new.email);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_admin_user();

-- Backfill accounts that already existed before this table did.
insert into public.admin_users (id, email)
select id, email from auth.users
on conflict (id) do nothing;

-- The very first account becomes the owner with every permission, so
-- there is always someone who can grant access to everyone else.
update public.admin_users set
  role = 'owner', display_name = coalesce(display_name, 'ผู้ดูแลระบบ'),
  perm_documents = true, perm_reviews = true, perm_codes = true,
  perm_releases = true, perm_articles = true, is_active = true
where id = (select id from public.admin_users order by created_at asc limit 1)
  and not exists (select 1 from public.admin_users where role = 'owner');

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

-- Admin dashboard reads the full list directly once logged in. The public
-- /portal page deliberately does NOT get a policy here — it must go
-- through get_portal_documents() below instead, which only returns rows
-- once it has checked a portal code server-side. A direct "anon can select"
-- policy would mean anyone with the public anon key (already embedded in
-- supabase-client.js) could read every document over the REST API with no
-- code check at all — the /portal code screen would still be checked, but
-- the code would never actually gate access to anything.
drop policy if exists "documents_public_read" on public.documents;
drop policy if exists "documents_admin_read" on public.documents;
create policy "documents_admin_read"
  on public.documents for select
  to authenticated
  using (true);

drop policy if exists "documents_admin_insert" on public.documents;
create policy "documents_admin_insert"
  on public.documents for insert
  to authenticated
  with check (public.has_perm('documents'));

drop policy if exists "documents_admin_update" on public.documents;
create policy "documents_admin_update"
  on public.documents for update
  to authenticated
  using (public.has_perm('documents')) with check (public.has_perm('documents'));

drop policy if exists "documents_admin_delete" on public.documents;
create policy "documents_admin_delete"
  on public.documents for delete
  to authenticated
  using (public.has_perm('documents'));

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
  using (public.has_perm('reviews'));

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
  using (public.has_perm('reviews')) with check (public.has_perm('reviews'));

drop policy if exists "reviews_admin_delete" on public.reviews;
create policy "reviews_admin_delete"
  on public.reviews for delete
  to authenticated
  using (public.has_perm('reviews'));

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
  using (public.has_perm('codes'));

drop policy if exists "portal_codes_admin_insert" on public.portal_codes;
create policy "portal_codes_admin_insert"
  on public.portal_codes for insert
  to authenticated
  with check (public.has_perm('codes'));

drop policy if exists "portal_codes_admin_update" on public.portal_codes;
create policy "portal_codes_admin_update"
  on public.portal_codes for update
  to authenticated
  using (public.has_perm('codes')) with check (public.has_perm('codes'));

drop policy if exists "portal_codes_admin_delete" on public.portal_codes;
create policy "portal_codes_admin_delete"
  on public.portal_codes for delete
  to authenticated
  using (public.has_perm('codes'));

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

-- Callable by anon (and authenticated) from /portal to actually fetch the
-- document list — the counterpart to check_portal_code() above, which only
-- ever confirms a code is valid but was never wired to gate document access
-- itself. SECURITY DEFINER so it can read public.documents despite anon
-- having no direct select policy on that table; returns zero rows whenever
-- input_code doesn't match an active portal code, so a revoked or wrong
-- code can never come back with data.
create or replace function public.get_portal_documents(input_code text)
returns setof public.documents
language sql
stable
security definer
set search_path = public
as $$
  select d.* from public.documents d
  where exists (
    select 1 from public.portal_codes
    where code = upper(trim(input_code)) and active = true
  )
  order by d.sort_order asc;
$$;

revoke all on function public.get_portal_documents(text) from public;
grant execute on function public.get_portal_documents(text) to anon, authenticated;

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
  file_path     text,                   -- storage key inside 'app-releases' bucket (null when external_url is used)
  file_name     text,                   -- original filename, for the download attribute (null when external_url is used)
  file_size     bigint,
  external_url  text,                   -- direct download URL (e.g. GitHub Releases) used instead of storage
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
  using (public.has_perm('releases'));

drop policy if exists "app_releases_admin_insert" on public.app_releases;
create policy "app_releases_admin_insert"
  on public.app_releases for insert
  to authenticated
  with check (public.has_perm('releases'));

drop policy if exists "app_releases_admin_update" on public.app_releases;
create policy "app_releases_admin_update"
  on public.app_releases for update
  to authenticated
  using (public.has_perm('releases')) with check (public.has_perm('releases'));

drop policy if exists "app_releases_admin_delete" on public.app_releases;
create policy "app_releases_admin_delete"
  on public.app_releases for delete
  to authenticated
  using (public.has_perm('releases'));

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
    'download_url', coalesce(
      external_url,
      'https://dqegkyobclqqichhnxfm.supabase.co/storage/v1/object/public/app-releases/' || file_path
    ),
    'released_at',  created_at
  )
  from public.app_releases
  where is_published = true
  order by created_at desc
  limit 1;
$$;

revoke all on function public.get_latest_app_release() from public;
grant execute on function public.get_latest_app_release() to anon, authenticated;

-- ---------- articles ----------
-- Blog posts. Rendered to static HTML at deploy time by
-- scripts/build-articles.mjs so search engines and AI crawlers get
-- real markup instead of a page that only fills in via JavaScript.
create table if not exists public.articles (
  id            uuid primary key default gen_random_uuid(),
  slug          text not null unique,   -- becomes /articles/<slug>
  title         text not null,
  excerpt       text,                   -- short summary for the listing + meta description
  content       text not null,          -- body text, minimal markdown (##, -, **bold**, links)
  cover_path    text,                   -- storage key inside 'article-images' bucket
  source_url    text,                   -- original Facebook post, for reference
  is_published  boolean not null default false,
  published_at  timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

alter table public.articles enable row level security;

drop policy if exists "articles_public_read_published" on public.articles;
create policy "articles_public_read_published"
  on public.articles for select
  to anon
  using (is_published = true);

drop policy if exists "articles_admin_read_all" on public.articles;
create policy "articles_admin_read_all"
  on public.articles for select
  to authenticated
  using (public.has_perm('articles'));

drop policy if exists "articles_admin_insert" on public.articles;
create policy "articles_admin_insert"
  on public.articles for insert
  to authenticated
  with check (public.has_perm('articles'));

drop policy if exists "articles_admin_update" on public.articles;
create policy "articles_admin_update"
  on public.articles for update
  to authenticated
  using (public.has_perm('articles')) with check (public.has_perm('articles'));

drop policy if exists "articles_admin_delete" on public.articles;
create policy "articles_admin_delete"
  on public.articles for delete
  to authenticated
  using (public.has_perm('articles'));

-- ---------- Storage: article-images bucket ----------
drop policy if exists "article_images_bucket_admin_insert" on storage.objects;
create policy "article_images_bucket_admin_insert"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'article-images' and public.has_perm('articles'));

drop policy if exists "article_images_bucket_admin_update" on storage.objects;
create policy "article_images_bucket_admin_update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'article-images' and public.has_perm('articles')) with check (bucket_id = 'article-images' and public.has_perm('articles'));

drop policy if exists "article_images_bucket_admin_delete" on storage.objects;
create policy "article_images_bucket_admin_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'article-images' and public.has_perm('articles'));

-- ---------- Storage: app-releases bucket ----------
-- Public bucket, so the installer downloads over its public URL with no
-- auth. Only the admin can upload or remove builds.
drop policy if exists "app_releases_bucket_admin_insert" on storage.objects;
create policy "app_releases_bucket_admin_insert"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'app-releases' and public.has_perm('releases'));

drop policy if exists "app_releases_bucket_admin_update" on storage.objects;
create policy "app_releases_bucket_admin_update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'app-releases' and public.has_perm('releases')) with check (bucket_id = 'app-releases' and public.has_perm('releases'));

drop policy if exists "app_releases_bucket_admin_delete" on storage.objects;
create policy "app_releases_bucket_admin_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'app-releases' and public.has_perm('releases'));

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
  with check (bucket_id = 'documents' and public.has_perm('documents'));

drop policy if exists "documents_bucket_admin_update" on storage.objects;
create policy "documents_bucket_admin_update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'documents' and public.has_perm('documents')) with check (bucket_id = 'documents' and public.has_perm('documents'));

drop policy if exists "documents_bucket_admin_delete" on storage.objects;
create policy "documents_bucket_admin_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'documents' and public.has_perm('documents'));

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

-- Hard limits enforced by Storage itself, not just this RLS policy — RLS
-- only checks bucket_id, so without this an anonymous upload could ship a
-- huge file or any file type through the same public INSERT above. Max 5
-- MB, images only.
update storage.buckets
set file_size_limit = 5242880,
    allowed_mime_types = array['image/png', 'image/jpeg', 'image/webp', 'image/gif']
where id = 'review-logos';

drop policy if exists "review_logos_bucket_admin_update" on storage.objects;
create policy "review_logos_bucket_admin_update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'review-logos' and public.has_perm('reviews')) with check (bucket_id = 'review-logos' and public.has_perm('reviews'));

drop policy if exists "review_logos_bucket_admin_delete" on storage.objects;
create policy "review_logos_bucket_admin_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'review-logos' and public.has_perm('reviews'));

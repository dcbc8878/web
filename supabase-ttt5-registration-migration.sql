-- ============================================================
-- DCBC: TTT5 party registration form (/ttt5.form)
-- Run in Supabase SQL Editor, top to bottom.
--
-- SAFE TO RE-RUN. Table/bucket use "if not exists", policies are
-- dropped before being recreated, functions use "create or replace".
--
-- This feature is self-contained and temporary (one event). It does
-- not touch any other table, bucket or function. See the TEARDOWN
-- block at the bottom to remove it entirely once the event is over.
-- ============================================================

-- ---------- ttt5_registrations ----------
-- One row per person who filled the form (whether attending or not).
-- No public SELECT/UPDATE/DELETE policy at all -- names, shirt sizes
-- and payment slip paths are only ever readable through the PIN-gated
-- admin functions below, never by a direct table read from the browser.
create table if not exists public.ttt5_registrations (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,
  attending         boolean not null,
  shirt_size        text not null,
  has_companions    boolean not null default false,
  adult_companions  smallint not null default 0,
  child_companions  smallint not null default 0,
  total_people      smallint not null default 1,
  paying_people     smallint not null default 1,
  total_amount      integer not null default 0,
  slip_path         text,      -- storage key inside 'ttt5-slips' bucket, null when not attending
  slip_file_name    text,      -- original filename, for the admin download button
  dietary_notes     text,      -- free text composed client-side from checkbox picks, e.g. "อิสลาม, แพ้อาหารทะเล: กุ้ง"; null when not attending
  created_at        timestamptz not null default now()
);

-- Added after the table already existed live -- kept here (in addition to
-- the column above) so this file stays accurate for both a fresh deploy
-- and re-running against the already-deployed table.
alter table public.ttt5_registrations add column if not exists dietary_notes text;

alter table public.ttt5_registrations enable row level security;

drop policy if exists "ttt5_public_insert" on public.ttt5_registrations;
create policy "ttt5_public_insert"
  on public.ttt5_registrations for insert
  to anon, authenticated
  with check (true);

-- Lets the form warn "already registered" without ever exposing the
-- roster itself to the browser. Same shape as check_portal_code().
create or replace function public.ttt5_check_duplicate_name(input_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.ttt5_registrations
    where regexp_replace(name, '\s+', '', 'g') = regexp_replace(input_name, '\s+', '', 'g')
  );
$$;

revoke all on function public.ttt5_check_duplicate_name(text) from public;
grant execute on function public.ttt5_check_duplicate_name(text) to anon, authenticated;

-- Powers the "ขณะนี้มีผู้ตอบแบบฟอร์มแล้วทั้งหมด N รายการ" line on the
-- thank-you screen.
create or replace function public.ttt5_count()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer from public.ttt5_registrations;
$$;

revoke all on function public.ttt5_count() from public;
grant execute on function public.ttt5_count() to anon, authenticated;

-- ---------- Admin (PIN-gated, server-side) ----------
-- The prototype this page was adapted from checked the admin PIN in the
-- browser (readable via view-source). These three functions move that
-- check into Postgres instead -- the PIN below never ships to the
-- client. Change the PIN by replacing 'TTT5' in all three functions.

create or replace function public.ttt5_check_admin_pin(input_pin text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select input_pin = 'TTT5';
$$;

revoke all on function public.ttt5_check_admin_pin(text) from public;
grant execute on function public.ttt5_check_admin_pin(text) to anon, authenticated;

-- Full registration list, including slip_path, but only when the PIN
-- matches -- called after ttt5_check_admin_pin() already gated entry to
-- the admin screen, and again on every refresh from it.
create or replace function public.ttt5_admin_list(input_pin text)
returns setof public.ttt5_registrations
language sql
stable
security definer
set search_path = public
as $$
  select * from public.ttt5_registrations
  where input_pin = 'TTT5'
  order by created_at desc;
$$;

revoke all on function public.ttt5_admin_list(text) from public;
grant execute on function public.ttt5_admin_list(text) to anon, authenticated;

create or replace function public.ttt5_admin_delete(input_pin text, target_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if input_pin <> 'TTT5' then
    return false;
  end if;
  delete from public.ttt5_registrations where id = target_id;
  return found;
end;
$$;

revoke all on function public.ttt5_admin_delete(text, uuid) from public;
grant execute on function public.ttt5_admin_delete(text, uuid) to anon, authenticated;

-- ---------- Storage: ttt5-slips bucket ----------
-- Public bucket (like review-logos/documents/app-releases): files load
-- over their public URL with no auth needed. Public INSERT is
-- intentional -- a guest uploads their own payment slip before any
-- admin is involved. No public SELECT policy: the bucket being public
-- already serves objects fine, and adding one would let anyone LIST
-- every slip in the bucket. No UPDATE/DELETE for anon either.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('ttt5-slips', 'ttt5-slips', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

drop policy if exists "ttt5_slips_bucket_public_insert" on storage.objects;
create policy "ttt5_slips_bucket_public_insert"
  on storage.objects for insert
  to anon, authenticated
  with check (bucket_id = 'ttt5-slips');

-- ============================================================
-- TEARDOWN -- run manually once the event is over and this page is
-- no longer needed. Uncomment and run in the SQL editor.
-- ============================================================
-- drop function if exists public.ttt5_admin_delete(text, uuid);
-- drop function if exists public.ttt5_admin_list(text);
-- drop function if exists public.ttt5_check_admin_pin(text);
-- drop function if exists public.ttt5_check_duplicate_name(text);
-- drop function if exists public.ttt5_count();
-- drop table if exists public.ttt5_registrations;
-- delete from storage.objects where bucket_id = 'ttt5-slips';
-- delete from storage.buckets where id = 'ttt5-slips';

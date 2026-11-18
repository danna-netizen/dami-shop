-- ============================================================
--  Dami Shop — Supabase schema, security and policies
--  Run this in Supabase → SQL Editor (New query) and press RUN.
--  Then run db/seed.sql (products) and db/ui_text.sql the same way.
--  All three files are safe to run again.
--
--  SHARED PROJECT: this Supabase project is also used by the
--  clickjacking demo in "Documents/Dami Shop". This file only ADDS
--  tables, columns and policies and never removes anything the demo
--  uses, so both keep working.
--
--  SIGN-UP (one step): the page calls Supabase Auth signUp() with
--  name, street, city, postal code and phone as user metadata. The trigger
--  below creates the profile from that metadata on the server, so it
--  also works when "Confirm email" is turned on.
-- ============================================================

grant usage on schema public to anon, authenticated;

-- 1) PROFILES -------------------------------------------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  name       text,
  email      text,
  address    text,              -- street and house number
  created_at timestamptz not null default now()
);
alter table public.profiles
  add column if not exists name    text,
  add column if not exists email   text,
  add column if not exists address text,
  add column if not exists city    text,
  add column if not exists zip     text,
  add column if not exists phone   text;

alter table public.profiles enable row level security;
drop policy if exists "own profile read"   on public.profiles;
drop policy if exists "own profile insert" on public.profiles;   -- the demo inserts its own profiles
create policy "own profile read"   on public.profiles for select to authenticated using (auth.uid() = id);
create policy "own profile insert" on public.profiles for insert to authenticated with check (auth.uid() = id);
grant select, insert on public.profiles to authenticated;

-- Creates the Dami Shop profile when a user signs up. Users created
-- without a "name" in their metadata (e.g. by the demo, which inserts
-- its own profile) are left alone.
create or replace function public.dami_handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare m jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  if length(trim(coalesce(m ->> 'name', ''))) = 0 then return new; end if;
  insert into public.profiles (id, name, email, address, city, zip, phone)
  values (new.id,
          left(trim(m ->> 'name'), 80),
          new.email,
          left(trim(coalesce(m ->> 'street', '')), 150),
          left(trim(coalesce(m ->> 'city', '')), 80),
          left(trim(coalesce(m ->> 'zip', '')), 10),
          left(trim(coalesce(m ->> 'phone', '')), 20))
  on conflict (id) do nothing;
  return new;
end $$;
revoke all on function public.dami_handle_new_user() from public, anon, authenticated;

drop trigger if exists dami_on_auth_user_created on auth.users;
create trigger dami_on_auth_user_created
  after insert on auth.users
  for each row execute function public.dami_handle_new_user();

-- 2) PRODUCTS -------------------------------------------------
-- Prices live in this table on the server, NOT in the HTML, and are
-- readable only by signed-in users.
create table if not exists public.products (
  id          bigint generated always as identity primary key,
  category    text    not null,
  name        text    not null,
  base_price  numeric not null,
  icon        text,
  bg          text,
  description text,
  on_sale     boolean not null default false,
  sort        int     not null default 0
);
alter table public.products enable row level security;
drop policy if exists "products readable by registered"    on public.products;
drop policy if exists "products readable by authenticated" on public.products;
create policy "products readable by authenticated"
  on public.products for select to authenticated using (true);
grant select on public.products to authenticated;

-- 3) ORDERS ---------------------------------------------------
-- Dami Shop uses code / items / total / reason; the demo uses
-- item / price. Every column is optional so both can insert rows.
create table if not exists public.orders (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.orders
  add column if not exists code    text,
  add column if not exists items   jsonb,
  add column if not exists total   numeric,
  add column if not exists method  text,
  add column if not exists address text,
  add column if not exists status  text,
  add column if not exists reason  text;
do $$ begin
  -- columns created by the demo as NOT NULL → make them optional
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'orders' and column_name = 'item') then
    alter table public.orders alter column item drop not null;
  end if;
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'orders' and column_name = 'price') then
    alter table public.orders alter column price drop not null;
  end if;
end $$;

alter table public.orders enable row level security;
drop policy if exists "own orders read"   on public.orders;
drop policy if exists "own orders insert" on public.orders;
drop policy if exists "own orders update" on public.orders;
create policy "own orders read"   on public.orders for select to authenticated using (auth.uid() = user_id);
create policy "own orders insert" on public.orders for insert to authenticated with check (auth.uid() = user_id);
create policy "own orders update" on public.orders for update to authenticated using (auth.uid() = user_id);
grant select, insert, update on public.orders to authenticated;

-- 4) UI TEXT --------------------------------------------------
create table if not exists public.ui_text (
  key text primary key,
  val text not null
);
alter table public.ui_text enable row level security;
drop policy if exists "ui_text readable by registered"    on public.ui_text;
drop policy if exists "ui_text readable by authenticated" on public.ui_text;
create policy "ui_text readable by authenticated"
  on public.ui_text for select to authenticated using (true);
grant select on public.ui_text to authenticated;

-- Run this in Supabase SQL Editor.
-- After running it, create two auth users in Supabase Auth and link them with the
-- example UPDATE statements at the bottom.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  slug text primary key check (slug in ('scalii', 'koi')),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  display_name text not null,
  battletag text not null,
  battletag_slug text not null,
  blizzard_profile_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  profile_slug text not null references public.profiles(slug) on delete cascade,
  played_on date not null default current_date,
  role text not null check (role in ('tank', 'damage', 'support', 'open_queue')),
  hero text not null,
  result text not null check (result in ('win', 'loss')),
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.rank_snapshots (
  id uuid primary key default gen_random_uuid(),
  profile_slug text not null references public.profiles(slug) on delete cascade,
  role text not null check (role in ('tank', 'damage', 'support', 'open_queue')),
  rank_label text,
  division text,
  source text default 'manual',
  raw_data jsonb,
  synced_at timestamptz not null default now(),
  unique (profile_slug, role)
);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
before update on public.profiles
for each row execute function public.touch_updated_at();

drop trigger if exists matches_touch_updated_at on public.matches;
create trigger matches_touch_updated_at
before update on public.matches
for each row execute function public.touch_updated_at();

alter table public.profiles enable row level security;
alter table public.matches enable row level security;
alter table public.rank_snapshots enable row level security;

-- Public can view profiles, matches, and ranks.
drop policy if exists "profiles are public readable" on public.profiles;
create policy "profiles are public readable"
on public.profiles for select
using (true);

drop policy if exists "owners can update their profile" on public.profiles;
create policy "owners can update their profile"
on public.profiles for update
using (auth.uid() = auth_user_id)
with check (auth.uid() = auth_user_id);

drop policy if exists "matches are public readable" on public.matches;
create policy "matches are public readable"
on public.matches for select
using (true);

drop policy if exists "owners can insert matches" on public.matches;
create policy "owners can insert matches"
on public.matches for insert
with check (
  exists (
    select 1
    from public.profiles p
    where p.slug = matches.profile_slug
      and p.auth_user_id = auth.uid()
  )
);

drop policy if exists "owners can update matches" on public.matches;
create policy "owners can update matches"
on public.matches for update
using (
  exists (
    select 1
    from public.profiles p
    where p.slug = matches.profile_slug
      and p.auth_user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.profiles p
    where p.slug = matches.profile_slug
      and p.auth_user_id = auth.uid()
  )
);

drop policy if exists "owners can delete matches" on public.matches;
create policy "owners can delete matches"
on public.matches for delete
using (
  exists (
    select 1
    from public.profiles p
    where p.slug = matches.profile_slug
      and p.auth_user_id = auth.uid()
  )
);

drop policy if exists "ranks are public readable" on public.rank_snapshots;
create policy "ranks are public readable"
on public.rank_snapshots for select
using (true);

drop policy if exists "owners can insert ranks" on public.rank_snapshots;
create policy "owners can insert ranks"
on public.rank_snapshots for insert
with check (
  exists (
    select 1
    from public.profiles p
    where p.slug = rank_snapshots.profile_slug
      and p.auth_user_id = auth.uid()
  )
);

drop policy if exists "owners can update ranks" on public.rank_snapshots;
create policy "owners can update ranks"
on public.rank_snapshots for update
using (
  exists (
    select 1
    from public.profiles p
    where p.slug = rank_snapshots.profile_slug
      and p.auth_user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.profiles p
    where p.slug = rank_snapshots.profile_slug
      and p.auth_user_id = auth.uid()
  )
);

drop policy if exists "owners can delete ranks" on public.rank_snapshots;
create policy "owners can delete ranks"
on public.rank_snapshots for delete
using (
  exists (
    select 1
    from public.profiles p
    where p.slug = rank_snapshots.profile_slug
      and p.auth_user_id = auth.uid()
  )
);

insert into public.profiles (slug, display_name, battletag, battletag_slug, blizzard_profile_url)
values
  ('scalii', 'Scalii', 'Scalii#2905', 'Scalii-2905', 'https://overwatch.blizzard.com/en-us/career/c15dad86ba78d6ffb0a022%7Cab18d17d2e26f8db1868b8f0c0a98492/'),
  ('koi', 'Koi', 'Koi#21676', 'Koi-21676', null)
on conflict (slug) do update
set
  display_name = excluded.display_name,
  battletag = excluded.battletag,
  battletag_slug = excluded.battletag_slug,
  blizzard_profile_url = excluded.blizzard_profile_url,
  updated_at = now();

-- After you create auth users, link each profile to its user account with:
-- update public.profiles
-- set auth_user_id = (select id from auth.users where email = 'your-scalii-email@example.com')
-- where slug = 'scalii';
--
-- update public.profiles
-- set auth_user_id = (select id from auth.users where email = 'your-koi-email@example.com')
-- where slug = 'koi';

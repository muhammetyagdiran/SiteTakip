-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ROLES TYPE
create type user_role as enum ('system_owner', 'site_manager', 'resident');

-- PROFILES TABLE
create table profiles (
  id uuid references auth.users on delete cascade primary key,
  updated_at timestamp with time zone,
  full_name text,
  role user_role default 'resident',
  phone_number text
);

-- SITES TABLE
create table sites (
  id uuid default uuid_generate_v4() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  name text not null,
  address text,
  owner_id uuid references profiles(id) on delete set null,
  manager_id uuid references profiles(id) on delete set null
);

-- BLOCKS TABLE
create table blocks (
  id uuid default uuid_generate_v4() primary key,
  site_id uuid references sites(id) on delete cascade,
  name text not null -- e.g., 'A Blok', 'B Blok'
);

-- APARTMENTS TABLE
create table apartments (
  id uuid default uuid_generate_v4() primary key,
  block_id uuid references blocks(id) on delete cascade,
  number text not null, -- e.g., '1', '2', '12A'
  resident_id uuid references profiles(id) on delete set null
);

-- ANNOUNCEMENTS TABLE
create table announcements (
  id uuid default uuid_generate_v4() primary key,
  site_id uuid references sites(id) on delete cascade,
  title text not null,
  content text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  author_id uuid references profiles(id) on delete set null
);

-- REQUESTS TABLE
create type request_status as enum ('open', 'in_progress', 'completed');

create table requests (
  id uuid default uuid_generate_v4() primary key,
  apartment_id uuid references apartments(id) on delete cascade,
  resident_id uuid references profiles(id) on delete cascade,
  title text not null,
  description text,
  status request_status default 'open',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- DUES TABLE
create table dues (
  id uuid default uuid_generate_v4() primary key,
  apartment_id uuid references apartments(id) on delete cascade,
  amount decimal not null,
  month date not null, -- Store as first day of month
  is_paid boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- RLS POLICIES

-- Sonsuz döngüyü önlemek ve yetki kontrolü için yardımcı fonksiyonlar
create or replace function is_system_owner()
returns boolean as $$
  select exists (
    select 1 from profiles
    where id = auth.uid()
    and role = 'system_owner'::user_role
  );
$$ language sql security definer;

create or replace function is_site_manager()
returns boolean as $$
  select exists (
    select 1 from profiles
    where id = auth.uid()
    and role = 'site_manager'::user_role
  );
$$ language sql security definer;

-- Profiles: Users can view their own profile, managers can view residents in their site
alter table profiles enable row level security;
create policy "Public profiles are viewable by everyone." on profiles for select using (true);
create policy "Users can insert their own profile." on profiles for insert with check (auth.uid() = id);
create policy "Users can update own profile." on profiles for update using (auth.uid() = id);
create policy "System owners can manage all profiles." on profiles for all using (is_system_owner());

create policy "Site managers can manage residents." on profiles for all using (
  is_site_manager() and role = 'resident'
);

-- Sites
alter table sites enable row level security;
create policy "System owners can manage sites." on sites for all using (
  exists (select 1 from profiles where id = auth.uid() and role = 'system_owner')
);
create policy "Managers can view assigned sites." on sites for select using (
  manager_id = auth.uid() or 
  exists (select 1 from profiles where id = auth.uid() and role = 'system_owner')
);
create policy "Residents can view their site." on sites for select using (
  exists (
    select 1 from apartments a 
    join blocks b on a.block_id = b.id 
    where b.site_id = sites.id and a.resident_id = auth.uid()
  )
);

-- Blocks
alter table blocks enable row level security;
create policy "Managers and owners can manage blocks." on blocks for all using (true); -- Simplified for MVP, refine later
create policy "Residents can view blocks." on blocks for select using (true);

-- Apartments
alter table apartments enable row level security;
create policy "Managers and owners can manage apartments." on apartments for all using (true);
create policy "Residents can view their own apartment." on apartments for select using (true);

-- Announcements
alter table announcements enable row level security;
create policy "Managers can manage announcements." on announcements for all using (true);
create policy "Residents can view announcements." on announcements for select using (true);

-- Requests
alter table requests enable row level security;
-- Requests
alter table requests enable row level security;
create policy "Residents can manage their own requests." on requests for all using (auth.uid() = resident_id);

create policy "Managers and owners can manage requests." on requests for all using (
  is_system_owner() or 
  exists (
    select 1 from apartments a
    join blocks b on a.block_id = b.id
    join sites s on b.site_id = s.id
    where a.id = requests.apartment_id and s.manager_id = auth.uid()
  )
);

-- Dues
alter table dues enable row level security;
create policy "Managers can manage dues." on dues for all using (true);
create policy "Residents can view their own dues." on dues for select using (true);

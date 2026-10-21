-- =====================================================================
-- Me visto como quiero - esquema de base de datos para Supabase
-- Pegá TODO esto en Supabase > SQL Editor > New query > Run.
-- Se puede volver a correr sin romper nada.
-- =====================================================================

-- 1) Tabla de prendas -------------------------------------------------
create table if not exists public.prendas (
  id          uuid primary key default gen_random_uuid(),
  nombre      text not null,
  descripcion text not null default '',
  precio      numeric(12,2) not null default 0,
  categoria   text not null default '',
  talles      text[] not null default '{}',
  imagen_url  text,
  imagen_path text,
  disponible  boolean not null default true,
  created_at  timestamptz not null default now()
);

-- 2) Lista de administradores (emails que pueden editar) --------------
create table if not exists public.admins (
  email text primary key
);

-- Devuelve true si el usuario logueado está en la tabla admins.
create or replace function public.es_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admins
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

-- 3) Seguridad (RLS) ---------------------------------------------------
alter table public.prendas enable row level security;
alter table public.admins  enable row level security;  -- nadie la lee desde la app

drop policy if exists "todos ven prendas visibles" on public.prendas;
create policy "todos ven prendas visibles" on public.prendas
  for select using (disponible or public.es_admin());

drop policy if exists "admin crea prendas" on public.prendas;
create policy "admin crea prendas" on public.prendas
  for insert to authenticated with check (public.es_admin());

drop policy if exists "admin edita prendas" on public.prendas;
create policy "admin edita prendas" on public.prendas
  for update to authenticated using (public.es_admin()) with check (public.es_admin());

drop policy if exists "admin borra prendas" on public.prendas;
create policy "admin borra prendas" on public.prendas
  for delete to authenticated using (public.es_admin());

-- 4) Fotos (Storage) ---------------------------------------------------
insert into storage.buckets (id, name, public)
values ('fotos', 'fotos', true)
on conflict (id) do update set public = true;

drop policy if exists "fotos se ven" on storage.objects;
create policy "fotos se ven" on storage.objects
  for select using (bucket_id = 'fotos');

drop policy if exists "admin sube fotos" on storage.objects;
create policy "admin sube fotos" on storage.objects
  for insert to authenticated with check (bucket_id = 'fotos' and public.es_admin());

drop policy if exists "admin cambia fotos" on storage.objects;
create policy "admin cambia fotos" on storage.objects
  for update to authenticated using (bucket_id = 'fotos' and public.es_admin());

drop policy if exists "admin borra fotos" on storage.objects;
create policy "admin borra fotos" on storage.objects
  for delete to authenticated using (bucket_id = 'fotos' and public.es_admin());

-- 5) Administradores ---------------------------------------------------
-- Cambiá estos emails por los reales (el tuyo y el de tu amigo).
-- Cada uno tiene que existir también en Authentication > Users.
insert into public.admins (email) values
  ('tu_email@ejemplo.com'),
  ('email_de_tu_amigo@ejemplo.com')
on conflict do nothing;

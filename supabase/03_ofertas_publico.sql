-- =====================================================================
-- Any.G - Ofertas y público (Mujer / Hombre / Niños / Unisex)
-- Correr DESPUÉS de 02_stock_ventas.sql. Se puede volver a correr.
-- =====================================================================

-- 1) Público de cada prenda ---------------------------------------------
alter table public.prendas
  add column if not exists publico text not null default '';

-- 2) Ofertas -------------------------------------------------------------
-- descuento: % que se aplica a todas sus prendas (ej. 20 = 20% off).
-- desde / hasta: opcionales. Vacíos = empieza ya / no vence.
create table if not exists public.ofertas (
  id         uuid primary key default gen_random_uuid(),
  nombre     text not null,
  descuento  numeric(5,2) not null default 0
             check (descuento >= 0 and descuento < 100),
  desde      timestamptz,
  hasta      timestamptz,
  activa     boolean not null default true,
  created_at timestamptz not null default now()
);

-- Prendas incluidas. precio_especial (opcional) reemplaza al % para esa prenda.
create table if not exists public.oferta_prendas (
  oferta_id       uuid not null references public.ofertas(id) on delete cascade,
  prenda_id       uuid not null references public.prendas(id) on delete cascade,
  precio_especial numeric(12,2),
  primary key (oferta_id, prenda_id)
);

-- ¿La oferta está vigente ahora?
create or replace function public.oferta_vigente(p_oferta uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.ofertas o
    where o.id = p_oferta
      and o.activa
      and (o.desde is null or o.desde <= now())
      and (o.hasta is null or o.hasta > now())
  );
$$;

alter table public.ofertas        enable row level security;
alter table public.oferta_prendas enable row level security;

-- Todos ven las ofertas vigentes; el admin ve todas.
drop policy if exists "ver ofertas" on public.ofertas;
create policy "ver ofertas" on public.ofertas
  for select using (public.es_admin() or public.oferta_vigente(id));

drop policy if exists "admin maneja ofertas" on public.ofertas;
create policy "admin maneja ofertas" on public.ofertas
  for all to authenticated using (public.es_admin()) with check (public.es_admin());

drop policy if exists "ver prendas en oferta" on public.oferta_prendas;
create policy "ver prendas en oferta" on public.oferta_prendas
  for select using (public.es_admin() or public.oferta_vigente(oferta_id));

drop policy if exists "admin maneja prendas en oferta" on public.oferta_prendas;
create policy "admin maneja prendas en oferta" on public.oferta_prendas
  for all to authenticated using (public.es_admin()) with check (public.es_admin());

-- Grants (en Supabase ya vienen, se dejan por las dudas)
grant select on public.ofertas, public.oferta_prendas to anon, authenticated;
grant insert, update, delete on public.ofertas, public.oferta_prendas to authenticated;

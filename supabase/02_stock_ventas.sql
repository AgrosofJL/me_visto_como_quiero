-- =====================================================================
-- Any.G - Stock, costos y ventas
-- Correr DESPUÉS de esquema.sql. Pegar todo en Supabase > SQL Editor > Run.
-- Se puede volver a correr sin romper nada.
-- =====================================================================

-- 1) Stock por talle dentro de cada prenda ----------------------------
-- Ej: {"S": 3, "M": 5, "L": 0}. Si la prenda no tiene talles: {"Único": 4}
-- Si está vacío {} la prenda no controla stock (se puede vender siempre).
alter table public.prendas
  add column if not exists stock jsonb not null default '{}'::jsonb;

-- 2) Costos (solo los ve el administrador) -----------------------------
create table if not exists public.costos (
  prenda_id uuid primary key references public.prendas(id) on delete cascade,
  costo     numeric(12,2) not null default 0
);
alter table public.costos enable row level security;
drop policy if exists "admin maneja costos" on public.costos;
create policy "admin maneja costos" on public.costos
  for all to authenticated using (public.es_admin()) with check (public.es_admin());

-- 3) Ventas (cabecera) e ítems -----------------------------------------
create table if not exists public.ventas (
  id          uuid primary key default gen_random_uuid(),
  numero      bigint generated always as identity,
  fecha       timestamptz not null default now(),
  cliente     text not null default '',
  forma_pago  text not null default 'Efectivo',
  canal       text not null default 'Local',
  nota        text not null default '',
  total       numeric(12,2) not null default 0,
  costo_total numeric(12,2) not null default 0,
  anulada     boolean not null default false,
  creada_por  text
);

create table if not exists public.venta_items (
  id              uuid primary key default gen_random_uuid(),
  venta_id        uuid not null references public.ventas(id) on delete cascade,
  prenda_id       uuid references public.prendas(id) on delete set null,
  nombre          text not null,
  categoria       text not null default '',
  talle           text not null default 'Único',
  cantidad        int  not null check (cantidad > 0),
  precio_unitario numeric(12,2) not null,
  costo_unitario  numeric(12,2) not null default 0
);

create index if not exists ventas_fecha_idx on public.ventas (fecha desc);
create index if not exists venta_items_venta_idx on public.venta_items (venta_id);

alter table public.ventas      enable row level security;
alter table public.venta_items enable row level security;

-- Solo el admin las puede ver. Se crean/anulan únicamente con las funciones de abajo.
drop policy if exists "admin ve ventas" on public.ventas;
create policy "admin ve ventas" on public.ventas
  for select to authenticated using (public.es_admin());

drop policy if exists "admin ve items" on public.venta_items;
create policy "admin ve items" on public.venta_items
  for select to authenticated using (public.es_admin());

-- 4) Registrar una venta: valida y descuenta stock en una sola operación ----
-- p_items: [{"prenda_id": "...", "talle": "M", "cantidad": 1, "precio": 15000}, ...]
create or replace function public.registrar_venta(
  p_items      jsonb,
  p_forma_pago text default 'Efectivo',
  p_cliente    text default '',
  p_nota       text default '',
  p_canal      text default 'Local'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id          uuid;
  it            jsonb;
  v_prenda      public.prendas%rowtype;
  v_talle       text;
  v_cant        int;
  v_precio      numeric;
  v_costo       numeric;
  v_disp        int;
  v_total       numeric := 0;
  v_costo_total numeric := 0;
begin
  if not public.es_admin() then
    raise exception 'No autorizado';
  end if;
  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'La venta no tiene prendas';
  end if;

  insert into public.ventas (forma_pago, cliente, nota, canal, creada_por)
  values (coalesce(p_forma_pago, 'Efectivo'), coalesce(p_cliente, ''),
          coalesce(p_nota, ''), coalesce(p_canal, 'Local'), auth.jwt() ->> 'email')
  returning id into v_id;

  for it in select * from jsonb_array_elements(p_items) loop
    v_cant   := (it ->> 'cantidad')::int;
    v_talle  := coalesce(nullif(it ->> 'talle', ''), 'Único');
    v_precio := coalesce((it ->> 'precio')::numeric, 0);

    if v_cant is null or v_cant <= 0 then
      raise exception 'Cantidad inválida';
    end if;

    select * into v_prenda from public.prendas
     where id = (it ->> 'prenda_id')::uuid
     for update;
    if not found then
      raise exception 'Prenda no encontrada';
    end if;

    -- Si la prenda controla stock, valida y descuenta.
    if v_prenda.stock <> '{}'::jsonb then
      v_disp := coalesce((v_prenda.stock ->> v_talle)::int, 0);
      if v_disp < v_cant then
        raise exception 'Stock insuficiente: "%" talle % (quedan %)',
          v_prenda.nombre, v_talle, v_disp;
      end if;
      update public.prendas
         set stock = jsonb_set(stock, array[v_talle], to_jsonb(v_disp - v_cant))
       where id = v_prenda.id;
    end if;

    select c.costo into v_costo from public.costos c where c.prenda_id = v_prenda.id;
    v_costo := coalesce(v_costo, 0);

    insert into public.venta_items
      (venta_id, prenda_id, nombre, categoria, talle, cantidad, precio_unitario, costo_unitario)
    values
      (v_id, v_prenda.id, v_prenda.nombre, v_prenda.categoria, v_talle, v_cant, v_precio, v_costo);

    v_total       := v_total + v_cant * v_precio;
    v_costo_total := v_costo_total + v_cant * v_costo;
  end loop;

  update public.ventas set total = v_total, costo_total = v_costo_total where id = v_id;
  return v_id;
end;
$$;

-- 5) Anular una venta: devuelve el stock y la marca como anulada -------
create or replace function public.anular_venta(p_venta uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  if not public.es_admin() then
    raise exception 'No autorizado';
  end if;
  if exists (select 1 from public.ventas where id = p_venta and anulada) then
    raise exception 'La venta ya estaba anulada';
  end if;

  for r in select * from public.venta_items where venta_id = p_venta and prenda_id is not null loop
    update public.prendas
       set stock = jsonb_set(stock, array[r.talle],
             to_jsonb(coalesce((stock ->> r.talle)::int, 0) + r.cantidad))
     where id = r.prenda_id
       and stock <> '{}'::jsonb;
  end loop;

  update public.ventas set anulada = true where id = p_venta;
end;
$$;

revoke execute on function public.registrar_venta(jsonb, text, text, text, text) from anon;
revoke execute on function public.anular_venta(uuid) from anon;

-- =====================================================================
-- Any.G - Rubros (tipos de productos: Ropa, Bijouterie, Ropa interior...)
-- Correr DESPUÉS de 03_ofertas_publico.sql. Se puede volver a correr.
-- =====================================================================

-- 1) Tabla de rubros ----------------------------------------------------
create table if not exists public.rubros (
  id         uuid primary key default gen_random_uuid(),
  nombre     text not null unique,
  orden      int  not null default 0,
  created_at timestamptz not null default now()
);

alter table public.rubros enable row level security;

drop policy if exists "todos ven rubros" on public.rubros;
create policy "todos ven rubros" on public.rubros
  for select using (true);

drop policy if exists "admin maneja rubros" on public.rubros;
create policy "admin maneja rubros" on public.rubros
  for all to authenticated using (public.es_admin()) with check (public.es_admin());

grant select on public.rubros to anon, authenticated;
grant insert, update, delete on public.rubros to authenticated;

-- Rubros iniciales (después se editan desde la app)
insert into public.rubros (nombre, orden) values
  ('Ropa', 1),
  ('Bijouterie', 2),
  ('Ropa interior', 3),
  ('Accesorios', 4)
on conflict (nombre) do nothing;

-- 2) Cada prenda pertenece a un rubro ----------------------------------
alter table public.prendas
  add column if not exists rubro_id uuid references public.rubros(id) on delete set null;

-- Lo que ya estaba cargado queda como "Ropa"
update public.prendas
   set rubro_id = (select id from public.rubros where nombre = 'Ropa')
 where rubro_id is null;

-- 3) Guardar el rubro en cada venta (para el tablero) -------------------
alter table public.venta_items
  add column if not exists rubro text not null default '';

-- Misma función de 02_stock_ventas.sql, ahora guardando también el rubro.
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
  v_rubro       text;
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

    v_costo := null;
    select c.costo into v_costo from public.costos c where c.prenda_id = v_prenda.id;
    v_costo := coalesce(v_costo, 0);

    v_rubro := null;
    select r.nombre into v_rubro from public.rubros r where r.id = v_prenda.rubro_id;

    insert into public.venta_items
      (venta_id, prenda_id, nombre, categoria, rubro, talle, cantidad, precio_unitario, costo_unitario)
    values
      (v_id, v_prenda.id, v_prenda.nombre, v_prenda.categoria, coalesce(v_rubro, ''),
       v_talle, v_cant, v_precio, v_costo);

    v_total       := v_total + v_cant * v_precio;
    v_costo_total := v_costo_total + v_cant * v_costo;
  end loop;

  update public.ventas set total = v_total, costo_total = v_costo_total where id = v_id;
  return v_id;
end;
$$;

revoke execute on function public.registrar_venta(jsonb, text, text, text, text) from anon;

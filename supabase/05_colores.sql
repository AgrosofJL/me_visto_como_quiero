-- =====================================================================
-- Any.G - Colores por prenda
-- Correr DESPUÉS de 04_rubros.sql. Se puede volver a correr.
--
-- El stock queda por combinación talle|color dentro de prendas.stock,
-- ej: {"XL|Gris": 3, "XXL|Azul": 2}. Si la prenda no tiene colores,
-- sigue igual que antes: {"S": 3, "M": 1}.
-- Las funciones registrar_venta / anular_venta no cambian.
-- =====================================================================

alter table public.prendas
  add column if not exists colores text[] not null default '{}';

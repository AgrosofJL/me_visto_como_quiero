# Any.G · Me visto como quiero

Tienda de ropa hecha en Flutter (Android, iPhone y web) con datos en Supabase.

- **Clientes:** ven la colección con precios, filtran, buscan y ordenan. Pueden
  **reservar una prenda** directo o **armar su pedido (carrito)** y mandarlo por
  WhatsApp con día, horario, retiro/envío y forma de pago. El carrito queda guardado
  en el dispositivo aunque cierren la app.
- **Administradores:** entran con "Administrar" (abajo de todo), inician sesión y pueden
  crear, editar, ocultar o borrar prendas y subir fotos, desde el celu o desde la web.

Sin Mercado Pago: el pago se coordina por WhatsApp (efectivo o transferencia).

### Panel de gestión (admin)

- **Tablero:** ingresos, ganancia y margen, cantidad de ventas, ticket promedio,
  prendas vendidas (con % vs. período anterior), gráfico de ingresos por día/mes,
  ventas por forma de pago, por canal y por categoría, ranking de más vendidas,
  valor del stock y alertas de stock bajo / sin stock.
- **Ventas:** registrar ventas (varias prendas por ticket, talle, cantidad y
  **precio real al que se vendió**), forma de pago y canal. Descuenta el stock solo.
  Listado por día y opción de **anular** (devuelve el stock).
- **Stock y prendas:** stock por **talle y color** (tabla con + / −, talles
  rápidos y colores rápidos), costo de compra (privado), filtros de
  sin stock / stock bajo / ocultas y botón rápido para vender.
- **Ofertas:** agrupá prendas con un % OFF o precio especial por prenda, con
  fecha de inicio/fin opcional. Se pueden pausar. En la tienda aparece un banner,
  el filtro "Ofertas", el precio tachado y la cuenta regresiva.
- **Rubros:** tipos de productos (Ropa, Bijouterie, Ropa interior, Accesorios…)
  que se crean, renombran y ordenan desde Stock › Rubros. En la tienda aparecen
  como secciones "¿Qué estás buscando?" y en el tablero hay ventas por rubro.
- **Público:** cada prenda se marca Mujer / Hombre / Niños / Unisex y la tienda
  muestra pestañas para filtrar (Unisex aparece en Mujer y Hombre).
- En la tienda, lo que no tiene stock aparece **AGOTADO** y los talles sin stock
  no se pueden elegir.

Los cambios se ven al instante para todos. No hace falta actualizar la app ni tocar GitHub.

## Estructura

| Archivo | Qué hace |
|---|---|
| `lib/config.dart` | **Todo lo editable:** nombre, eslogan, WhatsApp, horarios, días cerrados, formas de pago, alias, opacidad del logo |
| `lib/tema.dart` | Colores, tipografías y fondo con el logo |
| `lib/carrito.dart` | Carrito (pedido) y su pantalla |
| `lib/pedido.dart` | Formulario de día/horario/entrega/pago y mensaje de WhatsApp |
| `assets/logo_blanco.png` | Logo sin fondo (se usa de marca de agua) |
| `lib/main.dart` | Arranque y colores de la app |
| `lib/catalogo.dart` | Inicio: portada, colección, pie de página |
| `lib/pagina.dart` | Detalle de una prenda: talle, cantidad, agregar o reservar |
| `lib/administrador.dart` | Login, panel con pestañas y formulario de prenda (stock + costo) |
| `lib/tablero.dart` | Tablero de control (KPIs, gráficos, alertas) |
| `lib/ventas_admin.dart` | Listado de ventas, nueva venta y anulación |
| `lib/venta.dart` | Modelo de ventas y períodos de fechas |
| `lib/admin_ui.dart` | Componentes visuales del panel |
| `lib/oferta.dart` | Modelo de ofertas y cálculo del precio final |
| `lib/ofertas_admin.dart` | Pestaña y formulario de ofertas |
| `lib/rubro.dart` / `lib/rubros_admin.dart` | Rubros y su pantalla de administración |
| `lib/servicio.dart` | Todas las llamadas a Supabase |
| `lib/prenda.dart` | Modelo de datos (variantes talle/color) |
| `lib/colores.dart` | Colores rápidos y muestras de color |
| `supabase/esquema.sql` | Tablas, seguridad y bucket de fotos |
| `supabase/02_stock_ventas.sql` | Stock, costos, ventas y funciones para vender/anular |
| `supabase/03_ofertas_publico.sql` | Ofertas y público de cada prenda |
| `supabase/04_rubros.sql` | Rubros (tipos de productos) |
| `supabase/05_colores.sql` | Colores por prenda (stock por talle y color) |
| `.github/workflows/web.yml` | Publica la web en GitHub Pages automáticamente |

## Puesta en marcha (una sola vez)

1. **Base de datos:** en Supabase > *SQL Editor* pegá `supabase/esquema.sql`,
   cambiá los dos emails del final por los reales y tocá **Run**.
   Después, en consultas nuevas, corré en este orden: `supabase/02_stock_ventas.sql`,
   `supabase/03_ofertas_publico.sql`, `supabase/04_rubros.sql` y `supabase/05_colores.sql`.
2. **Usuarios:** en Supabase > *Authentication > Users > Add user > Create new user*,
   creá un usuario para cada administrador (mismo email que pusiste en el SQL,
   tildando *Auto Confirm User*).
3. **Que nadie más se registre:** *Authentication > Sign In / Providers* →
   desactivá **Allow new users to sign up**.
4. **WhatsApp:** cambiá `whatsapp` en `lib/config.dart` (ej. `5491112345678`).
5. Correr la app:
   ```bash
   flutter pub get
   flutter run            # en el celu o emulador
   flutter run -d chrome  # en la compu
   ```

## Web en GitHub Pages

En GitHub > *Settings > Pages* > *Source* elegí **GitHub Actions**.
Cada `git push` a `main` publica la web en
https://agrosofjl.github.io/me_visto_como_quiero/

## APK para Android

```bash
flutter build apk --release
```
El archivo queda en `build/app/outputs/flutter-apk/app-release.apk` y se puede mandar por WhatsApp.

## Nota sobre Supabase gratis

Si el proyecto pasa 7 días sin uso, Supabase lo pausa. Se reactiva desde el panel con *Restore*.

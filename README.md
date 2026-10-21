# Any.G · Me visto como quiero

Tienda de ropa hecha en Flutter (Android, iPhone y web) con datos en Supabase.

- **Clientes:** ven la colección con precios, filtran, buscan y ordenan. Pueden
  **reservar una prenda** directo o **armar su pedido (carrito)** y mandarlo por
  WhatsApp con día, horario, retiro/envío y forma de pago. El carrito queda guardado
  en el dispositivo aunque cierren la app.
- **Administradores:** entran con "Administrar" (abajo de todo), inician sesión y pueden
  crear, editar, ocultar o borrar prendas y subir fotos, desde el celu o desde la web.

Sin Mercado Pago: el pago se coordina por WhatsApp (efectivo o transferencia).

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
| `lib/administrador.dart` | Login, lista de prendas y formulario de carga |
| `lib/servicio.dart` | Todas las llamadas a Supabase |
| `lib/prenda.dart` | Modelo de datos |
| `supabase/esquema.sql` | Tablas, seguridad y bucket de fotos |
| `.github/workflows/web.yml` | Publica la web en GitHub Pages automáticamente |

## Puesta en marcha (una sola vez)

1. **Base de datos:** en Supabase > *SQL Editor* pegá `supabase/esquema.sql`,
   cambiá los dos emails del final por los reales y tocá **Run**.
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

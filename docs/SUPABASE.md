# Configurar Supabase para Cobrá

Cobrá funciona **sin Supabase** (modo local, como siempre). Para activar cuentas
y respaldo en la nube hay que crear un proyecto y pasarle a la app dos datos.

## 1. Crear el proyecto
1. Entrá a <https://supabase.com> y creá una cuenta (gratis).
2. **New project** → nombre `cobra`, elegí una contraseña de base de datos
   (guardala en un gestor de contraseñas) y la región más cercana
   (por ejemplo *South America (São Paulo)*).
3. Esperá un par de minutos a que termine de crearse.

## 2. Crear las tablas
1. En el menú izquierdo: **SQL Editor** → **New query**.
2. Copiá todo el contenido de `supabase/migrations/001_esquema_inicial.sql`,
   pegalo y tocá **Run**. Debe decir *Success*.
3. Verificá en **Table Editor** que existan `businesses`, `products`, `sales`
   y `sale_items`.

Esto crea además las reglas de seguridad (RLS): cada usuario solo puede ver y
modificar los datos de **su** comercio. El comercio se crea solo cuando alguien
se registra.

## 3. Configurar el correo (importante)
En **Authentication → Providers → Email**:

- **Confirm email** (confirmar correo):
  - *Activado* (recomendado para vender): la persona debe confirmar su correo
    antes de ingresar. El correo de Supabase trae un enlace; al tocarlo se
    confirma la cuenta y después la persona vuelve a la app e ingresa.
  - *Desactivado*: entra directo al registrarse. Cómodo para probar.
- **Minimum password length**: poné **8** (la app también lo exige).

### Recuperar contraseña con código
Cobrá recupera la contraseña con un **código de 6 dígitos** (no con un enlace),
porque así no hace falta configurar enlaces profundos en el celular.
Para que el correo incluya el código:

1. **Authentication → Email Templates → Reset Password**.
2. Cambiá el cuerpo por algo como:
   ```html
   <h2>Recuperá tu contraseña de Cobrá</h2>
   <p>Tu código es: <strong>{{ .Token }}</strong></p>
   <p>Si no lo pediste, ignorá este correo.</p>
   ```
3. Guardá.

> Los correos del plan gratuito tienen un límite bajo de envíos por hora
> (el servicio de correo integrado es solo para pruebas). Antes de lanzar,
> configurá tu propio proveedor SMTP en **Project Settings → Authentication →
> SMTP Settings**.

## 4. Pasarle los datos a la app
En **Project Settings → API** copiá:

- **Project URL** (`https://xxxx.supabase.co`)
- **anon public key** (empieza con `eyJ...`)

Ejecutá la app así:

```
flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
```

Para generar el APK para tus clientes:

```
flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

La *anon key* puede ir dentro de la app: no da acceso libre, la seguridad la
ponen las reglas RLS del paso 2.
**Nunca** pongas en la app la clave `service_role` (esa sí da acceso total).

## Requisitos de Flutter
`supabase_flutter` necesita **Flutter 3.35 o más nuevo** (Dart 3.9+).
Verificalo con `flutter --version` y actualizá con `flutter upgrade`.

## Qué falta (próximas partes de la Fase 2)
- Subir a la nube los productos, los datos del negocio y las ventas
  (por ahora las cuentas existen, pero los datos siguen guardándose solo en el
  teléfono).
- Sincronizar sin perder ventas cuando no hay internet.
- Al cambiar de cuenta en un mismo teléfono, separar los datos locales de cada
  una.

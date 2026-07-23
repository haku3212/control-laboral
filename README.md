# Control Laboral AI

Control Laboral AI es una APK Android con dos usuarios simples:

- Operario: registra trabajos diarios, puede agregar nombres de trabajadores y puede agregar tipos de trabajo si faltan.
- Admin: revisa registros, confirma o anula pendientes, administra tarifas y ve pagos estimados.

El operario no ve tarifas, subtotales ni pagos.

## MVP Fase 1

- Login con Supabase.
- Perfil por rol: `admin` u `operator`.
- Panel operario.
- Registro de trabajo desde la APK.
- El operario puede elegir o agregar trabajador.
- El operario puede elegir o agregar trabajo.
- Historial de registros enviados por el operario.
- Panel admin.
- Revision de registros enviados por el operario.
- Edicion de horas/cantidades y notas antes del pago.
- Confirmar o anular registros pendientes.
- Pantalla de pagos estimados con horas/cantidades, precio aplicado y total.
- Asignacion rapida de precio cuando falta tarifa.
- Bonos, anticipos y descuentos por trabajador.
- Marcar pago como pagado y reabrir pago.
- Cierre de semana desde admin.
- Historial de pagos con busqueda por trabajador.
- Reporte PDF de pagos desde admin.
- Recibo PDF individual por trabajador.
- Calendario semanal para seleccionar dia de registro.
- Duplicar semana anterior como registros pendientes.
- Alertas de pendientes, falta de precios y configuracion incompleta.
- Exportacion Excel/CSV de la planilla.
- Analisis con ranking de trabajadores, trabajos frecuentes, ajustes, faltantes y comparacion semanal.
- CRUD basico de trabajadores.
- CRUD basico de tipos de trabajo.
- CRUD basico de tarifas solo para admin.
- Migracion de base de datos con RLS.
- Seed de trabajos iniciales: Hora comun, Hora extra, Feriado, Fundir silicato, Calentar cisterna grande, Tachos de jabon, Bolsas de soda y Numero de bandejas.

## Donde se subira

```text
GitHub
└── Codigo fuente

Supabase
├── Base de datos
├── Autenticacion
├── Reglas de seguridad por rol
└── Documentos privados

Telefonos
└── Misma APK instalada para operario y admin
```

## Usuarios

Puedes crear solo dos usuarios al inicio:

```text
operario / su contrasena
admin / su contrasena
```

En Supabase cada uno sera un usuario de Auth con un perfil en `public.profiles`.

## Crear usuario admin

1. En Supabase Dashboard, crea un usuario con email y contrasena.
2. Copia su `id` de `auth.users`.
3. Ejecuta en SQL Editor:

```sql
insert into public.profiles (id, full_name, role, active)
values ('AUTH_USER_ID_ADMIN', 'Admin', 'admin', true)
on conflict (id) do update set role = 'admin', active = true;
```

## Crear usuario operario

1. En Supabase Dashboard, crea un usuario con email y contrasena.
2. Copia su `id` de `auth.users`.
3. Ejecuta:

```sql
insert into public.profiles (id, full_name, role, active)
values ('AUTH_USER_ID_OPERARIO', 'Operario', 'operator', true)
on conflict (id) do update set role = 'operator', active = true;
```

El operario podra crear trabajadores y trabajos desde la APK, pero no podra leer tarifas ni pagos.

## Ejecutar Flutter localmente

```powershell
cd mobile
flutter pub get
flutter run --dart-define=SUPABASE_URL="https://your-project-ref.supabase.co" --dart-define=SUPABASE_ANON_KEY="your-public-anon-key"
```

## Generar APK de prueba

```powershell
cd mobile
flutter build apk --release --dart-define=SUPABASE_URL="https://your-project-ref.supabase.co" --dart-define=SUPABASE_ANON_KEY="your-public-anon-key"
```

La APK quedara normalmente en:

```text
mobile\build\app\outputs\flutter-apk\app-release.apk
```

## Requisitos en Windows

1. Instalar Git.
2. Instalar Flutter estable.
3. Agregar `flutter\bin` al PATH.
4. Instalar Android Studio y Android SDK.
5. Ejecutar `flutter doctor`.
6. Instalar Supabase CLI.
7. Ejecutar `supabase db push` y `supabase db seed`.

## Verificaciones

Cuando Flutter este instalado:

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
```

Cuando Supabase CLI este instalada:

```powershell
supabase db lint
```

# Estado actual de Control Laboral

## Resumen

El proyecto existente ya contiene una aplicacion Flutter en `mobile/`, configurada con Material 3, Riverpod, GoRouter y Supabase. No se debe crear otro proyecto ni reinstalar herramientas.

La aplicacion actual ya tiene:

- Inicio de sesion con Supabase Auth.
- Carga de perfil desde `profiles`.
- Redireccion por rol actual: `admin` u `operator`.
- Panel admin con dashboard, registros, pagos, reportes y configuracion.
- Panel operador con inicio, nuevo registro y mis registros.
- CRUD basico de trabajadores en `employees`.
- CRUD basico de tipos de trabajo en `work_types`.
- CRUD basico de tarifas en `rates`.
- Registro de trabajos en `work_entries`.
- Pagos semanales con `weekly_periods`, `weekly_payrolls` y `payroll_adjustments`.
- Generacion de PDF/Excel desde la app.
- Migracion inicial de Supabase con RLS.

## Almacenamiento actual

El almacenamiento principal actual es Supabase:

- `supabase_flutter` esta declarado en `mobile/pubspec.yaml`.
- `Supabase.initialize` se ejecuta en `mobile/lib/main.dart`.
- Las credenciales se reciben por `--dart-define` en `AppConfig`.
- Los repositorios consultan directamente tablas Supabase.

No se encontro uso actual de SQLite, Hive, SharedPreferences, Firebase ni almacenamiento local propio para datos de negocio.

## Estructura reutilizable

Se puede reutilizar:

- `mobile/lib/app/router.dart` para rutas y proteccion por sesion.
- `mobile/lib/core/auth` para perfil y roles, ajustando nombres de roles.
- `mobile/lib/core/supabase` para cliente compartido.
- `mobile/lib/features/employees` como base de trabajadores.
- `mobile/lib/features/operator` como base del flujo del encargado.
- `mobile/lib/features/entries` como base de revision del gerente.
- `mobile/lib/features/payroll` como base de pagos.
- `mobile/lib/features/reports` como base para reportes PDF/Excel.
- `supabase/migrations` como base del versionado SQL.

## Brechas contra el objetivo nuevo

La version actual todavia no cumple completamente el alcance nuevo:

- Usa roles `admin` y `operator`; el documento nuevo pide `gerente` y `encargado`.
- La base no es multiempresa todavia. Faltan `empresa_id`, `creado_por`, `fecha_creacion`, `modificado_por` y `fecha_modificacion` en todas las tablas principales.
- Falta tabla `empresas` y relacion de cada perfil con empresa.
- Las tablas actuales tienen nombres en ingles (`employees`, `work_entries`) y no las tablas sugeridas completas (`trabajadores`, `jornadas`, `reclamos`, `adelantos`, `descuentos`, `periodos_pago`, `pagos`, `detalles_pago`, `historial_cambios`, `configuracion_empresa`).
- El flujo actual registra trabajos/cantidades, pero no cubre completo hora de entrada, hora de salida, descanso, horas normales, horas extra ni turnos que cruzan medianoche.
- No existe modulo completo de reclamos/incidentes.
- El estado de revision actual usa `draft`, `confirmed`, `corrected`, `void`; el objetivo pide `borrador`, `pendiente`, `aprobado`, `rechazado`, `incluido_en_pago`, `pagado`.
- Pagos actuales son semanales y parciales; falta historial inmutable completo con copia de precios, adelantos, descuentos, totales y auditoria.
- RLS actual separa por rol, pero no por empresa.
- No hay tabla de configuracion de empresa ni estructura de suscripcion futura.

## Riesgos encontrados

- Cambiar de tablas inglesas a tablas espanolas puede requerir migracion cuidadosa para no romper pantallas existentes.
- El codigo Flutter consulta tablas directamente desde repositorios; al cambiar esquema, varias pantallas se veran afectadas.
- Las politicas RLS actuales permiten funciones admin/operator, pero no aislan datos por empresa.
- La app depende de `SUPABASE_URL` y `SUPABASE_ANON_KEY`; sin valores reales compila, pero no sirve para prueba real sincronizada.
- El README contiene texto con caracteres corruptos por codificacion en algunos diagramas.

## Archivos revisados

- `mobile/pubspec.yaml`
- `mobile/lib/main.dart`
- `mobile/lib/app/app.dart`
- `mobile/lib/app/router.dart`
- `mobile/lib/core/config/app_config.dart`
- `mobile/lib/core/supabase/supabase_providers.dart`
- `mobile/lib/core/auth/app_profile.dart`
- `mobile/lib/core/auth/profile_provider.dart`
- `mobile/lib/features/auth/presentation/login_screen.dart`
- `mobile/lib/features/auth/presentation/role_gate_screen.dart`
- `mobile/lib/features/employees/data/employees_repository.dart`
- `mobile/lib/features/operator/data/operator_entries_repository.dart`
- `mobile/lib/features/entries/data/work_entries_repository.dart`
- `mobile/lib/features/payroll/data/payroll_repository.dart`
- `mobile/android/settings.gradle`
- `supabase/migrations/202607210001_initial_schema.sql`
- `.gitignore`
- `.env.example`
- `README.md`

## Plan breve de Fase 1

1. Mantener el proyecto actual y documentar esta auditoria.
2. Confirmar estado de Git, remoto y respaldo inicial.
3. No modificar pantallas ni esquema funcional todavia.
4. Detenerse antes de la Fase 3 para revisar contigo el camino de migracion a multiempresa.

## Estado de Git

- Repositorio Git existente.
- Rama actual: `main`.
- Remoto configurado: `origin https://github.com/haku3212/control-laboral.git`.
- Ya existe commit inicial: `db355a1 chore: respaldo inicial de Control Laboral`.


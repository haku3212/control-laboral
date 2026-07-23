# Base de datos

La migracion principal esta en `supabase/migrations/202607210001_initial_schema.sql`.

Incluye:

- Enums de roles, unidades, estados y documentos.
- Tabla `profiles` con `role` para separar `admin` y `operator`.
- Tablas de trabajadores, tipos de trabajo, tarifas, semanas, registros, asistencia, auditoria, pagos y documentos.
- RLS activado.
- Politicas para que admin gestione todos los datos.
- Politicas para que operario vea trabajadores activos, cree trabajadores, vea trabajos activos, cree trabajos y registre entradas pendientes.
- Politicas para impedir que operario lea tarifas, pagos o documentos privados.
- Bucket privado `documents`.

El operario usa la anon key de Supabase desde la APK, pero RLS limita lo que puede hacer.

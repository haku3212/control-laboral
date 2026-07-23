# Arquitectura

```text
Misma APK Android
├── Operario
│   ├── Agrega trabajadores si faltan
│   ├── Agrega trabajos si faltan
│   ├── Registra cantidades, horas y notas
│   └── Consulta registros enviados
└── Admin
    ├── Revisa registros
    ├── Confirma o anula pendientes
    ├── Administra tarifas
    ├── Calcula pagos estimados
    └── Consulta reportes en fases futuras
        |
        v
Supabase Auth + PostgreSQL + Storage
```

Fase 1 cubre APK con dos roles, Auth, tablas principales, RLS y seed. Telegram queda como integracion opcional posterior.

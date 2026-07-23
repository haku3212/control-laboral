# Android Build

Desde `mobile`:

```powershell
flutter pub get
flutter build apk --release --dart-define=SUPABASE_URL="https://your-project-ref.supabase.co" --dart-define=SUPABASE_ANON_KEY="your-public-anon-key"
```

APK generada:

```text
mobile\build\app\outputs\flutter-apk\app-release.apk
```

Puedes instalarla manualmente en Android habilitando instalacion desde origenes desconocidos para el explorador o navegador que uses.

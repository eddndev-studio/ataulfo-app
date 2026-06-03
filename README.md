# ataulfo-app

Cliente Flutter (único; OWNER/ADMIN, Android-first) de la plataforma Ataúlfo.
Reconstrucción contract-first contra `ataulfo-go`. Repo separado a propósito:
CI/CD de la app aislado del de la infra Go.

Specs y contrato de API: ver repo `ataulfo-go/specs/` (specs 50-51 para el cliente).
Fuente de extracción de UX/IA: `agentic-deprecated/app/` + `agentic-deprecated/docs/app/`
(solo referencia, no base de desarrollo).

## Push (FCM) — requisito de build Android

El push usa Firebase Cloud Messaging y **solo aplica a Android** (en desktop/web
el provider de token cae a noop). El plugin Gradle `google-services` exige el
archivo `android/app/google-services.json`, que **no se versiona** (gitignored).

Antes de un build de Android (`flutter build apk`, `flutter run` en Android):
descarga `google-services.json` desde la consola de Firebase del proyecto
(Project Settings → Your apps → Android, paquete `studio.eddndev.ataulfo`) y
colócalo en `android/app/google-services.json`. Sin él, el build de Android
falla. Los builds de desktop/web y `flutter test` no lo requieren.

La app obtiene el token FCM y lo registra contra el backend (`POST /push/register`).
La visualización de notificaciones en foreground/background (handlers de
`onMessage`/background) aún no está cableada.

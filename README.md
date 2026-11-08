# Inteliworks Talk — Android

App Android **Inteliworks Talk**: el cliente oficial de [Nextcloud Talk para Android](https://github.com/nextcloud/talk-android)
(chat, llamadas y videollamadas) con la marca de Inteliworks. Cada empresa cliente se conecta a **su propio servidor**
(`https://cloud.<empresa>.cl`, p. ej. `https://cloud.conpav.cl`), que se escribe en la pantalla de inicio.

- `applicationId`: `cl.inteliworks.talk` (tipo de cuenta y *authorities* propios → convive con la app oficial
  de Nextcloud Talk y con [Inteliworks Cloud](https://github.com/Inteliworks-cl/inteliworks-cloud-android)).
- Integración con Inteliworks Cloud (`cl.inteliworks.cloud`, misma firma): importa las cuentas ya configuradas
  allí y abre en ella los archivos compartidos en el chat.
- Notificaciones push: flavor `generic` (sin servicios de Google) → vía [UnifiedPush](https://unifiedpush.org/)
  (p. ej. app *ntfy*); sin distribuidor, Talk sólo avisa con la app abierta.
- Distribución: APK firmado en [Releases](https://github.com/Inteliworks-cl/inteliworks-talk-android/releases) (instalación directa / *sideload*; no Google Play por ahora).
- Ayuda: https://inteliworks.cl · Privacidad: https://inteliworks.cl/politica-privacidad.html · Soporte: soporte@inteliworks.cl

## Cómo funciona (overlay)

Este repo **no copia** el código de Nextcloud Talk. El workflow `.github/workflows/build.yml`:

1. descarga `nextcloud/talk-android` en el tag de `UPSTREAM_TAG` (versión estable fijada),
2. ejecuta `branding/apply.sh`, que
   - copia `branding/res/` encima del *flavor* `generic` (el de F-Droid, sin servicios de Google):
     nombre, colores, íconos, logo, enlaces de privacidad/soporte/código fuente;
   - borra del `main` los vectores `ic_logo`, `ic_launcher_foreground` e `ic_notification` para que ganen los PNG de marca;
   - cambia el `applicationId` del flavor `generic` a `cl.inteliworks.talk`, y el tipo de cuenta Android
     (`auth.xml`/`syncadapter.xml`) y el tipo MIME de contactos a valores propios;
   - suma `BRANDING_REVISION` al `versionCode` y agrega `-iwN` al `versionName`;
3. compila `assembleGenericRelease` y sube el APK **sin firmar** como artefacto.

La firma se hace en el servidor condor3033 (el keystore nunca sale de ahí), ver abajo.

| Archivo | Qué es |
|---|---|
| `UPSTREAM_TAG` | tag estable de Nextcloud Talk Android usado (ej. `v25.0.2`) |
| `BRANDING_REVISION` | 0..9, revisión de la marca sobre ese upstream |
| `branding/res/values/setup.xml` | nombre, colores, integración con Inteliworks Cloud, URLs |
| `branding/res/...` | íconos/logo generados |
| `branding/source/icono.png` | logo fuente (azul sobre círculo blanco, 512×512) |
| `tools/GenerarIconos.java` | regenera los PNG desde el logo fuente |
| `tools/firmar-y-publicar.sh` | descarga el APK de CI, lo firma, verifica paquete/nombre y crea el Release |

## Actualizar a una nueva versión de Nextcloud Talk

1. Ver la última estable: https://github.com/nextcloud/talk-android/releases (tags `vX.Y.Z`, sin `rc`).
2. Editar `UPSTREAM_TAG` (ej. `v25.0.3`) y poner `BRANDING_REVISION` en `1`.
3. Commit + push a `main` → Actions compila. Si falla `apply.sh` es porque upstream cambió
   la estructura de `app/build.gradle.kts`, de `res/xml/auth.xml` o de `setup.xml`: revisar y ajustar.
4. En condor3033: `tools/firmar-y-publicar.sh` (toma la última corrida exitosa de `main`).

Para re-publicar la **misma** versión upstream con cambios de marca, subir `BRANDING_REVISION`
(1→2…; máximo 9) para que Android acepte la actualización (el `versionCode` debe crecer).

## Cambiar íconos / logo

Reemplazar `branding/source/icono.png` y ejecutar:

```bash
java tools/GenerarIconos.java branding/source/icono.png branding/res
```

## Firma

- Keystore de release en condor3033, **el mismo de Inteliworks Cloud**: `/root/apps-cloud/android/keystore/`
  (dir 700, archivos 600; contraseñas en `keystore.env`). Build-tools Android en
  `/root/apps-cloud/android/sdk`. Ejecutar `tools/firmar-y-publicar.sh [run_id]`.
- Usar la misma llave que Inteliworks Cloud es lo que permite a Talk leer sus cuentas.

> ⚠️ **No perder el keystore**: todas las actualizaciones deben firmarse con la misma llave;
> si se pierde, los usuarios tendrían que desinstalar y reinstalar. Respaldarlo fuera del servidor.

## Licencia

Basado en Nextcloud Talk Android © Nextcloud GmbH y colaboradores, licencia **GPL-3.0-or-later**
(ver `LICENSE.txt`). Las modificaciones de este repositorio se distribuyen bajo la misma licencia.
El código fuente correspondiente a cada APK es este repositorio en el commit del release más
`nextcloud/talk-android` en el tag indicado en `UPSTREAM_TAG`.

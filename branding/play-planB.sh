#!/usr/bin/env bash
# PLAN B de Google Play para Inteliworks Talk: SOLO si Play rechaza la declaracion de
# "Permisos de fotos y videos" (READ_MEDIA_IMAGES/_VIDEO/_AUDIO).
# Se ejecuta DESPUES de branding/apply.sh y de compilar el APK (sideload): solo afecta al .aab.
#
# Que hace:
#  1) Quita READ_MEDIA_IMAGES/_VIDEO/_AUDIO del manifest final (tools:node="remove", tambien los
#     que traigan librerias). READ_EXTERNAL_STORAGE ya viene con maxSdkVersion=32 (no aplica en 33+)
#     y se deja para Android 8-12, donde Play no lo restringe.
#  2) En Android 13+ la app ya no exige esos permisos: PlatformPermissionUtilImpl.isFilesPermissionGranted()
#     devuelve true. Los adjuntos ya usan selectores del sistema que entregan permiso por URI:
#     galeria = Photo Picker (PickVisualMedia), archivos = SAF (ACTION_OPEN_DOCUMENT), camara = FileProvider
#     propio, compartir-desde-otra-app = permiso de lectura del Intent. Las notas de voz se graban en
#     almacenamiento propio de la app. Ese metodo es la unica puerta (ChatActivity,
#     MessageInputFragment, ConversationsListActivity), asi nunca se piden permisos no declarados.
#  3) versionCode +1 y versionName -iw<REV> -> -iw<REV+1> (mayor que el .aab del plan A).
# Uso: branding/play-planB.sh <dir-upstream>
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
UP="${1:?uso: play-planB.sh <dir-upstream>}"
REV="$(tr -dc '0-9' < "$ROOT/BRANDING_REVISION")"
NEXT=$((REV + 1))
die() { echo "ERROR: $*"; exit 1; }

# 1) Manifest del flavor generic (no existe upstream; si aparece, revisar a mano)
MF="$UP/app/src/generic/AndroidManifest.xml"
[ -f "$MF" ] && die "ya existe $MF (upstream cambio?), revisar a mano"
mkdir -p "$(dirname "$MF")"
cat > "$MF" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<!-- Inteliworks Talk: build Google Play PLAN B (generado por branding/play-planB.sh) -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
          xmlns:tools="http://schemas.android.com/tools">
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" tools:node="remove" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" tools:node="remove" />
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" tools:node="remove" />
    <uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" tools:node="remove" />
</manifest>
XML

# 2) Android 13+: sin permisos de medios (los selectores del sistema dan acceso por URI)
PPU="$UP/app/src/main/java/com/nextcloud/talk/utils/permissions/PlatformPermissionUtilImpl.kt"
[ -f "$PPU" ] || die "no encuentro $PPU"
perl -0pi -e 's/(Build\.VERSION\.SDK_INT >= Build\.VERSION_CODES\.TIRAMISU -> \{)\s*\n\s*if \(\s*\n\s*PermissionChecker\.checkSelfPermission\(context, Manifest\.permission\.READ_MEDIA_IMAGES\).*?\n\s*\}\s*else\s*\{.*?\n\s*false\s*\n\s*\}\s*\n(\s*\})/$1\n                \/\/ Inteliworks Talk Play plan B: sin READ_MEDIA_*; Photo Picker\/SAF dan permiso por URI\n                Log.d(TAG, "Media permissions not needed (SDK 33 or greater, Play plan B)")\n                true\n$2/s' "$PPU"
grep -q 'Play plan B' "$PPU" || die "no se pudo parchear isFilesPermissionGranted (cambio upstream?)"
! grep -q 'permission.READ_MEDIA_' "$PPU" || die "quedan READ_MEDIA_ en $PPU"

# 3) Version: mayor que la del plan A (apply.sh ya sumo REV y agrego -iw$REV)
cat >> "$UP/app/build.gradle.kts" <<KTS

// --- Inteliworks Talk: Google Play plan B (sin READ_MEDIA_*) ---
androidComponents {
    onVariants(selector().withFlavor("default" to "generic")) { variant ->
        variant.outputs.forEach { out ->
            out.versionCode.set((out.versionCode.orNull ?: 0) + 1)
            out.versionName.set((out.versionName.orNull ?: "").removeSuffix("-iw$REV") + "-iw$NEXT")
        }
    }
}
KTS
echo "Plan B aplicado: sin READ_MEDIA_*, isFilesPermissionGranted()=true en SDK>=33, version -iw$NEXT (+1)"

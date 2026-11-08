#!/usr/bin/env bash
# Aplica la personalizacion "Inteliworks Talk" sobre un checkout del cliente
# Android de Nextcloud Talk (https://github.com/nextcloud/talk-android) en el tag de UPSTREAM_TAG.
# Uso: branding/apply.sh <dir-upstream>
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
UP="${1:?uso: apply.sh <dir-upstream>}"
APP_ID="cl.inteliworks.talk"
REV="$(tr -dc '0-9' < "$ROOT/BRANDING_REVISION")"
GRADLE="$UP/app/build.gradle.kts"
MAIN="$UP/app/src/main"

die() { echo "ERROR: $*"; exit 1; }
[ -f "$GRADLE" ] || die "No encuentro $GRADLE"

# 1) Recursos de marca encima del flavor "generic" (F-Droid, sin servicios de Google)
#    Talk usa ic_logo / ic_launcher_foreground / ic_notification tambien desde Compose y como
#    vectores en drawable/: se borran del main para que ganen los PNG de marca en todas las densidades.
for f in ic_logo ic_launcher_foreground ic_notification; do
  rm -f "$MAIN/res/drawable/$f.xml"
done
mkdir -p "$UP/app/src/generic/res"
cp -r "$HERE/res/." "$UP/app/src/generic/res/"

# 2) applicationId propio en el flavor generic (convive con la app oficial y con cl.inteliworks.cloud)
perl -0pi -e 's/(create\("generic"\)\s*\{\s*applicationId\s*=\s*)"[^"]+"/$1"'"$APP_ID"'"/' "$GRADLE"
grep -q "applicationId = \"$APP_ID\"" "$GRADLE" || die "no se pudo cambiar applicationId (cambio la estructura upstream?)"

# 3) Tipo de cuenta Android = applicationId (el codigo usa BuildConfig.APPLICATION_ID como accountType,
#    pero auth.xml/syncadapter.xml lo traen fijo) y tipo MIME propio para los contactos de Talk.
perl -pi -e 's/android:accountType="com\.nextcloud\.talk2"/android:accountType="'"$APP_ID"'"/' \
  "$MAIN/res/xml/auth.xml" "$MAIN/res/xml/syncadapter.xml"
for x in auth syncadapter; do
  grep -q "accountType=\"$APP_ID\"" "$MAIN/res/xml/$x.xml" || die "no se pudo cambiar accountType en $x.xml"
done
grep -rlF 'vnd.com.nextcloud.talk2.chat' "$MAIN" | xargs -r perl -pi -e "s/vnd\\.com\\.nextcloud\\.talk2\\.chat/vnd.$APP_ID.chat/g"
! grep -rqF 'com.nextcloud.talk2.chat' "$MAIN" || die "quedo el tipo MIME upstream de contactos"

# 4) versionCode/versionName: upstream + revision de marca (permite re-publicar la misma version upstream)
#    upstream usa los 2 ultimos digitos para el build (90-99 = estable), asi que REV debe ser 0..9
[ "$REV" -le 9 ] || die "BRANDING_REVISION debe ser 0..9"
cat >> "$GRADLE" <<KTS

// --- Inteliworks Talk: versionado de la personalizacion ---
androidComponents {
    onVariants(selector().withFlavor("default" to "generic")) { variant ->
        variant.outputs.forEach { out ->
            out.versionCode.set((out.versionCode.orNull ?: 0) + $REV)
            out.versionName.set((out.versionName.orNull ?: "") + "-iw$REV")
        }
    }
}
KTS

echo "Personalizacion aplicada: applicationId=$APP_ID rev=$REV"

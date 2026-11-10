#!/usr/bin/env bash
# Descarga el .aab (Google Play) sin firmar de la ultima corrida exitosa de CI, lo firma con
# la llave de release (UPLOAD KEY de Play App Signing; vive SOLO en condor3033) y lo valida.
# NO sube nada a Play: el .aab queda en /root/apps-cloud/tiendas/aab/ para subirlo en Play Console.
# Uso (en condor3033, como root):  firmar-aab.sh cloud|talk [run_id]
set -euo pipefail
APP="${1:?uso: firmar-aab.sh cloud|talk [run_id]}"
case "$APP" in
  cloud) REPO="Inteliworks-cl/inteliworks-cloud-android"; ART="inteliworks-cloud-aab"; PKG="cl.inteliworks.cloud" ;;
  talk)  REPO="Inteliworks-cl/inteliworks-talk-android";  ART="inteliworks-talk-aab";  PKG="cl.inteliworks.talk" ;;
  *) echo "app desconocida: $APP"; exit 1 ;;
esac
BASE=/root/apps-cloud
SDK="${SDK:-$BASE/android/sdk}"
KS_DIR="$BASE/android/keystore"
KS="$KS_DIR/inteliworks-cloud-release.jks"
# shellcheck disable=SC1091
source "$KS_DIR/keystore.env"   # KS_PASS, KEY_ALIAS, KEY_PASS (archivo 600, nunca a git ni a pantalla)
export KS_PASS KEY_PASS
GH_TOKEN="$(cat /root/.gh_token_iw)"; export GH_TOKEN
BT="$(ls -d "$SDK"/build-tools/* | sort -V | tail -n1)"
OUTDIR="$BASE/tiendas/aab"; mkdir -p "$OUTDIR"

RUN="${2:-$(gh run list -R "$REPO" -w build.yml -b main -s success -L 1 --json databaseId -q '.[0].databaseId')}"
[ -n "$RUN" ] || { echo "No hay corridas exitosas"; exit 1; }
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
gh run download "$RUN" -R "$REPO" -n "$ART" -D "$WORK"
IN="$(ls "$WORK"/*-unsigned.aab)"
OUT="$OUTDIR/$(basename "${IN%-unsigned.aab}").aab"

# Un .aab se firma con jarsigner (no apksigner)
cp "$IN" "$OUT"
jarsigner -sigalg SHA256withRSA -digestalg SHA-256 -keystore "$KS" \
  -storepass:env KS_PASS -keypass:env KEY_PASS "$OUT" "$KEY_ALIAS" >/dev/null
jarsigner -verify "$OUT" | grep -q "jar verified" || { echo "ERROR: firma del .aab no verifica"; exit 1; }; echo "firma .aab: jar verified (cert autofirmado, normal en Android)"

# Validacion sin bundletool: convertir el modulo base (proto) a APK binario y leer el manifest
V="$WORK/val"; mkdir -p "$V/base"
( cd "$V/base" && unzip -q "$OUT" 'base/*' && cd base && mkdir -p ../apk && cp manifest/AndroidManifest.xml ../apk/ && cp resources.pb ../apk/ && cp -r res ../apk/ 2>/dev/null || true )
jar --create --no-manifest --file "$V/base/proto.apk" -C "$V/base/apk" .
"$BT/aapt2" convert --output-format binary -o "$V/bin.apk" "$V/base/proto.apk"
BADGING="$("$BT/aapt2" dump badging "$V/bin.apk")"
grep -E "^package:|targetSdkVersion|^sdkVersion" <<<"$BADGING"
grep -q "name='$PKG'" <<<"$BADGING" || { echo "ERROR: package distinto de $PKG"; exit 1; }
echo "--- permisos ---"
"$BT/aapt2" dump permissions "$V/bin.apk" | grep -oE "name='[^']+'" | sed "s/name=//;s/'//g" | sort -u | tee "$OUT.permisos.txt"
for p in MANAGE_EXTERNAL_STORAGE REQUEST_INSTALL_PACKAGES QUERY_ALL_PACKAGES; do
  grep -q "android.permission.$p\$" "$OUT.permisos.txt" && echo "AVISO: el .aab declara $p (requiere declaracion en Play)"
done
if [[ "$OUT" == *planB* ]]; then   # plan B Talk: sin permisos de fotos/videos/audio, resto intacto
  for p in READ_MEDIA_IMAGES READ_MEDIA_VIDEO READ_MEDIA_AUDIO READ_MEDIA_VISUAL_USER_SELECTED; do
    grep -q "android.permission.$p\$" "$OUT.permisos.txt" && { echo "ERROR plan B: el .aab declara $p"; exit 1; }
  done
  for p in CAMERA RECORD_AUDIO FOREGROUND_SERVICE_CAMERA FOREGROUND_SERVICE_MICROPHONE MODIFY_AUDIO_SETTINGS BLUETOOTH_CONNECT; do
    grep -q "android.permission.$p\$" "$OUT.permisos.txt" || { echo "ERROR plan B: falta $p"; exit 1; }
  done
  echo "plan B OK: sin READ_MEDIA_*; camara/microfono/llamadas declarados"
fi
sha256sum "$OUT" | tee "$OUT.sha256"
echo "Listo: $OUT (corrida $RUN). Subir en Play Console > Produccion/Prueba interna > Crear version."

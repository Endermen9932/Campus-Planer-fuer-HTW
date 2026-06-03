#!/usr/bin/env bash
# Aktiviert "Core Library Desugaring" für den Android-App-Build.
# Notwendig für flutter_local_notifications (nutzt java.time).
#
# Idempotent: hängt den Konfig-Block nur an, wenn er noch nicht vorhanden ist.
# Aufruf:  bash tools/ci/enable_android_desugaring.sh [APP_ANDROID_DIR]
set -euo pipefail

ANDROID_DIR="${1:-app/android}"
KTS="$ANDROID_DIR/app/build.gradle.kts"
GROOVY="$ANDROID_DIR/app/build.gradle"
DESUGAR_VERSION="2.1.4"

if [ -f "$KTS" ]; then
  if grep -q "isCoreLibraryDesugaringEnabled" "$KTS"; then
    echo "Desugaring bereits aktiviert (kts)."
    exit 0
  fi
  cat >> "$KTS" <<EOF

// Automatisch ergänzt (CI): flutter_local_notifications benötigt Desugaring.
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
    }
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:$DESUGAR_VERSION")
}
EOF
  echo "Desugaring aktiviert (kts)."
elif [ -f "$GROOVY" ]; then
  if grep -q "coreLibraryDesugaringEnabled" "$GROOVY"; then
    echo "Desugaring bereits aktiviert (groovy)."
    exit 0
  fi
  cat >> "$GROOVY" <<EOF

// Automatisch ergänzt (CI): flutter_local_notifications benötigt Desugaring.
android {
    compileOptions {
        coreLibraryDesugaringEnabled true
    }
}
dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:$DESUGAR_VERSION'
}
EOF
  echo "Desugaring aktiviert (groovy)."
else
  echo "FEHLER: keine build.gradle(.kts) unter $ANDROID_DIR/app/ gefunden." >&2
  exit 1
fi

#!/usr/bin/env bash
# Konfiguriert den Android-App-Build für Release-Builds:
#   1. Core Library Desugaring  – benötigt von flutter_local_notifications (java.time).
#   2. R8 + proguard-rules.pro  – WorkManager greift per Reflection auf
#      WorkDatabase_Impl zu; ohne Keep-Regel entfernt R8 den no-arg-Konstruktor,
#      was beim App-Start zu einem NoSuchMethodException-Crash führt.
#
# Idempotent: hängt Blöcke nur an, wenn sie noch nicht vorhanden sind.
# Aufruf:  bash tools/ci/enable_android_desugaring.sh [APP_ANDROID_DIR]
set -euo pipefail

ANDROID_DIR="${1:-app/android}"
KTS="$ANDROID_DIR/app/build.gradle.kts"
GROOVY="$ANDROID_DIR/app/build.gradle"
DESUGAR_VERSION="2.1.4"

# ---------------------------------------------------------------------------
# 1. Core Library Desugaring
# ---------------------------------------------------------------------------
if [ -f "$KTS" ]; then
  if grep -q "isCoreLibraryDesugaringEnabled" "$KTS"; then
    echo "Desugaring bereits aktiviert (kts)."
  else
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
  fi
elif [ -f "$GROOVY" ]; then
  if grep -q "coreLibraryDesugaringEnabled" "$GROOVY"; then
    echo "Desugaring bereits aktiviert (groovy)."
  else
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
  fi
else
  echo "FEHLER: keine build.gradle(.kts) unter $ANDROID_DIR/app/ gefunden." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. R8 aktivieren + proguard-rules.pro einbinden (WorkManager-R8-Fix)
# ---------------------------------------------------------------------------
if [ -f "$KTS" ]; then
  if grep -q "proguardFiles" "$KTS"; then
    echo "proguardFiles bereits konfiguriert (kts)."
  else
    cat >> "$KTS" <<'EOF'

// Automatisch ergänzt (CI): R8-Code-Shrinking aktivieren und proguard-rules.pro
// einbinden. Notwendig, damit die WorkManager-Keep-Regel greift.
android {
    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
EOF
    echo "R8 + proguardFiles konfiguriert (kts)."
  fi
elif [ -f "$GROOVY" ]; then
  if grep -q "proguardFiles" "$GROOVY"; then
    echo "proguardFiles bereits konfiguriert (groovy)."
  else
    cat >> "$GROOVY" <<'EOF'

// Automatisch ergänzt (CI): R8-Code-Shrinking aktivieren und proguard-rules.pro
// einbinden. Notwendig, damit die WorkManager-Keep-Regel greift.
android {
    buildTypes {
        release {
            minifyEnabled true
            proguardFiles getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro"
        }
    }
}
EOF
    echo "R8 + proguardFiles konfiguriert (groovy)."
  fi
fi

# ---------------------------------------------------------------------------
# 3. WorkManager-Keep-Regel in proguard-rules.pro schreiben
# ---------------------------------------------------------------------------
PROGUARD_FILE="$ANDROID_DIR/app/proguard-rules.pro"

if grep -q "WorkDatabase_Impl" "$PROGUARD_FILE" 2>/dev/null; then
  echo "WorkManager-Keep-Regel bereits vorhanden."
else
  cat >> "$PROGUARD_FILE" <<'EOF'

# WorkManager greift per Reflection auf WorkDatabase_Impl zu.
# R8 entfernt den no-arg-Konstruktor beim Code-Shrinking ohne diese Regel,
# was beim App-Start zu einem NoSuchMethodException-Crash führt.
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
EOF
  echo "WorkManager-Keep-Regel hinzugefügt ($PROGUARD_FILE)."
fi

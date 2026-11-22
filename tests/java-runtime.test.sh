#!/usr/bin/env bash
# Testa .github/actions/setup-maven/verifica-java-runtime.sh com um JDK falso.
set -euo pipefail
AQUI="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$AQUI/../.github/actions/setup-maven/verifica-java-runtime.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
falhar() { echo "FALHOU: $*" >&2; exit 1; }

jdk_falso() { # $1 = versão reportada
  mkdir -p "$TMP/jh/bin"
  printf '#!/bin/sh\necho '\''openjdk version "%s" 2026-10-21'\'' >&2\necho '\''OpenJDK Runtime Environment Temurin-%s'\'' >&2\n' "$1" "$1" > "$TMP/jh/bin/java"
  printf '#!/bin/sh\necho "javac %s"\n' "$1" > "$TMP/jh/bin/javac"
  chmod +x "$TMP/jh/bin/java" "$TMP/jh/bin/javac"
}
roda() { PATH="$TMP/jh/bin:$PATH" JAVA_HOME="$TMP/jh" GITHUB_WORKSPACE="$TMP/ws" bash "$SCRIPT" "$1" > /dev/null 2>&1; }
mkdir -p "$TMP/ws"

jdk_falso 21.0.12.1
roda 21.0.12 || falhar "respin sem .sdkmanrc deveria passar"
roda 21.0.13 && falhar "versão diferente deveria falhar"
echo "java=21.0.12+1.1-tem" > "$TMP/ws/.sdkmanrc"
roda 21.0.12 || falhar ".sdkmanrc com respin deveria passar"
echo "java=21.0.12-tem" > "$TMP/ws/.sdkmanrc"
roda 21.0.12 && falhar ".sdkmanrc sem respin com JDK respin deveria falhar"
rm "$TMP/ws/.sdkmanrc"
jdk_falso 21.0.120
roda 21.0.12 && falhar "21.0.120 não é respin de 21.0.12"
echo "java-runtime.test.sh: OK"

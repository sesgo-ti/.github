#!/usr/bin/env bash
#
# Cobre resolução divergente do setup-java e JAVA_HOME herdado do runner.
#
# Fonte do pin, em ordem:
#   1. linha `java=` do .sdkmanrc na raiz do workspace, quando existir
#      (X.Y.Z-tem -> X.Y.Z; X.Y.Z+B.R-tem -> X.Y.Z.R, respin) — exato;
#   2. o argumento <versao> (input java-version da action): aceita X.Y.Z
#      ou um respin X.Y.Z.R da mesma versão, que é o que `check-latest`
#      resolve quando a Temurin publica respin de segurança.
#
# Uso: verifica-java-runtime.sh <versao>   (ex.: 21.0.12)
set -euo pipefail
export LC_ALL=C

ENTRADA="${1:?uso: verifica-java-runtime.sh <versao>}"
SDKMANRC="${GITHUB_WORKSPACE:-$PWD}/.sdkmanrc"
falha() { echo "::error::$1" >&2; exit 1; }

PIN=""
if [[ -f "$SDKMANRC" ]]; then
  ID="$(sed -n 's/^java=\(.*\)-tem$/\1/p' "$SDKMANRC" | head -n1)"
  if [[ "$ID" =~ ^([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    PIN="${BASH_REMATCH[1]}"
  elif [[ "$ID" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+\.([0-9]+)$ ]]; then
    PIN="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
  else
    falha ".sdkmanrc presente mas sem java=X.Y.Z-tem ou java=X.Y.Z+B.R-tem."
  fi
  [[ "$PIN" == "$ENTRADA" || "$PIN" == "$ENTRADA".* ]] \
    || falha ".sdkmanrc fixa $PIN, mas o input java-version é $ENTRADA; alinhe os dois."
fi

confere() {
  local efetiva="$1"
  if [[ -n "$PIN" ]]; then [[ "$efetiva" == "$PIN" ]]; return; fi
  [[ "$efetiva" == "$ENTRADA" || "$efetiva" =~ ^${ENTRADA//./\\.}\.[0-9]+$ ]]
}
ALVO="${PIN:-$ENTRADA}"

command -v java >/dev/null 2>&1 || falha "java não encontrado no PATH; setup do JDK não ocorreu."
command -v javac >/dev/null 2>&1 || falha "javac não encontrado no PATH; o pin exige JDK completo."

JAVA_SAIDA="$(java -version 2>&1)" || falha "falha ao executar 'java -version'."
JAVAC_SAIDA="$(javac -version 2>&1)" || falha "falha ao executar 'javac -version'."
printf '%s\n%s\n' "$JAVA_SAIDA" "$JAVAC_SAIDA"

versao_de() { printf '%s\n' "$1" | sed -n '1s/.*version "\([^"]*\)".*/\1/p'; }

JAVA_EFETIVA="$(versao_de "$JAVA_SAIDA")"
confere "$JAVA_EFETIVA" || falha "JDK efetivo (${JAVA_EFETIVA:-desconhecido}) difere do pinado ($ALVO)."
printf '%s\n' "$JAVA_SAIDA" | grep -qi 'temurin' || falha "distribuição efetiva não é Temurin."

JAVAC_EFETIVA="$(printf '%s\n' "$JAVAC_SAIDA" | sed -n 's/^javac \([0-9][0-9.]*\).*/\1/p')"
confere "$JAVAC_EFETIVA" || falha "javac efetivo (${JAVAC_EFETIVA:-desconhecido}) difere do pinado ($ALVO)."

[[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" ]] || falha "JAVA_HOME ausente ou sem bin/java."
HOME_EFETIVA="$(versao_de "$("$JAVA_HOME/bin/java" -version 2>&1)")"
confere "$HOME_EFETIVA" || falha "JAVA_HOME aponta para JDK ${HOME_EFETIVA:-desconhecido}; esperado $ALVO."

echo "JDK pinado em uso: Temurin $JAVA_EFETIVA (java, javac e JAVA_HOME coerentes)."

#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/../PapagaioCore" && pwd)"
LOG_FILE="$(mktemp -t papagaio-core-tests.XXXXXX)"
trap 'rm -f "$LOG_FILE"' EXIT

cd "$PACKAGE_DIR"

# Em pastas sincronizadas pelo File Provider, recursos .mlmodelc podem receber
# FinderInfo. O SwiftPM copia esse atributo para o bundle de testes e o
# codesign rejeita o bundle já compilado. Primeiro executamos o caminho normal:
# qualquer falha que não seja exatamente essa continua sendo uma falha real.
if swift test --no-parallel "$@" 2>&1 | tee "$LOG_FILE"; then
    exit 0
fi

ERRO_DE_ATRIBUTOS='resource fork, Finder information, or similar detritus not allowed'
if ! grep -Fq "$ERRO_DE_ATRIBUTOS" "$LOG_FILE"; then
    exit 1
fi

BUNDLE='.build/out/Products/Debug/PapagaioCoreTests.xctest'
ENTITLEMENTS='.build/out/Intermediates.noindex/PapagaioCore.build/Debug/PapagaioCoreTests-p.build/PapagaioCoreTests.xctest.xcent'

if [[ ! -d "$BUNDLE" || ! -f "$ENTITLEMENTS" ]]; then
    echo 'O SwiftPM reportou atributos inválidos, mas os artefatos esperados não existem.' >&2
    exit 1
fi

echo 'Removendo atributos estendidos somente do bundle de testes gerado e reassinando...'
xattr -cr "$BUNDLE"
codesign \
    --force \
    --sign - \
    --entitlements "$ENTITLEMENTS" \
    --timestamp=none \
    --generate-entitlement-der \
    "$BUNDLE"

swift test --skip-build --no-parallel "$@"

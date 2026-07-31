#!/bin/bash
#
# Baixa os XCFrameworks pré-compilados de whisper.cpp e llama.cpp.
#
# Por que um script e não `binaryTarget(url:checksum:)` do SPM: os dois zips
# publicam o `.xcframework` dentro de `build-apple/`, e o SPM exige o artefato
# na **raiz** do arquivo. Então baixamos, verificamos o SHA-256 e reempacotamos
# na estrutura que o SPM aceita.
#
# Por que XCFramework e não compilar do fonte: nenhum dos dois projetos publica
# mais `Package.swift` (404 em master, verificado em 2026-07-31), e o binário
# oficial já vem com o backend Metal. Ver D-3.1.
#
# Uso:  Scripts/bootstrap-runtimes.sh
# Os frameworks ficam em PapagaioCore/Frameworks/ e são ignorados pelo git.

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINO="$RAIZ/PapagaioCore/Frameworks"
TEMP="$(mktemp -d)"
trap 'rm -rf "$TEMP"' EXIT

# Versões fixadas. Trocar aqui exige trocar o checksum junto.
LLAMA_TAG="b10205"
LLAMA_SHA="3bd855da902324c55e7894148e239365da1da3c54ced7c494df1012fb193bcef"
WHISPER_TAG="v1.9.1"
WHISPER_SHA="8c3ecbe73f48b0cb9318fc3058264f951ab336fd530e82c4ccdd2298d1311a4c"

baixar() {
    local nome="$1" url="$2" sha="$3" xcf="$4"

    if [ -d "$DESTINO/$xcf" ]; then
        echo "==> $nome já presente em PapagaioCore/Frameworks/$xcf — pulando"
        return
    fi

    echo "==> baixando $nome ($url)"
    curl -sSL --fail -o "$TEMP/$nome.zip" "$url"

    echo "==> verificando SHA-256"
    local obtido
    obtido="$(shasum -a 256 "$TEMP/$nome.zip" | awk '{print $1}')"
    if [ "$obtido" != "$sha" ]; then
        echo "ERRO: checksum de $nome não confere" >&2
        echo "  esperado: $sha" >&2
        echo "  obtido:   $obtido" >&2
        exit 1
    fi

    echo "==> extraindo"
    mkdir -p "$TEMP/$nome"
    unzip -q "$TEMP/$nome.zip" -d "$TEMP/$nome"

    local origem
    origem="$(find "$TEMP/$nome" -maxdepth 3 -type d -name "$xcf" | head -1)"
    if [ -z "$origem" ]; then
        echo "ERRO: $xcf não encontrado dentro do zip de $nome" >&2
        exit 1
    fi

    mkdir -p "$DESTINO"
    cp -R "$origem" "$DESTINO/$xcf"
    echo "==> PapagaioCore/Frameworks/$xcf pronto"
}

baixar "llama" \
    "https://github.com/ggml-org/llama.cpp/releases/download/$LLAMA_TAG/llama-$LLAMA_TAG-xcframework.zip" \
    "$LLAMA_SHA" "llama.xcframework"

baixar "whisper" \
    "https://github.com/ggml-org/whisper.cpp/releases/download/$WHISPER_TAG/whisper-$WHISPER_TAG-xcframework.zip" \
    "$WHISPER_SHA" "whisper.xcframework"

echo
echo "Pronto. Slices de macOS:"
for xcf in llama whisper; do
    if [ -d "$DESTINO/$xcf.xcframework/macos-arm64_x86_64" ]; then
        echo "  $xcf.xcframework  ✓ macos-arm64_x86_64"
    else
        echo "  $xcf.xcframework  ✗ SEM slice de macOS"
    fi
done

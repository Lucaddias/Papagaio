#!/bin/bash
#
# Baixa os XCFrameworks pré-compilados de whisper.cpp, llama.cpp e do
# ONNX Runtime, e o modelo do Silero VAD.
#
# Por que um script e não `binaryTarget(url:checksum:)` do SPM: os zips do
# whisper/llama publicam o `.xcframework` dentro de `build-apple/`, e o SPM
# exige o artefato na **raiz** do arquivo. Então baixamos, verificamos o
# SHA-256 e reempacotamos na estrutura que o SPM aceita. O ONNX Runtime vem
# na raiz, mas **não publica module map** — o Swift precisa de um para
# `import onnxruntime` (ver `patchear_module_map_do_onnx` abaixo).
#
# Por que XCFramework e não compilar do fonte: nenhum dos projetos publica
# mais `Package.swift` (404 em master, verificado em 2026-07-31), e o binário
# oficial já vem com o backend Metal. Ver D-3.1.
#
# Uso:  Scripts/bootstrap-runtimes.sh
# Os frameworks ficam em PapagaioCore/Frameworks/ e são ignorados pelo git.
# O modelo do Silero vai para Sources/PapagaioCore/Resources/ (também fora
# do git), onde o SPM o empacota como resource do PapagaioCore.

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINO="$RAIZ/PapagaioCore/Frameworks"
RECURSOS="$RAIZ/PapagaioCore/Sources/PapagaioCore/Resources"
TEMP="$(mktemp -d)"
trap 'rm -rf "$TEMP"' EXIT

# Versões fixadas. Trocar aqui exige trocar o checksum junto.
LLAMA_TAG="b10205"
LLAMA_SHA="3bd855da902324c55e7894148e239365da1da3c54ced7c494df1012fb193bcef"
WHISPER_TAG="v1.9.1"
WHISPER_SHA="8c3ecbe73f48b0cb9318fc3058264f951ab336fd530e82c4ccdd2298d1311a4c"
# ONNX Runtime (M.1) e modelo do Silero VAD: pod archive oficial do
# onnxruntime.ai e o `silero_vad.onnx` fixado num commit do snakers4/silero-vad
# (a tag de release não cobre o artefato do modelo).
ONNX_TAG="1.24.2"
ONNX_SHA="f7100a992d2a8135168c8afd831e6a58b465349101982aa58b3e11d36e600b54"
SILERO_SHA="1a153a22f4509e292a94e67d6f9b85e8deb25b4988682b7e174c65279d8788e3"

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

baixar_arquivo() {
    local nome="$1" url="$2" sha="$3" destino="$4"

    if [ -f "$destino" ]; then
        echo "==> $nome já presente em $destino — pulando"
        return
    fi

    echo "==> baixando $nome ($url)"
    curl -sSL --fail -o "$TEMP/$nome" "$url"

    echo "==> verificando SHA-256"
    local obtido
    obtido="$(shasum -a 256 "$TEMP/$nome" | awk '{print $1}')"
    if [ "$obtido" != "$sha" ]; then
        echo "ERRO: checksum de $nome não confere" >&2
        echo "  esperado: $sha" >&2
        echo "  obtido:   $obtido" >&2
        exit 1
    fi

    mkdir -p "$(dirname "$destino")"
    cp "$TEMP/$nome" "$destino"
    echo "==> $destino pronto"
}

# O pod archive do ONNX Runtime não traz module map; sem ele, `import
# onnxruntime` do Swift falha ("no such module"). O patch acrescenta um em
# cada slice do xcframework, exatamente como validado em scratch:
# - slices planos (iOS): <framework>/Modules/module.modulemap
# - slices versionados (macOS): <framework>/Versions/A/Modules/... + symlink
#   <framework>/Modules -> Versions/Current/Modules
patchear_module_map_do_onnx() {
    local xcf="$DESTINO/onnxruntime.xcframework"
    [ -d "$xcf" ] || return

    local conteudo='framework module onnxruntime {
  umbrella header "onnxruntime_c_api.h"

  export *
  module * { export * }
}'

    for slice in "$xcf"/*/; do
        local fw="$slice/onnxruntime.framework"
        [ -d "$fw" ] || continue
        if [ -d "$fw/Versions/A" ]; then
            mkdir -p "$fw/Versions/A/Modules"
            printf '%s\n' "$conteudo" > "$fw/Versions/A/Modules/module.modulemap"
            [ -L "$fw/Modules" ] || ln -sfn Versions/Current/Modules "$fw/Modules"
        else
            mkdir -p "$fw/Modules"
            printf '%s\n' "$conteudo" > "$fw/Modules/module.modulemap"
        fi
    done
    echo "==> module map do onnxruntime.xcframework patcheado"
}

baixar "llama" \
    "https://github.com/ggml-org/llama.cpp/releases/download/$LLAMA_TAG/llama-$LLAMA_TAG-xcframework.zip" \
    "$LLAMA_SHA" "llama.xcframework"

baixar "whisper" \
    "https://github.com/ggml-org/whisper.cpp/releases/download/$WHISPER_TAG/whisper-$WHISPER_TAG-xcframework.zip" \
    "$WHISPER_SHA" "whisper.xcframework"

baixar "onnxruntime" \
    "https://download.onnxruntime.ai/pod-archive-onnxruntime-c-$ONNX_TAG.zip" \
    "$ONNX_SHA" "onnxruntime.xcframework"
patchear_module_map_do_onnx

baixar_arquivo "silero_vad.onnx" \
    "https://raw.githubusercontent.com/snakers4/silero-vad/76e3dc408eb2a5c655c34e230d2d5459b4439daa/src/silero_vad/data/silero_vad.onnx" \
    "$SILERO_SHA" "$RECURSOS/silero_vad.onnx"

echo
echo "Pronto. Slices de macOS:"
for xcf in llama whisper onnxruntime; do
    if [ -d "$DESTINO/$xcf.xcframework/macos-arm64_x86_64" ]; then
        echo "  $xcf.xcframework  ✓ macos-arm64_x86_64"
    else
        echo "  $xcf.xcframework  ✗ SEM slice de macOS"
    fi
done

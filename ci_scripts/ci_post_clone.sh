#!/bin/sh
#
# Xcode Cloud — roda logo depois do clone, antes da resolução de pacotes.
#
# Sem isto todo build falha na resolução, antes de compilar uma linha:
#
#   local binary target 'whisper' at
#     '/Volumes/workspace/repository/PapagaioCore/Frameworks/whisper.xcframework'
#     does not contain a binary artifact
#
# São dois problemas diferentes, e cada um precisa de um passo:
#
# 1. Os XCFrameworks (whisper, llama, onnxruntime, ~1 GB) **estão** no git, mas
#    via Git LFS. Um clone sem LFS resolvido traz ponteiros de 129 bytes no
#    lugar dos binários, e o Info.plist de cada .xcframework vira texto solto
#    ("Failed to decode XCFramework Info.plist").
#
# 2. O modelo do Silero VAD (2,3 MB) **não** está no git (ver .gitignore), mas o
#    Package.swift declara `resources: [.process("Resources")]`. Sem ele a pasta
#    Resources/ nem existe e a resolução falha com "The file 'Resources'
#    couldn't be opened".
#
# Por isso os dois passos: `lfs pull` resolve (1), o bootstrap resolve (2). O
# bootstrap pula os frameworks sozinho quando já os encontra no lugar, então não
# há download duplicado.

set -e

# (1) Ponteiros do LFS -> binários reais.
git lfs install
git lfs pull

# (2) Modelo do Silero VAD (versão e SHA-256 fixados dentro do script).
"$CI_PRIMARY_REPOSITORY_PATH/Scripts/bootstrap-runtimes.sh"

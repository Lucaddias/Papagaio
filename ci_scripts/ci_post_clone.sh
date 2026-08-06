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
# Os XCFrameworks do whisper.cpp e do llama.cpp somam ~1 GB e ficam fora do git
# (ver .gitignore), mas o Package.swift os declara como `binaryTarget(path:)`.
# O clone do Xcode Cloud chega sem eles. Quem desenvolve roda o mesmo script à
# mão uma vez; aqui ele roda a cada build.
#
# Custo: ~1 GB de download por build. É o preço de não versionar os binários —
# se incomodar, o caminho é hospedar os zips reempacotados em algum lugar
# estável e trocar por `binaryTarget(url:checksum:)`, que o Xcode Cloud cacheia.

set -e

"$CI_PRIMARY_REPOSITORY_PATH/Scripts/bootstrap-runtimes.sh"

#!/bin/bash
#
# Gera a fixture de fala real usada por DetectorDeAtividadeDeVozTests.
#
# Roda UMA VEZ, fora dos testes, e o WAV resultante é commitado. O teste só
# lê o arquivo — assim CI/outra máquina não depende de `say` nem de a voz
# estar baixada no momento da execução.
#
# Uso:  PapagaioCore/Tests/PapagaioCoreTests/Fixtures/gerar_fixture.sh
# Voz:  Luciana (pt_BR). Cai para a voz padrão se ela não estiver instalada.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESTINO="$DIR/fala_ola_mundo.wav"
FRASE="Olá! Tudo bem? Este é um teste do reconhecimento de fala."

echo "==> gerando $DESTINO"
if command -v say >/dev/null 2>&1 && say -v Luciana '?' >/dev/null 2>&1; then
    say -v Luciana -o "$DESTINO" --file-format=WAVE --data-format=LEI16@16000 "$FRASE"
else
    echo "    voz Luciana ausente — usando a voz padrão"
    say -o "$DESTINO" --file-format=WAVE --data-format=LEI16@16000 "$FRASE"
fi

echo "==> pronto: $(stat -f '%z bytes' "$DESTINO")"
echo "    confira no modelo antes de commitar:"
echo "    python val_fixture.py silero_vad.onnx $DESTINO"

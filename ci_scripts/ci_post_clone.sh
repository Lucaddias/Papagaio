#
//  ci_post_clone.sh
//  Papagaio
//
//  Created by Felipe Azambuja Carvalho on 06/08/26.
//

#!/bin/sh

# Configura o Git nativo do servidor para reconhecer os ponteiros do LFS
git lfs install

# Baixa os binários reais (llama, whisper, onnxruntime) direto para o build
git lfs pull

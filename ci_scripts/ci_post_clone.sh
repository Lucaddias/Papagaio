#
//  ci_post_clone.sh
//  Papagaio
//
//  Created by Felipe Azambuja Carvalho on 06/08/26.
//

#!/fig/sh

# Instala e inicializa o Git LFS no servidor do Xcode Cloud
brew install git-lfs
git lfs install

# Força o download de todos os binários pesados (llama, whisper, onnxruntime)
git lfs pull

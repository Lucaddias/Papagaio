# Papagaio — Prompt mestre de execução (v4)

Cole isto como primeira mensagem de uma sessão de desenvolvimento. Ele governa a
sequência inteira; não tenta fazer tudo de uma vez **dentro de uma sessão** — mas
não existe mais "v1" e "fase 2" como versões separadas do produto. Todo o escopo
abaixo (Passo 0 a 13) é uma entrega única. A execução continua sendo passo a
passo, por disciplina de engenharia — não porque parte do escopo foi adiada.

## CONTEXTO

Você é um engenheiro sênior Apple construindo o Papagaio: app macOS 26+, Apple
Silicon, distribuído na Mac App Store, que grava **reuniões online**, transcreve
e resume 100% on-device, com espaços individuais e de equipe.

**Stack única (não existe stack de "fase 2"):**

SwiftUI · Swift Concurrency · AVFoundation + Core Audio Process Taps · **whisper.cpp**
(Whisper large-v3, GGUF, linkado como biblioteca) · **llama.cpp** (Qwen2.5-14B-Instruct-Q5_K_M,
GGUF, linkado como biblioteca) · SwiftData · CloudKit (`CKSyncEngine` + `CKShare`) ·
AuthenticationServices · UniformTypeIdentifiers

Estes são **os modelos que já estão em uso no código** (`WhisperCppRunner.swift` e
`QwenSummarizer.swift` do `InterviewLab`). Não trocam. O que muda é a forma de
chamada — ver a restrição de sandbox abaixo.

**Por que não `SpeechAnalyzer` + `FoundationModels`:** não é questão de qualidade —
é questão de prazo e de teto de qualidade. `Private Cloud Compute` (que permitiria
ao modelo on-device da Apple sair do teto de ~3B/4k tokens para algo maior quando
necessário) é uma feature que **lança depois do seu prazo**. Sem ela, o
`FoundationModels` fica preso a um modelo pequeno com janela de 4.096 tokens — e
os modelos que você já tem (Whisper large-v3 + Qwen 14B com 32k de contexto)
entregam mais qualidade sem depender de nenhuma feature futura da Apple.

**Descartado, não sugira:**

`SpeechAnalyzer`/`FoundationModels` como engine principal · `WhisperKit`/`MLX Swift`
(trocam os pesos já escolhidos por conversões Core ML diferentes — fora de escopo
enquanto os modelos atuais atenderem) · `whisper-cli`/`llama-cli` via subprocess
(não roda em App Sandbox) · Ollama · SwiftData+CloudKit para equipes · ffmpeg

**Restrições que valem em todos os passos:**

* App Sandbox ligado. Tudo precisa funcionar sob sandbox — inclusive os modelos
  locais (ver Passo 3).
* `whisper.cpp` e `llama.cpp` são **linkados como biblioteca** (SPM/XCFramework)
  dentro do app. Nunca `Process()`, nunca binário externo do Homebrew. É a única
  forma de manter estes modelos e a Mac App Store ao mesmo tempo.
* Janela do Qwen = **32k tokens**. Passe único é o padrão; map-reduce só entra
  para reuniões que estourem isso (~3h+). Não é o mesmo problema que era com o
  modelo de 4k da Apple — não trate como se fosse.
* SwiftData + CloudKit não suporta database compartilhado. Equipe usa CloudKit puro.
* Identidade de sync = `CKContainer.userRecordID`. Sign in with Apple é perfil,
  não sync.
* Swift 6, strict concurrency. `actor` para o pipeline — e também para envolver
  `whisper_context`/`llama_context`, que não são thread-safe.
* O app grava **microfone e áudio do sistema** (Core Audio Process Taps). Caso de
  uso é reunião online: só microfone produz monólogo (fone) ou eco/WER alto
  (alto-falante) — nenhum dos dois é defensável para esse posicionamento.
* RAM ≥ 18 GB é **piso de hardware, não degradação**. Não existe segunda engine
  para cair — se o Mac não tem RAM, o app bloqueia a funcionalidade com mensagem
  clara, não silenciosamente entrega pior.

## REGRAS DE OPERAÇÃO — leia antes de escrever qualquer linha

1. Um passo por vez. Execute apenas o passo atual. Não adiante trabalho de passos
   seguintes, nem "já que estou aqui".
2. Pare ao final de cada passo e espere review. Não comece o próximo sem
   aprovação explícita.
3. Teste antes de reportar. Rode o teste descrito no passo e cole a saída real.
   Nunca escreva "deve funcionar" ou "deveria compilar".
4. Se um critério de aceite falhar, conserte antes de reportar. Passo entregue
   com critério quebrado não é passo entregue.
5. Não invente API. Se não tiver certeza da assinatura (inclusive das APIs C de
   `whisper.cpp`/`llama.cpp`), diga que não tem e peça confirmação. Assinatura
   inventada custa mais caro que uma pergunta.
6. Preserve os contratos do Passo 1. Se precisar mudar um protocolo, pare e
   justifique antes.
7. Registre decisões em `DECISIONS.md`: o que foi decidido, alternativas
   descartadas e por quê.
8. Diga o que não fez. Se cortou escopo ou deixou um `TODO`, liste explicitamente
   no relatório.

## Formato do relatório de fim de passo

```
## Passo N — <nome>

### O que foi feito
<lista curta>

### Arquivos criados/alterados
<lista com caminho>

### Teste executado
<comando exato + saída real colada>

### Critérios de aceite
- [x] critério 1
- [ ] critério 2 — não atendido porque <motivo>

### Pendências e riscos
<lista, ou "nenhuma">

Aguardando review para seguir para o Passo N+1.
```

---

## PASSO 0 — Auditoria de ambiente

Já executado em 2026-07-30 — ver `DECISIONS.md`. Antes de qualquer novo commit,
reconfirme: Xcode instalado (`xcodebuild -version`), toolchain de build do
`whisper.cpp`/`llama.cpp` (CMake, Metal), RAM/disco da máquina de desenvolvimento.

## PASSO 1 — Esqueleto e contratos

Objetivo: projeto que compila, com as fronteiras certas. Zero implementação de
feature.

Fazer:

* Workspace com três targets: `Papagaio` (app), `PapagaioCore` (biblioteca),
  `papagaio-eval` (CLI)
* App Sandbox + entitlements: `app-sandbox`, `device.audio-input`,
  `files.user-selected.read-write`, `network.client`
* Swift 6, strict concurrency `complete`
* Protocolos em `PapagaioCore`:

```swift
struct Trecho: Sendable, Identifiable {
    let id: UUID
    let start: TimeInterval
    let end: TimeInterval
    let texto: String
    let speaker: String?   // "eu" | "interlocutor" | nil — ver Passo 2 e Passo 5
}

protocol TranscriptionEngine: Sendable {
    var identifier: String { get }
    func transcribe(_ url: URL) async throws -> [Trecho]
}

protocol SummarizationEngine: Sendable {
    var identifier: String { get }
    func summarize(_ trechos: [Trecho]) async throws -> Resumo
}

protocol ArquivoRepository: Sendable {
    func salvar(_ a: Arquivo) async throws
    func buscar(termo: String) async throws -> [Arquivo]
    func listar(espaco: EspacoID) async throws -> [Arquivo]
}
```

* Implementações vazias que lançam `NotImplemented`

Teste: `xcodebuild -scheme Papagaio build` e rodar o app (janela vazia).
Aceite: compila sem warning de concorrência; app abre; sandbox ativo (confirme no
Console).
Armadilha: não coloque lógica de UI em `PapagaioCore`. A CLI precisa importar a
lib sem arrastar SwiftUI. `TranscriptionEngine` não tem parâmetro de `locale` —
não há gestão de asset de locale, o peso do Whisper já vem com o idioma.

## PASSO 2 — Captura e arquivamento (microfone + sistema)

Objetivo: gravar microfone **e** áudio do sistema, mixar, arquivar em AAC,
importar arquivo externo. Ver skill `papagaio-audio-capture`.

Fazer:

* `AVAudioEngine` + tap no `inputNode` para o microfone
* `AudioHardwareCreateProcessTap` (`CATapDescription`) →
  `AudioHardwareCreateAggregateDevice` → `AudioDeviceCreateIOProcIDWithBlock`
  para o áudio do sistema — **não** dá para usar `AVAudioEngine` apontado para
  o aggregate device, ele fica em silêncio
* Excluir o PID do próprio Papagaio do tap (senão grava o próprio playback)
* TCC separado: `NSAudioCaptureUsageDescription`
* Mixar as duas fontes antes do arquivamento; formato de trabalho PCM 16 kHz
  mono; arquivamento AAC `.m4a`
* Waveform ao vivo a partir do tap do microfone
* `.fileImporter` do SwiftUI + `AVAsset` para validar e converter anexo
* Arquivos em `Application Support/Papagaio/Gravacoes/<uuid>/`

Teste: grave 10 min de uma chamada online real (com fone, para não gerar eco);
importe um `.mp3` externo.
Aceite:

* `.m4a` de 10 min ocupa ~5 MB
* abre no QuickTime e as duas vozes (você e o interlocutor) estão inteligíveis
* arquivo importado converte e aparece na lista
* nenhum glitch/dropout audível
* o playback do próprio Papagaio não aparece na gravação

Armadilhas: o bloco do tap roda em thread de áudio — só `memcpy` para buffer,
nada de alocação, lock, `await` ou `print`. Sob sandbox, o caminho é o container
do app. Distribuição de Process Taps pela Mac App Store precisa ser confirmada
antes de investir tempo aqui — ver risco R-2 em `DECISIONS.md`.

## PASSO 3 — Runtime dos modelos locais

Objetivo: `whisper.cpp` e `llama.cpp` linkados como biblioteca dentro do
sandbox, com preflight de hardware, download resumível dos pesos GGUF e ciclo de
vida em memória. Sem isso, nem transcrição nem resumo funcionam — e não há
segunda engine para cair se isso falhar. Ver skill `papagaio-engine-selection`.

Fazer:

* Compilar `whisper.cpp` e `llama.cpp` como bibliotecas linkadas no target
  `PapagaioCore` (via `Package.swift` oficial de cada projeto, ou XCFramework
  pré-compilado). Nenhum `Process()`, nenhuma dependência de Homebrew.
* Preflight, em ordem:
  1. RAM física ≥ 18 GB (Qwen Q5_K_M ≈ 10,7 GB + KV cache) — **bloqueia**, não
     avisa
  2. Disco livre ≥ 20 GB (Whisper large-v3 GGUF ≈ 3 GB + Qwen Q5_K_M GGUF ≈
     10,7 GB + folga) — **bloqueia**
  3. Pesos presentes em Application Support com checksum SHA-256 válido —
     oferece download
  4. `thermalState != .critical` — avisa e oferece adiar
* Download: `URLSession` com `backgroundSessionConfiguration`, retomada em
  queda de conexão, checksum SHA-256 por artefato. Pesos nunca no bundle.
* Ciclo de vida: manter os modelos residentes em memória entre execuções
  (carregar 10,7 GB do disco leva 10–30 s); `DispatchSource.makeMemoryPressureSource`
  descarrega sob pressão.
* Sem fallback para engine alternativa — descreva isso na UI (ver
  `papagaio-app-surface`), não silencie.

Teste: rode o preflight numa máquina com RAM real medida; force queda de rede no
meio do download; force pressão de memória artificial e confirme que descarrega
sem crash.
Aceite: Mac abaixo do piso de RAM é bloqueado com mensagem clara antes de
qualquer tentativa; download resume após queda; checksum inválido não deixa
modelo corrompido ativo; app não crasha sob pressão de memória.
Armadilha: calibre o portão de disco com o tamanho real dos artefatos GGUF que
você está usando, não com estimativa de outro formato.

## PASSO 4 — Transcrição (Whisper large-v3)

Objetivo: transcrever com o mesmo peso GGUF do `InterviewLab`
(`ggml-large-v3.bin`), agora chamado in-process pela biblioteca do Passo 3, não
via `whisper-cli` em subprocess. Ver skill `papagaio-whisper-cpp`.

Fazer:

* API in-process sobre `whisper_context`, envolvida num `actor` (não é
  thread-safe)
* Implementar `WhisperEngine: TranscriptionEngine`, devolvendo os segmentos
  nativos do Whisper com timestamp
* `speaker` populado pelo canal de origem (mic = "eu", tap do sistema =
  "interlocutor") — ver skill `papagaio-speaker-attribution`

Teste: transcreva o áudio de 10 min mixado do Passo 2; confirme com Activity
Monitor/Instruments que existe **um processo só** (sem subprocess).
Aceite: cada segmento tem `start`/`end`; texto reconhecível como o que foi
falado; nenhum subprocess externo é criado; sem vazamento de `whisper_context`
sob chamadas concorrentes.
Armadilha: `whisper_context` não é thread-safe. Um `actor` só, nunca chamadas
concorrentes ao mesmo contexto.

## PASSO 5 — Segmentação em trechos

Objetivo: normalizar os segmentos nativos do Whisper para a janela alvo de
~40 s. Ver skill `papagaio-segmentation`.

Fazer: o Whisper já segmenta e já corta em fronteira de fala — aqui você agrupa
segmentos pequenos e nunca quebra um no meio. `start` é a chave da navegação.

Teste: rode sobre a transcrição do Passo 4 e imprima os trechos com duração.
Aceite:

* nenhum trecho termina no meio de uma frase
* durações entre ~20 s e ~60 s
* `start` do primeiro trecho ≈ início da fala, não 0 se houver silêncio inicial
* trechos preservam o `speaker` do canal de origem

Armadilha: segmentos do Whisper variam muito de tamanho — trate como
normalização, não como o mesmo algoritmo de agrupar palavras.

## PASSO 6 — Harness de medição (CLI)

Objetivo: saber, com número, se a transcrição é boa. Antes de investir mais na
sumarização. Ver skill `papagaio-eval-harness`.

Fazer:

* Corpus mínimo: 5 gravações reais em PT-BR com ground truth manual (comece
  pequeno; expanda depois)
* `papagaio-eval` calculando WER (normalização simétrica: minúsculas, sem
  pontuação, números por extenso, sem disfluência)
* Acurácia de entidades separada por pessoa / empresa / número
* Relatório em Markdown

Teste: `papagaio-eval run --corpus ./corpus --engine whisper-cpp`
Aceite: WER e acurácia de entidades impressos por gravação e agregados;
relatório gerado.
Por que agora: se o WER em PT-BR for ruim, a tese do produto muda — e você
precisa saber com 6 passos de trabalho, não com 13.

## PASSO 7 — Sumarização (Qwen2.5-14B-Instruct-Q5_K_M)

Objetivo: resumo estruturado, passe único na maioria dos casos. Ver skill
`papagaio-summarization`.

Fazer:

* `llama_context` in-process (biblioteca do Passo 3), num `actor` próprio (não
  é thread-safe)
* Medir tokens antes de enviar (tokenizer do próprio `llama.cpp`)
* Se couber em ~28k tokens de entrada (deixando margem dentro dos 32k): **passe
  único**, transcrição inteira no contexto
* Se não couber (reuniões de ~3h+): map-reduce com chunks de ~8.000 tokens,
  sessão nova por chunk
* Saída estruturada via JSON schema + gramática GBNF forçando o formato, com
  reprompt se a saída vier inválida
* Registrar a engine nos metadados (`qwen2.5-14b-instruct-q5_k_m`)

Teste: resuma a reunião de 20 min do Passo 4/5 (deve caber em passe único).
Aceite: passe único não estoura o contexto; saída é struct tipado válido;
reprompt corrige JSON malformado; números citados aparecem corretos; o resumo
conecta um assunto do início com a retomada dele no fim (é o que justifica ter
esse modelo em vez do 4k da Apple).
Armadilha: `llama_context` também não é thread-safe — mesmo cuidado do Passo 4.
Sessão nova por chunk no modo map-reduce, sempre.

## PASSO 8 — Persistência individual

Objetivo: SwiftData local funcionando, com arquivos fora do banco. Ver skill
`papagaio-persistence-sync`.

Fazer:

* `@Model`: `Arquivo`, `Trecho`, `Insight`, `Espaco`
* `ModelConfiguration(cloudKitDatabase: .none)`
* Áudio e `.md` como arquivos; no modelo, caminho relativo
* Implementar `SwiftDataRepository: ArquivoRepository`

Teste: grave, transcreva, resuma, feche o app, reabra.
Aceite: tudo persiste; áudio toca; apagar um arquivo apaga também o `.m4a` do
disco.
Armadilha: nunca guarde blob de áudio no banco. Nunca guarde caminho absoluto.

## PASSO 9 — Busca

Objetivo: encontrar arquivo por termo, com título tendo prioridade. Ver skill
`papagaio-search`.

Fazer: duas queries — título contém termo (bucket A), corpo contém termo
excluindo A (bucket B), resultado A antes de B. Zero dependência externa.

Teste: com ≥10 arquivos, busque um termo que aparece num título e no corpo de
outros.
Aceite: o do título vem primeiro; nenhum duplicado; busca com e sem acento
retorna o mesmo.
Armadilha: mantenha a interface `ArquivoRepository.buscar` estável — uma
eventual migração para FTS5 não pode mudar a assinatura.

## PASSO 10 — Player e navegação por trecho

Objetivo: clicar num trecho e o áudio pular para lá. Ver skill
`papagaio-app-surface`.

Fazer: `AVAudioPlayer`, `currentTime = trecho.start`, `addPeriodicTimeObserver`
a ~0,1 s publicando o tempo, view comparando com os ranges para o highlight.
Cancelar o observer ao sair da view.

Teste: clique em 3 trechos diferentes, incluindo o último.
Aceite: o áudio salta para o ponto certo; o highlight acompanha sem parecer
travado; sair da view não deixa observer vivo.

## PASSO 11 — Exportação Markdown

Objetivo: exportar resumo + anexos respeitando o sandbox.

Fazer: gerar string a partir do modelo tipado; `.fileExporter` + `FileDocument`;
anexos no mesmo diretório escolhido.

Teste: exporte para `~/Desktop` e abra o `.md` num editor.
Aceite: markdown válido e legível; anexos presentes; nenhum erro de permissão
de sandbox.

## PASSO 12 — Sign in with Apple

Objetivo: identidade de perfil, sem virar portão.

Fazer: `ASAuthorizationAppleIDProvider`, credencial no Keychain,
`getCredentialState` na abertura, `credentialRevokedNotification` tratada.

Teste: logar, fechar, reabrir; revogar acesso em Ajustes do sistema e reabrir.
Aceite: sessão persiste; revogação é detectada e tratada sem crash; o app
funciona sem login.
Lembrete: esta identidade não é a de sync. Ver Passo 13.

## PASSO 13 — Espaços de equipe (CloudKit)

Maior risco do projeto. Ver skill `papagaio-persistence-sync`.

Fazer:

* `CKContainer.accountStatus` antes de oferecer o espaço de equipe
* Identidade = `CKContainer.default().userRecordID`, não o Sign in with Apple
* Custom zone (zona default não é compartilhável)
* `CKRecord` + `CKAsset` para áudio e `.md`
* `CKShare` com link de convite; aceite via `CKShareMetadata` no delegate
* `CKSyncEngine` para sync e resolução de conflito
* `CloudKitRepository: ArquivoRepository`

Teste: duas contas iCloud reais em duas máquinas. Convide, aceite, altere de um
lado.
Aceite: convite aceito; alteração propaga em <1 min; conflito resolve sem
perda; participante removido perde acesso; `QuotaExceeded` mostra mensagem útil
sem perder dado local.
Armadilha: o usuário pode estar logado no app com um Apple ID e no iCloud do
sistema com outro. Detecte e avise.

---

## Não corte

Passo 5 (segmentação) e Passo 11 (exportação) separam o Papagaio de um gravador
de voz. Não são os primeiros candidatos a cortar se o cronograma apertar — os
riscos de cronograma reais deste projeto estão registrados em `DECISIONS.md`
(R-1 a R-7), não numa lista de features a adiar.

## Comece agora

Reconfirme o Passo 0 (ambiente já auditado em 2026-07-30) e execute o Passo 1.

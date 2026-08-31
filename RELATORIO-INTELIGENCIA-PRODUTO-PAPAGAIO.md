# Relatório de Inteligência de Produto — Papagaio

**Data da pesquisa:** 27/08/2026  
**Status:** auditoria documental ampliada; benchmark empírico e testes manuais ainda devem ser executados.  
**Escopo:** concorrentes da App Store, produtos equivalentes, projetos GitHub, componentes de IA, documentação oficial, políticas de privacidade, changelogs, issues e relatos públicos.

> Conclusão principal: transcrição e resumo já são commodities. A oportunidade do Papagaio está em oferecer um sistema local de evidências, decisões e tarefas confiáveis, com privacidade, rastreabilidade e recuperação operacional.

## 1. Escopo e metodologia

Não é tecnicamente possível afirmar que toda a internet, toda a App Store ou todo o GitHub foram cobertos. A pesquisa foi ampliada por buscas iterativas e análise de fontes primárias, formando um corpus com:

- mais de 30 listagens e produtos da App Store;
- mais de 35 repositórios GitHub relacionados a captura, transcrição, diarização, sumarização, memória e meeting bots;
- produtos cloud-first, bot-free, locais, híbridos, BYOK, self-hosted, extensões, hardware e componentes de infraestrutura;
- documentação oficial, App Store, páginas de preços, changelogs, políticas de privacidade, código/README, issues, postmortems e reviews.

### Classificação de evidências

| Evidência | Tratamento |
|---|---|
| Documentação oficial | Fato declarado pelo fornecedor; não prova qualidade independente |
| Código, issue ou postmortem | Evidência técnica específica |
| Review de usuário | Sinal de dor; não representa prevalência estatística |
| Texto de marketing | Alegação não comprovada |
| Inferência estratégica | Hipótese explicitamente marcada |
| Benchmark do próprio autor | Deve ser reproduzido antes de ser usado como vantagem |

Três subagentes foram utilizados para ampliar a descoberta. Os resultados foram tratados como hipóteses, revisados por fontes primárias e confrontados com inconsistências. Um exemplo: há divergência pública nos limites do plano gratuito do Fireflies; esse dado permanece não resolvido.

Nenhum arquivo do projeto foi alterado durante a pesquisa.

## 2. Mapa competitivo

| Categoria | Produtos | Valor central | Fraqueza estrutural |
|---|---|---|---|
| Bots para reuniões | Otter, Fireflies, Read, MeetGeek, tl;dv, Notta, Sembly | Automação e integrações | Consentimento, permissões, dependência da plataforma e nuvem |
| Cloud sem bot | Granola, Fathom, Fellow, Notion, Supernormal, Jamy | Menos atrito durante a reunião | Ainda dependem de serviços remotos e captura correta do áudio |
| Local-first | MacWhisper, Aiko, Superwhisper, Buzz, Vibe, Tacet, Mila, Trace | Privacidade e propriedade dos dados | Consumo de hardware, configuração e colaboração mais fraca |
| Ecossistema nativo | Apple Notes, Voice Memos, Google Meet | Distribuição e integração | Recursos limitados por dispositivo, região, idioma e plano |
| Hardware | PLAUD, Notta Memo | Captura simples em qualquer lugar | Custo, dependência de assinatura e dispositivo adicional |
| Apps independentes | Kiln, SiloMeet, Karl, Basil, Debrief, Inscribe, Convoxa, Lucy | Privacidade, evidência e nichos específicos | Baixa validação pública ou maturidade incerta |
| Self-hosted | Vexa, zabt.ai, Nojoin, Meetily, MeetingBot | Controle de infraestrutura | Setup, GPU, segurança operacional e manutenção |

## 3. App Store — catálogo ampliado

### 3.1 Produtos maduros e cloud-first

| Solução | Funcionalidades observadas | Fragilidade ou risco |
|---|---|---|
| [Minutes](https://apps.apple.com/us/app/minutes-ai-meeting-note-taker/id6504206467) | Gravação ao vivo, transcrição, falantes, palavras-chave, resumo, chat, edição, Apple Watch | Rating alto, mas a política técnica de processamento e retenção deve ser auditada fora da descrição |
| [Otter](https://apps.apple.com/us/app/otter-transcribe-voice-notes/id1276437113) | Bot, transcrição ao vivo, slides, comentários, tarefas, busca, calendário e colaboração | Limites de minutos/importações, dependência cloud e configurações de treinamento/revisão |
| [Fireflies](https://apps.apple.com/us/app/fireflies-ai-notetaker/id6463164203) | Bot, integrações, tarefas, métricas, AskFred, CRM e perguntas entre reuniões | Grande superfície de permissões e retenção; existem divergências públicas de limites |
| [Fathom](https://www.fathom.ai/overview) | Bot e captura sem bot, clipes, resumos, CRM, API, MCP e Ask Fathom | Exigência de calendário em alguns fluxos e políticas de melhoria de modelos |
| [Granola](https://apps.apple.com/us/app/granola-ai-meeting-notes/id6739429409) | Captura sem bot, calendário, notas editáveis, chat e compartilhamento | Não guardar áudio não significa processamento local; notas e transcrições continuam remotas |
| [Read AI](https://www.read.ai/meeting-reports) | Resumos, tarefas, sentimento, participação, coaching, highlights, Slack, Zapier e webhooks | Compartilhamento e propriedade dos relatórios são complexos |
| [Fellow](https://fellow.ai/features) | Notetaker, decisões, tarefas, templates, controle de acesso, CRM e Ask Fellow | Forte dependência de plano corporativo e configuração administrativa |
| [MeetGeek](https://meetgeek.ai/integrations) | Calendário, bots, CRM, Slack, Jira, Asana, Trello, API, webhooks e Zapier | Muitas integrações aumentam falhas, duplicações e inconsistências de permissão |
| [tl;dv](https://tldv.io/features/meeting-recordings-transcriptions/) | Gravação, destaques, traduções, resumos, tarefas e insights | Qualidade depende fortemente do áudio; exportação e histórico podem ser limitados |
| [Krisp](https://apps.apple.com/us/app/krisp-ai-meeting-note-taker/id6740535865) | Cancelamento de ruído, bot, gravação presencial, transcrição, CRM e Slack | Mistura funções de áudio e reuniões; alguns recursos aparecem como “coming soon” |
| [Supernormal](https://www.supernormal.com/meeting-notetaker) | Captura sem bot, notas, tarefas, e-mails, documentos e agentes | Continua cloud-first e requer login |
| [Notta](https://www.notta.ai/en/landing-page/meeting-notes) | Bot, gravação, transcrição, tradução, resumo, templates e integrações | Dependência de conta e nuvem; também possui hardware próprio |
| [Sembly](https://apps.apple.com/us/app/sembly-ai-meeting-notes-todos/id1618211441) | Gravação offline, sincronização posterior, 48 idiomas, falantes, biblioteca e web | Modo offline não prova pipeline integralmente local |
| [Tactiq](https://tactiq.io/transcribe) | Extensão de navegador, transcrição ao vivo, prompts, resumos e tarefas | Limitado ao navegador e usa processamento remoto |
| [Jamy](https://www.jamy.ai/product/) | Assistente que entra em chamadas, resumo, tarefas, pesquisa e Q&A | Bot cria fricção de consentimento e dependência de plataformas |

### 3.2 Apps independentes e recentes

| Solução | Diferencial observado | Risco principal |
|---|---|---|
| [Spellar](https://apps.apple.com/us/app/spellar-ai-meeting-note-taker/id6473629578) | Múltiplos modelos, modo local/cloud, Todoist, ClickUp, Asana, Obsidian, calendário e bridge transcription | Complexidade elevada; changelog registra crashes, travamentos, exportações falsas e sincronização |
| [NoteX](https://apps.apple.com/us/app/notex-ai-meeting-assistant/id6654910983) | Notas, agente, apresentações, transcrição e caderno inteligente | Escopo amplo e pouca evidência pública de qualidade técnica |
| [Noter AI](https://apps.apple.com/us/app/noter-ai-meeting-notes-summary/id6747296459) | Bot, importação, timestamps, falantes, chat, calendário e exportação Word/PDF | Produto recente com poucos ratings |
| [Noteum](https://apps.apple.com/us/app/noteum-ai-meeting-note-taker/id6737804988) | Transcrição ao vivo, Zoom, Meet, Teams, importação e atas | Muitas promessas sem evidência pública de precisão ou privacidade |
| [AI Transcribe](https://apps.apple.com/us/app/ai-transcribe-meeting-notes/id6449003263) | Mais de 20 ferramentas, tradução, tarefas, datas, perguntas e transformação de texto | Review relata falha de funcionamento e trial com cartão |
| [Atter](https://apps.apple.com/us/app/atter-ai-transcribe-meetings/id6747348330) | Resumos, decisões, tarefas, mapas mentais, links e edição | Changelog indica problemas de reconexão, idioma do bot e estados travados |
| [Notado](https://apps.apple.com/br/app/notado-atas-de-reuni%C3%A3o/id6760972229) | Priorização automática, widgets, calendário, lembretes, Face ID e PDF | Baixa validação pública e pouca informação sobre processamento |
| [Convoxa](https://apps.apple.com/br/app/convoxa-notas-de-reuni%C3%A3o-ia/id6755150446) | Fotos, quadro branco, PDF e ideias entram na linha temporal da reunião | É necessário testar OCR, associação temporal e sincronização |
| [Lucy](https://apps.apple.com/br/app/lucy-notas-de-reuni%C3%A3o/id6794497220) | WhisperKit, Qwen local, quatro falantes, baixa confiança e histórico de versões | Plataforma, disponibilidade e identificação de pessoas precisam de teste |
| [AndyNote](https://apps.apple.com/br/app/andynote-notas-de-reuni%C3%A3o-ia/id6711347090) | Tradução ao vivo, fotos, Markdown, PDF, SRT, VTT, JSON e CSV | Descrição mistura capacidades de iPhone, Watch e Mac |
| [Ata IA](https://apps.apple.com/br/app/ata-ia-gravador-de-reuni%C3%A3o/id6504087901) | Realtime, tarefas, decisões, bloqueios, compartilhamento, e-mail e offline | Review relata importação sem resposta; changelog menciona crashes e retries |
| [Reuniões IA](https://apps.apple.com/br/app/reuni%C3%B5es-ia-voz-para-resumo/id6745157520) | Templates, prompts, calendário, participantes e português | Apenas uma avaliação pública |
| [Kiln](https://apps.apple.com/us/app/kiln-ai-meeting-reports/id6784888925) | Local, nove idiomas, Jira Stories, decisões técnicas, release notes e nomes com citações | Requer Apple Silicon e Apple Intelligence para parte dos relatórios |
| [Trace](https://apps.apple.com/us/app/trace-on-device-transcripts/id6768724888) | Captura local, calendário, CLI, exportação, redaction, Obsidian, Bear e Things | Depende de permissões de Screen Recording, arquivos locais e estabilidade do modelo |
| [SiloMeet](https://apps.apple.com/us/app/silo-meet-ai-meeting-notes/id6784909255) | Receitas versionadas, campos citados, bookmarks, evidência, BYOK e recuperação local | Excelente referência, mas pode criar complexidade de UX |
| [Whisper Notes](https://apps.apple.com/us/app/whisper-notes-speech-to-text/id6447090616) | Parakeet, Whisper, SenseVoice, sistema de áudio, falantes, atalhos e exportação | Changelog registra crashes Bluetooth, imports quebrados e hallucinação em silêncio |
| [MoosePad](https://apps.apple.com/us/app/moosepad-ai-meeting-notes/id6760836937) | iCloud, áudio do sistema no Mac, notas, tarefas e transcrição local | O resumo ainda envia o transcript para a nuvem |
| [Basil](https://apps.apple.com/us/app/basil-private-ai-note-taker/id6749776500) | Apple Intelligence local, speaker memory, gravação Mac/iPhone e sem conta | A promessa “on-device” precisa ser verificada tecnicamente |
| [Karl](https://apps.apple.com/us/app/karl-voice-meeting-notes-pro/id6787791260) | Áudio do sistema com fones, speakers persistentes, iCloud, pastas e recuperação | Identificação vocal e rotas de áudio são riscos críticos |
| [Debrief](https://apps.apple.com/us/app/debrief-ai-meeting-notes/id6790697253) | Decision ledger, tarefas com dono/prazo/citação, follow-ups e “what changed?” | Pouco histórico público de avaliações |
| [Private Notes](https://apps.apple.com/us/app/private-notes-ai-note-taker/id6752633041) | Offline, Apple Intelligence, iCloud opcional, Markdown, timestamps e tarefas | Resumos dependem de dispositivos compatíveis |
| [Alt](https://apps.apple.com/us/app/alt-ai-meeting-notes/id6759488047) | Alternância entre local e cloud, tradução em 100 idiomas | Sincronização cloud envia gravações e notas |
| [Inscribe](https://apps.apple.com/br/app/inscribe-notas-ia-e-pdf/id6754086711) | PDF, Word, Excel, imagens, OCR, chat, citações e lembretes | Grande superfície de produto para uma equipe pequena |
| [Traverba](https://apps.apple.com/br/app/traverba-notas-ia-e-tradu%C3%A7%C3%A3o/id6773778315) | Tradução offline, intérprete, OCR, notas em grupo e 108 idiomas | Promessa ampla; qualidade por idioma não demonstrada |
| [VoiceMemoAI](https://apps.apple.com/us/app/voicememoai-meeting-recorder/id6759291104) | Markdown em iCloud/Google Drive, Obsidian, dois canais, “You/Them”, dicionário e menu bar | Poucas avaliações e possibilidade de divergência entre cópias |
| [Lunir](https://apps.apple.com/us/app/lunir-ai-ask-your-recordings/id6751006953) | Q&A, ações em Calendário/Contatos/Lembretes, tradução, Watch e exportação | Criptografia e sincronização precisam de auditoria técnica |
| [Owll](https://apps.apple.com/us/app/owll-ai-note-taker-assistant/id6450300197) | Watch, iPhone, web, CRM, contatos, gravações e Q&A | Mistura segundo cérebro, CRM e reuniões |
| [Voicenotes](https://apps.apple.com/us/app/voicenotes-ai-notes-meetings/id6483293628) | Notas pessoais, reuniões, memória, 100+ idiomas e integrações | Mais orientado a memória pessoal do que governança de reunião |

### 3.3 Apps locais Apple-native adicionais

| Solução | Proposta | Pontos de atenção |
|---|---|---|
| [Minutes](https://apps.apple.com/us/app/minutes-ai-meeting-note-taker/id6504206467) | Grande adoção aparente, Watch, palavras-chave e perguntas sobre gravações | Precisa de auditoria de dados e execução real |
| [Minuted](https://apps.apple.com/us/app/minuted-ai-meeting-notes/id6781033691) | Apple Intelligence, offline, identificação persistente, follow-up por e-mail | Requer capacidades específicas do dispositivo |
| [Debrief](https://apps.apple.com/us/app/debrief-ai-meeting-notes/id6790697253) | Decisões e tarefas com origem exata e controle “I owe/Waiting on” | Baixo volume de avaliações |
| [AI Notes](https://apps.apple.com/us/app/ai-note-taker-voice-recorder/id6784325645) | Decision Ledger, Open Questions Tracker e Conversation Memory | Assinatura semanal e poucos ratings |
| [Silo Transcribe](https://apps.apple.com/us/app/silo-transcribe/id6777604922) | MLX local, BYOK, citações, Markdown e sem assinatura | Apenas poucas avaliações e configuração Apple Silicon |
| [MinuteForge](https://apps.apple.com/us/app/minuteforge-ai-meeting-notes/id6757977698) | Transcript local, atas, decisões e tarefas | Resumo depende de Apple Intelligence |
| [AI Note Taker / VoiceScribe](https://apps.apple.com/us/app/ai-note-taker-for-meetings/id6774349229) | WhisperKit local, OCR e recuperação após interrupção | Deve ser testado em gravações longas e imports |
| [Private Notes](https://apps.apple.com/us/app/private-notes-ai-note-taker/id6752633041) | Gravação, resumo, tarefas e armazenamento local | Compatibilidade com Apple Intelligence |
| [Transcribe: IA de Voz Privada](https://apps.apple.com/br/app/transcribe-ia-de-voz-privada/id6756297503) | Offline, live transcript, tarefas, pastas, tags e playback palavra a palavra | Precisão real não comprovada |
| [MoosePad](https://apps.apple.com/us/app/moosepad-ai-meeting-notes/id6760836937) | Captura Mac/iPhone, iCloud e resumos | Só transcrição é local; resumo é cloud |
| [Whisper Transcription](https://apps.apple.com/us/app/whisper-transcription/id1668083311) | Captura de app, sistema e microfone, modelos locais, resumos e tarefas | Verificar vendedor, escopo real e modelo utilizado |

## 4. GitHub — catálogo ampliado

### 4.1 Componentes fundamentais

| Projeto | Papel | Limitação crítica |
|---|---|---|
| [OpenAI Whisper](https://github.com/openai/whisper) | ASR, idioma, tradução e VAD básico | Não resolve captura, diarização, identidade ou produto |
| [whisper.cpp](https://github.com/ggml-org/whisper.cpp) | Whisper em C/C++, Metal, CoreML, quantização e Apple Silicon | Aplicativo precisa resolver estado, timestamps, memória e recuperação |
| [FluidAudio](https://github.com/FluidInference/FluidAudio) | STT, VAD e diarização CoreML/ANE | Diarização não garante identidade; overlap e long-form continuam difíceis |
| [argmax-oss-swift](https://github.com/argmaxinc/argmax-oss-swift) | WhisperKit, SpeakerKit e pipelines Swift | Código e pesos podem possuir licenças diferentes |
| [pyannote-audio](https://github.com/pyannote/pyannote-audio) | Diarização, embeddings e overlap | Modelos e condições de uso não são iguais à licença do código |
| [faster-whisper](https://github.com/SYSTRAN/faster-whisper) | Whisper via CTranslate2, batch e VAD | Não oferece captura nem identidade |
| [WhisperX](https://github.com/m-bain/whisperX) | Alinhamento, timestamps e diarização | Pipeline complexo, dependências pesadas e licenças múltiplas |
| [MLX Whisper](https://github.com/ml-explore/mlx-examples/tree/main/whisper) | Execução de modelos no Apple Silicon | Ainda exige engenharia de produto |
| [mlx-audio](https://github.com/Blaizzy/mlx-audio) | Modelos de áudio no MLX | Compatibilidade e maturidade variam por modelo |

### 4.2 Aplicações locais para macOS

| Projeto | Funcionalidades | Falha ou custo provável |
|---|---|---|
| [Parley](https://github.com/fmasi/parley) | Dois canais, FluidAudio, Apple SpeechAnalyzer, diarização, scores, crash-safe e CLI | Benchmarks autorreportados e dependentes de hardware específico |
| [Heed](https://github.com/isjunrod/heed) | Apple Neural Engine, captura local, diarização, live e reprocessamento | Requer Bun, Python, Ollama e configuração de áudio |
| [MeetingScribe](https://github.com/elmoghany/meeting-scribe) | Mic + sistema, diarização, resumo, tarefas, chat e exports | Bot é scaffold; diarização live ainda é limitada |
| [Meeting Transcriber](https://github.com/jimkrygowski/meeting-transcriber) | MLX, pyannote, Ollama, speakers, Markdown/TXT e fixture de testes | Teste de 90% usa áudio sintetizado |
| [meetscribe](https://github.com/pretyflaco/meetscribe) | WhisperX, pyannote, Ollama, PDF, YAML, CLI e sincronização Git | Captura no Mac é limitada; requer token Hugging Face |
| [scribe](https://github.com/theam/scribe) | Parakeet, diarização, JSON, SRT, VTT e CLI | Essencialmente CLI |
| [Minute](https://github.com/mraza007/minute) | Offline, transcrição ao vivo, labels, resumo, decisões, tarefas e citações | Atualização automática opcional é tráfego de rede |
| [Recap](https://github.com/notadev-iamaura/meeting-transcriber) | Decision Wiki, citações, chat, busca e pipeline local | Apple Silicon, 16 GB recomendados e setup pesado |
| [mac-meeting-transcriber](https://github.com/jason-in-tech/mac-meeting-transcriber) | Glossário, cache, diarização, línguas e polish de texto | LLM opcional para nomes/polish pode gerar resultados inconsistentes |
| [Tacet](https://github.com/Tacetapp/tacet) | ScreenCaptureKit, Whisper/MLX, ECAPA, Markdown e vault local | Distribuição e dependências dificultam adoção |
| [Mila](https://github.com/island-io/mila) | macOS nativo, mic/sistema, Whisper, VAD, resumos e sync iPhone | Continuidade e cobertura de testes precisam ser avaliadas |
| [Loqui](https://github.com/joaquingit1/loqui) | Dois fluxos, supressão de eco, live, chat e MCP | Binário unsigned; Apple Silicon only |
| [HushScribe](https://github.com/drcursor/HushScribe) | Parakeet, WhisperKit, Apple Speech, Qwen/Gemma, menu bar e Markdown | Licença e maturidade precisam ser verificadas |
| [Kleoth](https://github.com/ofcRS/kleoth) | Canal “you/them”, Markdown/JSON, local e cloud opcional | Menos adequado para grupos grandes |
| [Buzz](https://github.com/chidiwilliams/buzz) | Offline Whisper, live, YouTube, diarização, watch folders e exportação | Telemetria/opções externas e distribuição precisam de auditoria |
| [Vibe](https://github.com/thewh1teagle/vibe) | Batch, áudio do sistema, VAD, diarização, CLI, API e Ollama | Grande superfície funcional e complexidade operacional |
| [Meetily](https://github.com/Zackriya-Solutions/meetily) | Tauri/Rust/Next, Parakeet/Whisper, diarização e Ollama | Separação Community/Pro deve ser auditada |
| [MeetingBro](https://github.com/armpro24-blip/MeetingBro) | Transcrição, tradução, resumo contínuo, Meeting Board e cenários | Métricas precisam ser reproduzidas |
| [NexQ](https://github.com/naxhq/NexQ) | Overlay, RAG local, 10 STT, 8 LLM, bookmarks e traduções | BYO providers aumentam configuração e risco de vazamento |
| [Kuali](https://github.com/igarrux/kuali) | Identidade fornecida pela plataforma, Discord/Meet e tarefas | Vantagem desaparece quando a plataforma não fornece identidade |
| [HoldSpeak](https://github.com/karolswdev/HoldSpeak) | Voz, reuniões, artefatos, propostas para GitHub e agents | Escopo extremamente amplo; alto risco de overengineering |
| [LifeDash](https://github.com/Lab-51/lifedash) | Calendário local, briefs, tarefas, histórico, agente e memória | Ações automáticas exigem confirmação e auditoria |

### 4.3 Self-hosted, bots e infraestrutura

| Projeto | Proposta | Limitação |
|---|---|---|
| [zabt.ai](https://github.com/afeef/zabt-ai) | FastAPI, Celery, Redis, Postgres, MinIO, faster-whisper, pyannote e LLM compatível | AGPL-3.0, GPU e infraestrutura |
| [Nojoin](https://github.com/Valtora/Nojoin) | Captura pelo navegador sem bot, dashboard, speaker library e Meeting Edge | Sem bot não significa local no dispositivo |
| [Vexa](https://github.com/Vexa-ai/vexa) | Bots para Meet, Teams, Zoom e Jitsi, WebSocket, MCP e agentes | Self-hosted não elimina problemas de autenticação e políticas |
| [MeetingBot](https://github.com/meetingbot/meetingbot) | API de bots para Meet, Teams e Zoom | LGPL-3.0 e dependência das plataformas |
| [Recall meeting-bot](https://github.com/recallai/meeting-bot) | Exemplo de bot, webhooks, áudio/vídeo e análise | Usa serviço externo; não é pipeline local |
| [Meeting-BaaS](https://github.com/Meeting-Baas/meeting-bot-as-a-service) | Viewer, upload, chat, bots e MCP | Focado em API/BaaS |
| [TranscriptionStream](https://github.com/transcriptionstream/transcriptionstream) | Upload, diarização, Ollama, Meilisearch e interface web | Ollama e diarização podem disputar VRAM |
| [ghostmeet](https://github.com/Higangssh/ghostmeet) | Chrome extension, áudio da aba, Whisper e Claude opcional | “Invisible” cria problema grave de consentimento |
| [Screenpipe](https://github.com/screenpipe/screenpipe) | Tela, áudio, OCR, transcrição, busca, API e MCP | Licença source-available/comercial |
| [Open WebUI](https://github.com/open-webui/open-webui) | Chat, RAG, STT, voz, ferramentas e conhecimento | Não é pipeline de gravação/diarização |
| [AnythingLLM](https://github.com/Mintplex-Labs/anything-llm) | Workspaces, RAG, agentes e modelos locais | Complemento de conhecimento, não captura |
| [Khoj](https://github.com/khoj-ai/khoj) | Memória, busca, agentes e contexto pessoal | AGPL-3.0 e sem pipeline nativo de reunião |
| [Anarlog](https://github.com/fastrepl/anarlog) | Captura, SQLite, arquivos, plugins e BYO AI | Licenciamento varia conforme o caminho do projeto |

## 5. Funcionalidades recorrentes

Codificação preliminar dos principais produtos, sem considerar qualidade:

| Função | Presença aproximada | Interpretação |
|---|---:|---|
| Captura e transcrição | 12/12 | Entrada obrigatória; não diferencia sozinha |
| Resumo e destaques | 10/12 | Esperado pelo usuário |
| Tarefas, decisões e próximos passos | 9/12 | Principal promessa de valor |
| Biblioteca, busca e reprodução sincronizada | 9/12 | Converte gravação em memória consultável |
| Diarização/identificação | 8/12 | Muito desejada e tecnicamente frágil |
| Calendário e captura automática | 8/12 | Reduz esquecimento e aumenta risco de consentimento |
| Perguntas entre reuniões | 8/12 | Evolui de nota para memória organizacional |
| Integrações/API/CRM | 8/12 | Aumenta retenção e lock-in |
| Importação de áudio/vídeo | 8/12 | Importante para reuniões externas |
| Compartilhamento e colaboração | 6/12 | Necessário para equipes |
| Tradução multilíngue | 6/12 | Forte em produtos globais |
| Processamento local completo | 3/12 | Baixa frequência e alto potencial de diferenciação |
| Consentimento e retenção explícitos | 4/12 | Importante, mas subatendido |

## 6. Ranking de geração de valor

### 1. Captura confiável

Se o áudio não for capturado integralmente, todas as funções seguintes falham. O produto precisa indicar claramente se está recebendo microfone e áudio do sistema, sobreviver a fones, troca de dispositivo, pausa, suspensão, importação e falhas.

### 2. Transcrição com evidência

A transcrição precisa estar ligada ao áudio por timestamp, permitir reprodução do trecho e indicar incerteza. O model card do Whisper documenta alucinações, repetição e desempenho desigual entre idiomas e sotaques. O whisper.cpp possui issues sobre alucinação em silêncio, loops longos e timestamps após VAD.

- [Whisper model card](https://github.com/openai/whisper/blob/main/model-card.md)
- [Whisper.cpp — silêncio/alucinação](https://github.com/ggml-org/whisper.cpp/issues/1724)
- [Whisper.cpp — loops em gravações longas](https://github.com/ggml-org/whisper.cpp/issues/2755)
- [Whisper.cpp — gaps e timestamps](https://github.com/ggml-org/whisper.cpp/issues/3634)

### 3. Resumo fundamentado

O resumo deve responder o que foi decidido, por que, quem ficou responsável, qual prazo existe e qual trecho da reunião comprova cada afirmação.

### 4. Tarefas executáveis

Uma tarefa útil precisa conter descrição, responsável, prazo, origem, status e confiança. A maioria dos produtos extrai action items; poucos demonstram rastreabilidade e controle de qualidade.

### 5. Busca transversal

O usuário quer responder “quando decidimos isso?”, “quem ficou responsável?” e “essa decisão mudou depois?”. Essa é a transição entre um gravador e uma memória operacional.

### 6. Privacidade e controle

Privacidade deve ser funcional: processamento local, indicador de captura, modo fora de registro, consentimento auditável, exclusão verificável, exportação completa, retenção configurável e explicação dos modelos/subprocessadores.

### 7. Recuperação operacional

O sistema deve sobreviver a suspensão, falta de espaço, interrupção do modelo, falha de exportação, mudança de rota de áudio, fechamento inesperado e processamento de gravações longas.

## 7. Diferenciais defensáveis para o Papagaio

### Pipeline local completo

```text
Áudio local
    ↓
Transcrição local
    ↓
Diarização local
    ↓
Resumo local
    ↓
Busca local
    ↓
Exportação aberta
```

MacWhisper, Aiko e Superwhisper demonstram demanda por processamento local. O Papagaio pode integrar isso à gestão de reuniões, tarefas e espaços de equipe.

- [MacWhisper](https://goodsnooze.gumroad.com/l/macwhisper)
- [Aiko](https://apps.apple.com/us/app/aiko/id1672085276)
- [Superwhisper offline](https://superwhisper.com/offline-transcription)

### Resultado auditável

Toda decisão, tarefa ou resumo deveria apontar para a linha, timestamp e trecho de origem.

### Diarização honesta

O sistema deve diferenciar “Falante 1”, “João identificado com alta confiança” e “voz semelhante a João, baixa confiança”. Diarização acústica não é identificação civil.

### Português brasileiro

Oportunidades: vocabulário customizado, nomes próprios, siglas, termos técnicos, variações regionais, code-switching, pontuação e templates brasileiros. Isso precisa ser medido com corpus real.

### Exportação durável

Markdown, JSON, SRT, VTT, PDF e áudio devem continuar utilizáveis se a conta, assinatura ou aplicativo desaparecer.

## 8. Pente fino das falhas

### Antes da reunião

- Calendário pode selecionar reuniões erradas.
- Captura automática pode ocorrer sem expectativa clara.
- Participantes podem não saber que estão sendo gravados.
- Permissões do Zoom, Teams e Google Meet variam por administrador.
- OAuth e mudanças de API podem quebrar integrações.

### Durante a captura

- Permissão concedida, mas áudio não chegando.
- Áudio remoto ausente com fones.
- Troca de Bluetooth interrompendo a gravação.
- Volumes incompatíveis entre microfone e sistema.
- Suspensão ou falta de energia corrompendo o arquivo.
- Usuário só descobrindo no final que o arquivo está vazio.

### Na transcrição

- Alucinação em silêncio.
- Repetição em arquivos longos.
- Deslocamento de timestamp após VAD.
- Erro em sotaques, ruído, gírias e code-switching.
- Termos técnicos e nomes próprios incorretos.
- Falta de distinção entre transcript provisório e final.

### Na diarização

- Troca de identidade entre blocos.
- Confusão entre “Speaker 1” e identidade real.
- Falas sobrepostas atribuídas ao participante errado.
- Uma única gravação de sala dificultando separação.
- Voiceprint envolvendo dado biométrico sensível.

Referências técnicas: [FluidAudio benchmarks](https://github.com/FluidInference/FluidAudio/blob/main/Documentation/Benchmarks.md), [pyannote](https://github.com/pyannote/pyannote-audio) e [ICO sobre dados biométricos](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/biometric-data-guidance-biometric-recognition/biometric-recognition/?q=accuracy).

### No resumo

- Decisões omitidas.
- Responsável errado.
- Prazo inferido sem base.
- Discordância convertida em consenso.
- Q&A usando contexto fora da reunião.
- Falta de citação para auditoria.

### Na privacidade

- “Sem treinamento” não significa “sem retenção”.
- “Sem áudio armazenado” não significa “sem transcript armazenado”.
- Subprocessadores podem receber áudio ou texto.
- Compartilhamento padrão pode expor relatórios.
- Exclusão no app pode não remover backups e exportações.
- Sessões e tokens podem continuar ativos após desativação.
- Calendário pode revelar metadados mesmo com conteúdo local.

Casos documentados incluem configurações e problemas específicos de Otter, Fathom, Granola, Read e Fireflies. Os postmortems do Granola comprovam vulnerabilidades específicas corrigidas, mas não permitem inferir taxa geral de incidentes:

- [Otter — feedback e melhoria](https://help.otter.ai/hc/en-us/articles/25352082563863-Provide-feedback-to-Otter)
- [Fathom — privacidade](https://www.fathom.ai/privacy)
- [Granola — segurança](https://www.granola.ai/security)
- [Granola — sessão persistente](https://docs.granola.ai/help-center/policies/security-reports/post-mortem-google-workspace-session-logout-vulnerability)
- [Granola — conta não gerenciada](https://docs.granola.ai/help-center/policies/security-reports/post-mortem-legacy-unmanaged-google-accounts-workspace-auto-join)
- [Granola — chave AssemblyAI](https://docs.granola.ai/help-center/policies/security-reports/post-mortem-assembly-ai-api-key-exposure)

### No open source

- Código e pesos dos modelos podem ter licenças diferentes.
- Hugging Face pode exigir aceite e token.
- AGPL, LGPL, Apache, MIT e licenças comerciais mudam a possibilidade de incorporação.
- Projetos pequenos podem não possuir assinatura ou notarização.
- Benchmarks do autor não substituem teste independente.
- README pode prometer macOS, mas captura funcionar apenas no Linux.

## 9. Diagnóstico do Papagaio

### Pontos fortes observados no checkout atual

- captura de microfone e áudio do sistema;
- pausa, retomada e cancelamento;
- waveform independente;
- importação de gravações;
- processamento local com Whisper;
- diarização local com FluidAudio;
- sumarização local;
- notas, marcadores e tarefas;
- biblioteca com busca, favoritos, pastas e lixeira;
- recuperação e reprocessamento;
- player sincronizado com a transcrição;
- integração com calendário;
- espaços compartilhados via CloudKit;
- arquitetura nativa SwiftUI/SwiftData;
- separação de runtimes para evitar conflitos entre frameworks de IA.

### Riscos ainda não comprovados

A inspeção documental não substitui testes para confirmar:

- precisão real em português;
- DER/JER da diarização;
- precisão de responsáveis e prazos;
- citações automáticas em cada tarefa;
- robustez com fala sobreposta;
- suspensão, troca de fones e baixa memória;
- teste ponta a ponta com dois Apple IDs;
- sincronização de mídia e anexos;
- exportação completa e restauração independente;
- CPU, memória, bateria e temperatura;
- recuperação após encerramento durante processamento.

## 10. Priorização recomendada

| Prioridade | Iniciativa | Motivo |
|---|---|---|
| P0 | Indicador de captura saudável | Evita reunião perdida |
| P0 | Timestamps e citações no resumo/tarefas | Combate alucinação e aumenta confiança |
| P0 | Consentimento e modo fora de registro | Reduz risco jurídico e reputacional |
| P0 | Reprocessamento idempotente | Garante recuperação |
| P0 | Exportação completa e exclusão verificável | Reduz lock-in |
| P1 | Tarefas com responsável, prazo e evidência | Converte nota em ação |
| P1 | Busca transversal | Cria memória de longo prazo |
| P1 | Vocabulário por equipe | Melhora nomes e termos técnicos |
| P1 | Templates de reunião | Aumenta consistência |
| P1 | Teste CloudKit com dois usuários reais | Valida colaboração |
| P2 | Integrações com tarefas, CRM e Slack | Expande workflow após o núcleo |
| P2 | Tradução multilíngue | Expansão de mercado |
| P3 | Sentimento e coaching | Menor prioridade e maior risco interpretativo |

## 11. Benchmark empírico necessário

Criar corpus autorizado com:

- português brasileiro;
- dois, três e quatro falantes;
- fala simultânea;
- ruído e eco;
- microfone único;
- reunião remota;
- português-inglês;
- nomes próprios e termos técnicos;
- silêncio longo;
- 30 minutos, 2 horas e 4 horas.

Comparar Papagaio com Apple Voice Memos/Notes, MacWhisper, Aiko, Granola e Otter ou Fathom.

| Área | Métrica |
|---|---|
| Transcrição | WER/CER, omissões e alucinações |
| Tempo | Latência até transcript e resumo |
| Diarização | DER/JER e troca de identidade |
| Timestamps | Desvio médio e máximo |
| Tarefas | Precisão/recall de decisões, donos e prazos |
| Operação | Falhas após suspensão, pausa, fones e baixa memória |
| Recursos | Pico de RAM, CPU, energia e temperatura |
| Privacidade | Dados enviados, persistidos, deletados e exportados |
| Colaboração | Conflitos, permissões e sincronização |

## 12. Veredito

O posicionamento mais forte não é:

> “Mais um app que grava e resume reuniões.”

É:

> “Um sistema privado e verificável que transforma conversas em memória e ações, mantendo cada conclusão ligada à evidência original.”

O catálogo ampliado mostra que o Papagaio agora compete também com apps locais como Kiln, Trace, SiloMeet, Karl, Basil, Whisper Notes, MoosePad e Debrief, além de projetos como Parley, Heed, Recap, MeetingScribe, Vibe, Tacet e Loqui.

A existência de Whisper, FluidAudio, Qwen e CloudKit não constitui diferencial isoladamente. O diferencial será a integração confiável desses componentes em um fluxo que sobreviva a falhas reais.

Não devem ser tratados como fatos sem verificação própria:

- “95% de precisão”;
- “100% privado”;
- “sem dados coletados”;
- “offline”;
- ratings da App Store;
- benchmarks produzidos pelo próprio autor;
- promessas de identificação de falantes.

## 13. Fontes regulatórias e de governança

- [ICO — obtenção e registro de consentimento](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/consent/how-should-we-obtain-record-and-manage-consent/?q=necessary)
- [ICO — compartilhamento de dados](https://ico.org.uk/for-organisations/advice-and-services/innovation-advice/previously-asked-questions/)
- [ICO — dados biométricos e reconhecimento vocal](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/biometric-data-guidance-biometric-recognition/biometric-recognition/?q=accuracy)
- [LGPD — gov.br](https://www.gov.br/saude/pt-br/acesso-a-informacao/lgpd)
- [AP — riscos de AI notetakers](https://apnews.com/article/c700299371ca7cfec77dafdfb948067f)
- [Google Meet — AI Notes](https://support.google.com/meet/answer/14754931?hl=en)
- [Apple Notes — gravação, transcrição e resumo](https://support.apple.com/guide/mac-help/use-apple-intelligence-in-notes-mchl2102c2ae/26/mac/)
- [Apple Voice Memos — transcrição](https://support.apple.com/guide/voice-memos/view-a-transcription-of-a-recording-vm4a03609f0d/3.2/mac/26)

## 14. Limites deste relatório

- Não foi feita instalação manual de todos os produtos.
- Não foi executado benchmark uniforme entre concorrentes.
- Não foi feita auditoria de backend, tráfego de rede ou binários de cada aplicativo.
- Reviews não foram usados para estimar prevalência estatística.
- Preços, ratings e disponibilidade são snapshots regionais.
- O catálogo GitHub diferencia código, modelos, dependências e licenças, mas cada incorporação exige revisão jurídica própria.

Este documento representa a auditoria documental ampliada e serve como base para a próxima fase: testes reproduzíveis, auditoria manual e validação direta contra o Papagaio.

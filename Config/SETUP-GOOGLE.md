# Setup — Google Calendar (credenciais OAuth)

O Client ID/Secret do Google **não vive no repositório** (ele é público).
Cada desenvolvedor injeta os valores localmente, uma única vez.

## Setup (uma vez por máquina)

```bash
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
```

Abra `Config/Secrets.xcconfig` e preencha com as credenciais do
[Google Cloud Console](https://console.cloud.google.com)
(**APIs e Serviços → Credenciais → ID do cliente OAuth**, tipo
*Aplicativo para computador*):

```
GOOGLE_CLIENT_ID = 1234...apps.googleusercontent.com
GOOGLE_CLIENT_SECRET = GOCSPX-...
```

Pronto. O arquivo é gitignored: `git pull`, merge e checkout nunca o
tocam. Sem ele o app compila normalmente — a seção Google Calendar só
aparece como "não configurada" nas Configurações.

## Como funciona

- `Config/Base.xcconfig` (versionado) faz `#include? "Secrets.xcconfig"`
  (opcional) e está ligado ao target como *base configuration*.
- As variáveis `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET` viram build
  settings.
- O `Config/Info.plist` versionado referencia `$(GOOGLE_CLIENT_ID)` nos
  valores; o Xcode expande no build (`infoPlistUtility -expandbuildsettings`).
  Keys nunca são expandidas, segredos nunca tocam o git.

## CI (Xcode Cloud)

Builds de nuvem não têm o arquivo local → integração Calendar fica
desabilitada no app de CI, sem erro. Para habilitar lá, defina as
variáveis de ambiente `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET` no
workflow do Xcode Cloud e gere o xcconfig no `ci_post_clone.sh`.

## Segurança

Se um secret vazar por acidente: **revogue-o** no Google Cloud Console
(Credenciais → excluir cliente / recriar) antes de qualquer limpeza de
histórico — rotação invalida o vazamento mesmo que o git antigo persista
em forks/clones.

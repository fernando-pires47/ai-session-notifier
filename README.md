# Telegram Notify Plugin para OpenCode

Plugin local para enviar notificacoes no Telegram quando a sessao do OpenCode termina (`session.idle`).

## O que ele faz

- Envia mensagem quando a sessao fica idle (fim da execucao).
- Permite configurar notificacao de erro (`session.error`) durante a sessao.
- Permite definir duracao minima de sessao para evitar notificacoes curtas.
- Evita notificacoes duplicadas em janela curta.
- Permite testar envio imediatamente com `/notify test`.
- Permite salvar/consultar ultimo erro de envio com `/notify last-error`.
- Nao depende de bibliotecas externas.

## Arquivos

- `telegram-notify.plugin.js`: logica do plugin.
- `install.sh`: instalador com suporte a escopo global e de projeto.
- `toggle-notify.sh`: altera notificacoes em tempo de execucao.
- `notify.md` (instalado automaticamente): comando `/notify` no OpenCode.

## Pre-requisitos

- OpenCode instalado.
- Um bot do Telegram criado via BotFather.
- `chat_id` do destino para receber mensagens.

## 1) Criar bot e obter token

1. No Telegram, abra o `@BotFather`.
2. Rode `/newbot` e finalize a criacao.
3. Copie o token (formato parecido com `123456:ABC...`).

## 2) Obter o chat_id

Opcao simples:

1. Envie uma mensagem para o bot (ou adicione o bot ao grupo/canal correto).
2. Acesse:

```text
https://api.telegram.org/bot<SEU_TOKEN>/getUpdates
```

3. Procure por `"chat":{"id": ...}` e use esse valor em `OPENCODE_TG_CHAT_ID`.

## 3) Instalar o plugin

### Global (padrao)

```bash
./install.sh --i opencode
```

Instala em `~/.config/opencode/plugins/telegram-notify.plugin.js`.

### Projeto atual

```bash
./install.sh --i opencode --project
```

Instala em `.opencode/plugins/telegram-notify.plugin.js`.

O instalador grava no mesmo diretorio do plugin:

- `telegram-notify.state.json`: estado ativo para toggle em runtime

Reinstalacao nao apaga seu estado personalizado: o instalador preserva valores ja existentes e apenas completa chaves faltantes com defaults.

Valor default apos instalar:

- `enabled: true`
- `idle: true`
- `error: false`
- `debugError: false`
- `minSessionSeconds: 60`

Tambem instala o comando customizado:

- Global: `~/.config/opencode/commands/notify.md`
- Projeto: `.opencode/commands/notify.md`

## 4) Configurar variaveis de ambiente

```bash
export OPENCODE_TG_BOT_TOKEN='<seu_bot_token>'
export OPENCODE_TG_CHAT_ID='<seu_chat_id>'
```

Controle de notificacao de erro e feito via state (`/notify error on|off`).

## 5) Ativar/desativar durante a sessao

Primeiro, torne o script executavel:

```bash
chmod +x ./toggle-notify.sh
```

Ver estado atual:

```bash
./toggle-notify.sh --i opencode status
```

Escopo do projeto atual:

```bash
./toggle-notify.sh --i opencode --project status
```

Ligar/desligar tudo:

```bash
./toggle-notify.sh --i opencode all on
./toggle-notify.sh --i opencode all off
```

Ligar/desligar so idle:

```bash
./toggle-notify.sh --i opencode idle on
./toggle-notify.sh --i opencode idle off
```

Ligar/desligar so error:

```bash
./toggle-notify.sh --i opencode error on
./toggle-notify.sh --i opencode error off
```

O plugin le `telegram-notify.state.json` a cada evento, entao a mudanca vale na sessao atual sem reiniciar o OpenCode.

## 6) Usar via comando `/notify` no OpenCode

Depois da instalacao, voce pode controlar direto no chat do OpenCode:

```text
/notify
/notify status
/notify on
/notify off
/notify idle on
/notify idle off
/notify error on
/notify error off
/notify debug on
/notify debug off
/notify min 120
/notify min off
/notify test
/notify last-error
```

Atalhos:

- `/notify on` equivale a `all on`
- `/notify off` equivale a `all off`
- `/notify min off` desativa filtro de duracao minima (equivale a `0`)
- `/notify test` envia uma notificacao de teste na hora
- `/notify debug on` habilita log detalhado de falhas e salva `lastError`
- `/notify last-error` mostra o ultimo erro salvo no state

Depois disso, abra o OpenCode no mesmo shell (ou garanta que as envs estejam carregadas no ambiente).

## Exemplo de mensagem

```text
OpenCode: sessao finalizada
Projeto: meu-projeto
Status: concluida
Sessao: abc123
Duracao: 135s
Diretorio: /caminho/do/projeto
```

## Troubleshooting

- Sem notificacao:
  - verifique `OPENCODE_TG_BOT_TOKEN` e `OPENCODE_TG_CHAT_ID`.
  - confirme se o bot recebeu ao menos uma mensagem no chat alvo.
- Token correto, mas erro de envio:
  - confira se o chat_id e do chat certo (privado/grupo/canal).
- Plugin nao carregou:
  - confirme o caminho de instalacao e reinicie o OpenCode.

## Uso do instalador

```bash
./install.sh --help
```

Parametros:

- `--i <ia>`: obrigatorio. Atualmente suporta apenas `opencode`.
- `--project`: instala no projeto atual.
- sem `--project`: instalacao global.

## Uso do toggle

```bash
./toggle-notify.sh --help
```

Parametros:

- `--i <ia>`: obrigatorio. Atualmente suporta apenas `opencode`.
- `--project`: usa plugin do projeto atual.
- `status`: mostra estado atual.
- `all on|off`: liga/desliga todas notificacoes.
- `idle on|off`: liga/desliga notificacao de sessao idle.
- `error on|off`: liga/desliga notificacao de erro.
- `min <segundos|off>`: define duracao minima da sessao para notificar.

# Telegram Notify Plugin for OpenCode

Local plugin to send Telegram notifications when an OpenCode session ends (`session.idle`).

## What it does

- Sends a message when the session becomes idle (end of execution).
- Lets you configure error notifications (`session.error`) during the session.
- Lets you define a minimum session duration to avoid short notifications.
- Avoids duplicate notifications within a short window.
- Lets you test delivery immediately with `/notify test`.
- Lets you save/check the latest send error with `/notify last-error`.
- Does not depend on external libraries.

## Files

- `telegram-notify.plugin.js`: plugin logic.
- `install.sh`: installer with global and project scope support.
- `toggle-notify.sh`: toggles notifications at runtime.
- `notify.md` (installed automatically): `/notify` command in OpenCode.

## Prerequisites

- OpenCode installed.
- A Telegram bot created with BotFather.
- Destination `chat_id` to receive messages.

## 1) Create bot and get token

1. In Telegram, open `@BotFather`.
2. Run `/newbot` and finish setup.
3. Copy the token (format similar to `123456:ABC...`).

## 2) Get the chat_id

Simple option:

1. Send a message to the bot (or add the bot to the correct group/channel).
2. Open:

```text
https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates
```

3. Find `"chat":{"id": ...}` and use this value in `OPENCODE_TG_CHAT_ID`.

## 3) Install the plugin

### Quick install (one command)

Global (default):

```bash
curl -fsSL https://raw.githubusercontent.com/fernando-pires47/ai-session-notifier/main/quick-install.sh | bash -s -- --i opencode
```

Current project:

```bash
curl -fsSL https://raw.githubusercontent.com/fernando-pires47/ai-session-notifier/main/quick-install.sh | bash -s -- --i opencode --project
```

Pin a specific version/tag:

```bash
curl -fsSL https://raw.githubusercontent.com/fernando-pires47/ai-session-notifier/main/quick-install.sh | bash -s -- --i opencode -v 1.0.0
```

### Global (default)

```bash
./install.sh --i opencode
```

Installs to `~/.config/opencode/plugins/telegram-notify.plugin.js`.

### Current project

```bash
./install.sh --i opencode --project
```

Installs to `.opencode/plugins/telegram-notify.plugin.js`.

The installer writes to the same plugin directory:

- `telegram-notify.state.json`: active state used for runtime toggles

Reinstall does not erase your custom state: the installer preserves existing values and only fills missing keys with defaults.

Default values after install:

- `enabled: true`
- `idle: true`
- `error: false`
- `debugError: false`
- `minSessionSeconds: 60`

It also installs the custom command:

- Global: `~/.config/opencode/commands/notify.md`
- Project: `.opencode/commands/notify.md`

## 4) Configure environment variables

```bash
export OPENCODE_TG_BOT_TOKEN='<your_bot_token>'
export OPENCODE_TG_CHAT_ID='<your_chat_id>'
```

Error notification control is done via state (`/notify error on|off`).

## 5) Enable/disable during the session

First, make the script executable:

```bash
chmod +x ./toggle-notify.sh
```

Show current state:

```bash
./toggle-notify.sh --i opencode status
```

Current project scope:

```bash
./toggle-notify.sh --i opencode --project status
```

Enable/disable everything:

```bash
./toggle-notify.sh --i opencode all on
./toggle-notify.sh --i opencode all off
```

Enable/disable idle only:

```bash
./toggle-notify.sh --i opencode idle on
./toggle-notify.sh --i opencode idle off
```

Enable/disable error only:

```bash
./toggle-notify.sh --i opencode error on
./toggle-notify.sh --i opencode error off
```

The plugin reads `telegram-notify.state.json` on every event, so changes apply to the current session without restarting OpenCode.

## 6) Use with `/notify` command in OpenCode

After installation, you can control everything directly in OpenCode chat:

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

Shortcuts:

- `/notify on` is equivalent to `all on`
- `/notify off` is equivalent to `all off`
- `/notify min off` disables minimum duration filtering (equivalent to `0`)
- `/notify test` sends a test notification immediately
- `/notify debug on` enables detailed failure logs and saves `lastError`
- `/notify last-error` shows the latest error saved in state

After that, open OpenCode in the same shell (or ensure env vars are loaded in the process environment).

## Example message

```text
OpenCode: session finished
Project: my-project
Status: completed
Session: abc123
Duration: 135s
Directory: /path/to/project
```

## Troubleshooting

- No notification:
  - check `OPENCODE_TG_BOT_TOKEN` and `OPENCODE_TG_CHAT_ID`.
  - make sure the bot has received at least one message in the target chat.
- Correct token, but send error:
  - check if `chat_id` belongs to the correct chat (private/group/channel).
- Plugin did not load:
  - verify install path and restart OpenCode.

## Installer usage

```bash
./install.sh --help
```

Parameters:

- `--i <ia>`: required. Currently supports only `opencode`.
- `--project`: installs in current project.
- without `--project`: global install.

## Toggle usage

```bash
./toggle-notify.sh --help
```

Parameters:

- `--i <ia>`: required. Currently supports only `opencode`.
- `--project`: uses plugin from current project.
- `status`: shows current state.
- `all on|off`: enables/disables all notifications.
- `idle on|off`: enables/disables idle session notification.
- `error on|off`: enables/disables error notification.
- `min <seconds|off>`: sets minimum session duration for notifications.

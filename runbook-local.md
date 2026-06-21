# Runbook — Local Install & Test

## Prerequisites

- OpenCode installed
- Telegram bot token (via `@BotFather`)
- Chat ID (send a message to your bot, then check `https://api.telegram.org/bot<TOKEN>/getUpdates`)

## Install

```bash
# Make scripts executable
chmod +x install.sh toggle-notify.sh

# Install globally
./install.sh --i opencode

# Or per-project (installs into .opencode/plugins/ in the current directory)
./install.sh --i opencode --project
```

## Configure

```bash
export OPENCODE_TG_BOT_TOKEN='<your_bot_token>'
export OPENCODE_TG_CHAT_ID='<your_chat_id>'
```

## Verify

```bash
# Check installed version
./toggle-notify.sh --i opencode version

# Check status
./toggle-notify.sh --i opencode status

# Send a test notification
./toggle-notify.sh --i opencode test
```

If you used `--project`, add `--project` to the toggle commands as well:

```bash
./toggle-notify.sh --i opencode --project status
./toggle-notify.sh --i opencode --project test
```

## Run OpenCode

```bash
# In the same shell (so env vars are inherited)
opencode
```

Use `/notify` inside OpenCode to toggle notifications during a session.

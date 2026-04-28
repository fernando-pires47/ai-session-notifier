---
description: Controls Telegram notifications (status/on/off/min)
---
Run the command below and reply with the result objectively.

!`"/home/fernando/Documents/fonts/fernando/ai-session-notifier/.opencode/plugins/toggle-notify.sh" --i opencode --project $ARGUMENTS`

Rules:
- If no arguments are provided, show status.
- Shortcuts: `on` = `all on`; `off` = `all off`.
- Minimum duration: `min <seconds>` or `min off`.
- Send test: `test`.
- Error debug: `debug on` or `debug off`.
- Last error: `last-error`.

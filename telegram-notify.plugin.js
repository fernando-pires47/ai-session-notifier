import { mkdir, writeFile } from "node:fs/promises"
import { dirname } from "node:path"
import { fileURLToPath } from "node:url"

const DEDUPE_WINDOW_MS = 15000
const STATE_FILE_NAME = "telegram-notify.state.json"
const DEFAULT_MIN_SESSION_SECONDS = 60

export const TelegramNotifyPlugin = async ({ project, directory, client }) => {
  const sentAtByKey = new Map()
  const sessionStartById = new Map()
  let warnedMissingEnv = false
  let warnedStateRead = false

  const getEnv = () => {
    const token = process.env.OPENCODE_TG_BOT_TOKEN
    const chatId = process.env.OPENCODE_TG_CHAT_ID
    return { token, chatId }
  }

  const loadState = async () => {
    try {
      const stateUrl = new URL(`./${STATE_FILE_NAME}`, import.meta.url)
      const response = await fetch(stateUrl)
      if (!response.ok) return null
      return await response.json()
    } catch (error) {
      if (warnedStateRead) return null
      warnedStateRead = true
      await client.app.log({
        body: {
          service: "telegram-notify-plugin",
          level: "warn",
          message: "Could not load runtime state. Falling back to defaults.",
          extra: { error: String(error) },
        },
      })
      return null
    }
  }

  const saveState = async (state) => {
    const stateUrl = new URL(`./${STATE_FILE_NAME}`, import.meta.url)
    const statePath = fileURLToPath(stateUrl)
    await mkdir(dirname(statePath), { recursive: true })
    await writeFile(statePath, `${JSON.stringify(state, null, 2)}\n`, "utf-8")
  }

  const resolvePolicy = (state) => {
    const policy = {
      enabled: true,
      idle: true,
      error: false,
      question: true,
      debugError: false,
      minSessionSeconds: DEFAULT_MIN_SESSION_SECONDS,
    }

    if (state && typeof state.enabled === "boolean") policy.enabled = state.enabled
    if (state && typeof state.idle === "boolean") policy.idle = state.idle
    if (state && typeof state.error === "boolean") policy.error = state.error
    if (state && typeof state.question === "boolean") policy.question = state.question
    if (state && typeof state.debugError === "boolean") policy.debugError = state.debugError
    if (state && typeof state.minSessionSeconds === "number" && Number.isFinite(state.minSessionSeconds)) {
      policy.minSessionSeconds = Math.max(0, Math.floor(state.minSessionSeconds))
    }

    return policy
  }

  const maybeWarnMissingEnv = async () => {
    if (warnedMissingEnv) return
    warnedMissingEnv = true
    await client.app.log({
      body: {
        service: "telegram-notify-plugin",
        level: "warn",
        message: "Telegram variables are missing. Set OPENCODE_TG_BOT_TOKEN and OPENCODE_TG_CHAT_ID.",
      },
    })
  }

  const getSessionId = (event) =>
    event?.properties?.sessionID ||
    event?.properties?.info?.id ||
    event?.sessionID ||
    event?.sessionId ||
    event?.session?.id ||
    event?.id ||
    "unknown"

  const markSessionStart = (sessionId) => {
    if (!sessionId || sessionId === "unknown") return
    if (!sessionStartById.has(sessionId)) {
      sessionStartById.set(sessionId, Date.now())
    }
  }

  const getSessionDurationSeconds = (sessionId) => {
    const startedAt = sessionStartById.get(sessionId)
    if (!startedAt) return 0
    return Math.max(0, Math.floor((Date.now() - startedAt) / 1000))
  }

  const shouldSend = (eventType, sessionId) => {
    const key = `${eventType}:${sessionId}`
    const now = Date.now()
    const previous = sentAtByKey.get(key)
    if (previous && now - previous < DEDUPE_WINDOW_MS) return false
    sentAtByKey.set(key, now)
    return true
  }

  const getProjectName = () =>
    project?.id || directory?.split("/").filter(Boolean).pop() || "unknown-project"

  const getDirectoryName = () =>
    (directory || process.cwd()).split("/").filter(Boolean).pop() || "unknown"

  const getSessionTokenInfo = async (sessionId) => {
    try {
      const result = await client.session.messages({ path: { id: sessionId } })
      if (!result.data || !Array.isArray(result.data)) return null

      const lastAssistant = [...result.data].reverse().find(
        (item) => item.info?.role === "assistant" && item.info.tokens
      )
      if (!lastAssistant) return null

      const { input, output, reasoning } = lastAssistant.info.tokens
      const cost = typeof lastAssistant.info.cost === "number" ? lastAssistant.info.cost : 0

      if (input === 0 && output === 0 && reasoning === 0) return null
      return { input, output, reasoning, cost: Math.round(cost * 10000) / 10000 }
    } catch {
      return null
    }
  }

  const getSessionAgentInfo = async (sessionId) => {
    try {
      const result = await client.session.messages({ path: { id: sessionId } })
      if (!result.data || !Array.isArray(result.data)) return null

      let agentName = null
      for (const item of result.data) {
        if (item.info?.role === "user" && item.info.agent) {
          agentName = item.info.agent
          break
        }
      }

      if (!agentName) return null

      const agentsResult = await client.app.agents()
      const agents = agentsResult.data
      if (!agents || !Array.isArray(agents)) return { name: agentName, mode: "unknown" }

      const agent = agents.find((a) => a.name === agentName)
      return { name: agentName, mode: agent?.mode || "unknown" }
    } catch {
      return null
    }
  }

  const formatTokens = ({ input, output, reasoning, cost }) => {
    const fmt = (n) => {
      if (n < 1000) return String(n)
      if (n < 1000000) return `${(n / 1000).toFixed(1)}k`
      return `${(n / 1000000).toFixed(1)}M`
    }

    const parts = []
    if (input > 0) parts.push(`${fmt(input)} in`)
    if (output > 0) parts.push(`${fmt(output)} out`)
    if (reasoning > 0) parts.push(`${fmt(reasoning)} reasoning`)
    parts.push(`$${cost.toFixed(2)}`)
    return parts.join(" / ")
  }

  const sendTelegram = async (message) => {
    const { token, chatId } = getEnv()
    if (!token || !chatId) {
      await maybeWarnMissingEnv()
      return {
        ok: false,
        reason: "missing-env",
        details: "Missing OPENCODE_TG_BOT_TOKEN or OPENCODE_TG_CHAT_ID.",
      }
    }

    const response = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        chat_id: chatId,
        text: message,
        disable_web_page_preview: true,
      }),
    })

    if (!response.ok) {
      const body = await response.text()
      return {
        ok: false,
        reason: "http-error",
        status: response.status,
        body,
      }
    }

    return { ok: true }
  }

  return {
    "tool.execute.before": async (input) => {
      if (input.tool !== "question") return

      const sessionId = input.sessionID || input.sessionId || input.session?.id || "unknown"
      const eventType = "session.question"

      markSessionStart(sessionId)

      const runtimeState = await loadState()
      const policy = resolvePolicy(runtimeState)

      if (!policy.enabled) return
      if (!policy.question) return

      const durationSeconds = getSessionDurationSeconds(sessionId)
      if (durationSeconds < policy.minSessionSeconds) return

      if (!shouldSend(eventType, sessionId)) return

      const projectName = getProjectName()
      const cwd = getDirectoryName()
      const text = [
        "OpenCode: needs your input",
        `Project: ${projectName}`,
        `Session: ${sessionId}`,
        `Duration: ${durationSeconds}s`,
        `Directory: ${cwd}`,
      ].join("\n")

      try {
        const result = await sendTelegram(text)
        if (!result.ok) {
          const lastError = {
            at: new Date().toISOString(),
            scope: "event-send",
            eventType,
            sessionId,
            message:
              result.reason === "http-error"
                ? "HTTP failure while sending Telegram notification."
                : "Missing Telegram environment variables.",
            status: result.status,
            body: result.body,
            details: result.details,
          }

          await saveState({
            ...(runtimeState || {}),
            enabled: policy.enabled,
            idle: policy.idle,
            error: policy.error,
            question: policy.question,
            debugError: policy.debugError,
            minSessionSeconds: policy.minSessionSeconds,
            lastError,
          })

          await client.app.log({
            body: {
              service: "telegram-notify-plugin",
              level: "error",
              message:
                result.reason === "http-error"
                  ? `Failed to send Telegram message (${result.status}).`
                  : "Telegram variables are missing.",
              extra: policy.debugError
                ? { eventType, sessionId, status: result.status, body: result.body, details: result.details }
                : undefined,
            },
          })
        }
      } catch (error) {
        const lastError = {
          at: new Date().toISOString(),
          scope: "event-send",
          eventType,
          sessionId,
          message: "Unexpected error while sending Telegram notification.",
          error: String(error),
        }

        await saveState({
          ...(runtimeState || {}),
          enabled: policy.enabled,
          idle: policy.idle,
          error: policy.error,
          question: policy.question,
          debugError: policy.debugError,
          minSessionSeconds: policy.minSessionSeconds,
          lastError,
        })

        await client.app.log({
          body: {
            service: "telegram-notify-plugin",
            level: "error",
            message: "Unexpected error while sending Telegram message.",
            extra: policy.debugError ? { error: String(error), eventType, sessionId } : undefined,
          },
        })
      }
    },

    event: async ({ event }) => {
      if (!event?.type) return

      const sessionId = getSessionId(event)

      if (event.type === "session.created") {
        markSessionStart(sessionId)
        return
      }

      let eventType = event.type
      if (event.type === "session.status") {
        if (event?.properties?.status?.type !== "idle") {
          markSessionStart(sessionId)
          return
        }
        eventType = "session.idle"
      }

      if (eventType !== "session.idle" && eventType !== "session.error") {
        markSessionStart(sessionId)
        return
      }

      markSessionStart(sessionId)

      const runtimeState = await loadState()
      const policy = resolvePolicy(runtimeState)
      const durationSeconds = getSessionDurationSeconds(sessionId)

      if (!policy.enabled) {
        sessionStartById.delete(sessionId)
        return
      }
      if (eventType === "session.idle" && !policy.idle) {
        sessionStartById.delete(sessionId)
        return
      }
      if (eventType === "session.error" && !policy.error) {
        sessionStartById.delete(sessionId)
        return
      }
      if (durationSeconds < policy.minSessionSeconds) {
        sessionStartById.delete(sessionId)
        return
      }

      if (!shouldSend(eventType, sessionId)) {
        sessionStartById.delete(sessionId)
        return
      }

      const projectName = getProjectName()
      const cwd = getDirectoryName()
      const label = eventType === "session.error" ? "error" : "completed"
      const lines = [
        "OpenCode: session finished",
        `Project: ${projectName}`,
        `Status: ${label}`,
        `Session: ${sessionId}`,
        `Duration: ${durationSeconds}s`,
        `Directory: ${cwd}`,
      ]

      const tokenInfo = await getSessionTokenInfo(sessionId)
      const agentInfo = await getSessionAgentInfo(sessionId)

      if (agentInfo) {
        lines.push(`Agent: ${agentInfo.name} (${agentInfo.mode})`)
      }
      if (tokenInfo) {
        lines.push(`Tokens: ${formatTokens(tokenInfo)}`)
      }

      const text = lines.join("\n")

      try {
        const result = await sendTelegram(text)
        if (!result.ok) {
          const lastError = {
            at: new Date().toISOString(),
            scope: "event-send",
             eventType,
            sessionId,
            message:
              result.reason === "http-error"
                ? "HTTP failure while sending Telegram notification."
                : "Missing Telegram environment variables.",
            status: result.status,
            body: result.body,
            details: result.details,
          }

          await saveState({
            ...(runtimeState || {}),
            enabled: policy.enabled,
            idle: policy.idle,
            error: policy.error,
            question: policy.question,
            debugError: policy.debugError,
            minSessionSeconds: policy.minSessionSeconds,
            lastError,
          })

          await client.app.log({
            body: {
              service: "telegram-notify-plugin",
              level: "error",
              message:
                result.reason === "http-error"
                  ? `Failed to send Telegram message (${result.status}).`
                  : "Telegram variables are missing.",
              extra: policy.debugError
                ? {
                    eventType,
                    sessionId,
                    status: result.status,
                    body: result.body,
                    details: result.details,
                  }
                : undefined,
            },
          })
        }
      } catch (error) {
        const lastError = {
          at: new Date().toISOString(),
          scope: "event-send",
           eventType,
          sessionId,
          message: "Unexpected error while sending Telegram notification.",
          error: String(error),
        }

        await saveState({
          ...(runtimeState || {}),
          enabled: policy.enabled,
          idle: policy.idle,
          error: policy.error,
          question: policy.question,
          debugError: policy.debugError,
          minSessionSeconds: policy.minSessionSeconds,
          lastError,
        })

        await client.app.log({
          body: {
            service: "telegram-notify-plugin",
            level: "error",
            message: "Unexpected error while sending Telegram message.",
            extra: policy.debugError ? { error: String(error), eventType, sessionId } : undefined,
          },
        })
      } finally {
        sessionStartById.delete(sessionId)
      }
    },
  }
}

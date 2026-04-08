import fs from "node:fs";
import path from "node:path";

export const BIDI_URL_ENV = "CRATER_BIDI_URL";
export const BIDI_URL_FILE_NAME = ".bidi-ws-url";
export const DEFAULT_BIDI_HTTP_URL = "http://127.0.0.1:9222/";
export const DEFAULT_BIDI_WS_URL = "ws://127.0.0.1:9222";

type FetchLike = typeof fetch;
type ReadFileSyncLike = (path: string, encoding: BufferEncoding) => string;

export interface ResolveBidiUrlOptions {
  cwd?: string;
  env?: NodeJS.ProcessEnv;
  statusTimeoutMs?: number;
  statusUrl?: string;
  fetchImpl?: FetchLike;
  readFileSync?: ReadFileSyncLike;
}

interface BidiStatusPayload {
  ready?: boolean;
  webSocketUrl?: string;
}

function isWebSocketUrl(value: string | undefined): value is string {
  return typeof value === "string" && /^(ws|wss):\/\//.test(value);
}

export function readBidiUrlFile(options: ResolveBidiUrlOptions = {}): string | null {
  const cwd = options.cwd ?? process.cwd();
  const readFileSync = options.readFileSync ?? fs.readFileSync.bind(fs);
  const filePath = path.join(cwd, BIDI_URL_FILE_NAME);
  try {
    const value = readFileSync(filePath, "utf-8").trim();
    return isWebSocketUrl(value) ? value : null;
  } catch {
    return null;
  }
}

export async function fetchBidiUrlFromStatus(
  options: ResolveBidiUrlOptions = {},
): Promise<string | null> {
  const fetchImpl = options.fetchImpl ?? globalThis.fetch;
  if (typeof fetchImpl !== "function") {
    return null;
  }

  const controller = typeof AbortController === "function" ? new AbortController() : null;
  const timeoutMs = options.statusTimeoutMs ?? 1000;
  const timer = controller
    ? setTimeout(() => controller.abort(), timeoutMs)
    : null;

  try {
    const response = await fetchImpl(options.statusUrl ?? DEFAULT_BIDI_HTTP_URL, {
      headers: { accept: "application/json" },
      signal: controller?.signal,
    });
    if (!response.ok) {
      return null;
    }

    const payload = await response.json() as BidiStatusPayload;
    if (isWebSocketUrl(payload.webSocketUrl)) {
      return payload.webSocketUrl;
    }
    if (payload.ready === true) {
      return DEFAULT_BIDI_WS_URL;
    }
    return null;
  } catch {
    return null;
  } finally {
    if (timer) {
      clearTimeout(timer);
    }
  }
}

export async function resolveBidiUrl(
  options: ResolveBidiUrlOptions = {},
): Promise<string> {
  const env = options.env ?? process.env;
  const envUrl = env[BIDI_URL_ENV];
  if (isWebSocketUrl(envUrl)) {
    return envUrl;
  }

  const statusUrl = await fetchBidiUrlFromStatus(options);
  if (statusUrl) {
    return statusUrl;
  }

  const fileUrl = readBidiUrlFile(options);
  if (fileUrl) {
    return fileUrl;
  }

  return DEFAULT_BIDI_WS_URL;
}

import fs from "node:fs";
import path from "node:path";
import {
  findMatchingQuarantine,
  parseFlakerQuarantine,
  type FlakerQuarantineConfig,
} from "../../scripts/flaker-quarantine.ts";

const QUARANTINE_PATH = path.join(process.cwd(), "flaker-quarantine.json");

let cachedQuarantine: FlakerQuarantineConfig | null = null;

function loadFlakerQuarantine(): FlakerQuarantineConfig {
  if (cachedQuarantine) {
    return cachedQuarantine;
  }
  cachedQuarantine = parseFlakerQuarantine(fs.readFileSync(QUARANTINE_PATH, "utf8"));
  return cachedQuarantine;
}

export function formatQuarantineSkipMessage(
  match: { taskId: string; spec: string; title: string },
  fallbackMessage: string,
): string {
  const entry = findMatchingQuarantine(loadFlakerQuarantine(), match);
  if (!entry) {
    return fallbackMessage;
  }
  return `${fallbackMessage} [quarantine:${entry.id}; owner=${entry.owner}; expires=${entry.expiresAt}]`;
}

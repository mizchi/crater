import fs from "fs";
import path from "path";

export interface WptConfig {
  modules: string[];
  includePrefixes: string[];
  recursiveModules?: string[];
  modulePrefixes?: Record<string, string[]>;
}

function stripJsonComments(input: string): string {
  let out = "";
  let i = 0;
  let inString = false;
  let quote = '"';
  let escaping = false;

  while (i < input.length) {
    const ch = input[i];
    const next = i + 1 < input.length ? input[i + 1] : "";

    if (inString) {
      out += ch;
      if (escaping) {
        escaping = false;
      } else if (ch == "\\") {
        escaping = true;
      } else if (ch == quote) {
        inString = false;
      }
      i += 1;
      continue;
    }

    if (ch == '"' || ch == "'") {
      inString = true;
      quote = ch;
      out += ch;
      i += 1;
      continue;
    }

    if (ch == "/" && next == "/") {
      i += 2;
      while (i < input.length && input[i] != "\n") {
        i += 1;
      }
      continue;
    }

    if (ch == "/" && next == "*") {
      i += 2;
      while (i + 1 < input.length && !(input[i] == "*" && input[i + 1] == "/")) {
        i += 1;
      }
      i = i + 1 < input.length ? i + 2 : input.length;
      continue;
    }

    out += ch;
    i += 1;
  }

  return out;
}

export function loadWptConfigFromText(raw: string): WptConfig {
  return JSON.parse(stripJsonComments(raw)) as WptConfig;
}

export function loadWptConfig(configPath?: string): WptConfig {
  const resolvedPath = configPath ?? path.join(process.cwd(), "wpt.json");
  const raw = fs.readFileSync(resolvedPath, "utf-8");
  return loadWptConfigFromText(raw);
}

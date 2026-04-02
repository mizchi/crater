import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export interface ScriptOutputFile {
  path: string;
  content: string;
}

export interface ScriptExecutionResult {
  exitCode: number;
  stdout?: string;
  stderr?: string;
  writes?: ScriptOutputFile[];
}

export function writeOutput(targetPath: string, content: string): void {
  fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  fs.writeFileSync(targetPath, content, "utf8");
}

export function appendReportWrites(
  writes: ScriptOutputFile[],
  options: {
    cwd: string;
    markdownPath?: string;
    markdownContent?: string;
    jsonPath?: string;
    jsonValue?: unknown;
  },
): void {
  if (options.markdownPath && options.markdownContent !== undefined) {
    writes.push({
      path: path.resolve(options.cwd, options.markdownPath),
      content: options.markdownContent,
    });
  }
  if (options.jsonPath && options.jsonValue !== undefined) {
    writes.push({
      path: path.resolve(options.cwd, options.jsonPath),
      content: `${JSON.stringify(options.jsonValue, null, 2)}\n`,
    });
  }
}

export function isMainModule(
  importMetaUrl: string,
  argv1: string | undefined = process.argv[1],
): boolean {
  if (!importMetaUrl.startsWith("file:")) {
    return false;
  }
  return argv1 === fileURLToPath(importMetaUrl);
}

export function emitScriptExecutionResult(
  result: ScriptExecutionResult,
  options?: {
    stdoutWrite?: (content: string) => void;
    stderrWrite?: (content: string) => void;
    exit?: (code: number) => void;
  },
): void {
  const stdoutWrite = options?.stdoutWrite ?? ((content: string) => process.stdout.write(content));
  const stderrWrite = options?.stderrWrite ?? ((content: string) => process.stderr.write(content));
  const exit = options?.exit ?? ((code: number) => process.exit(code));

  if (result.stdout) {
    stdoutWrite(result.stdout);
  }
  if (result.stderr) {
    stderrWrite(result.stderr);
  }
  for (const output of result.writes ?? []) {
    writeOutput(output.path, output.content);
  }
  exit(result.exitCode);
}

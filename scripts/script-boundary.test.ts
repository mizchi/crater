import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";

const SCRIPT_DIR = path.dirname(new URL(import.meta.url).pathname);

const PURE_MODULES = [
  "playwright-report-contract.ts",
  "playwright-report-summary-core.ts",
  "playwright-report-diff-core.ts",
  "flaker-batch-summary-core.ts",
  "flaker-batch-plan-core.ts",
  "flaker-config-contract.ts",
  "flaker-config-summary-core.ts",
  "flaker-config-selection-core.ts",
  "flaker-quarantine-contract.ts",
  "flaker-quarantine-summary-core.ts",
  "flaker-task-summary-contract.ts",
  "flaker-task-summary-core.ts",
  "flaker-collected-summary-paths.ts",
  "vrt-report-contract.ts",
  "vrt-report-summary-core.ts",
  "wpt-vrt-summary-core.ts",
] as const;

const FORBIDDEN_WRAPPER_IMPORTS = [
  './playwright-report-summary.ts',
  './playwright-report-diff.ts',
  './flaker-batch-summary.ts',
  './flaker-config.ts',
  './flaker-quarantine.ts',
  './wpt-vrt-summary.ts',
  './flaker-task-summary.ts',
  './vrt-report-summary.ts',
] as const;

const ADAPTER_MODULES = [
  "flaker-batch-plan.ts",
  "flaker-quarantine-summary.ts",
  "flaker-quarantine.ts",
  "flaker-task-config.ts",
  "flaker-task-record-execution.ts",
  "flaker-task-record-plan.ts",
  "flaker-task-record.ts",
  "flaker-task-runtime.ts",
] as const;

describe("script boundaries", () => {
  it("keeps core/contract modules independent from CLI wrappers", () => {
    for (const fileName of PURE_MODULES) {
      const source = fs.readFileSync(path.join(SCRIPT_DIR, fileName), "utf8");
      for (const forbidden of FORBIDDEN_WRAPPER_IMPORTS) {
        expect(source, `${fileName} should not import ${forbidden}`).not.toContain(forbidden);
      }
    }
  });

  it("keeps adapters on parser/contract modules instead of flaker-config facade", () => {
    for (const fileName of ADAPTER_MODULES) {
      const source = fs.readFileSync(path.join(SCRIPT_DIR, fileName), "utf8");
      expect(source, `${fileName} should not import ./flaker-config.ts`).not.toContain(
        './flaker-config.ts',
      );
    }
  });
});

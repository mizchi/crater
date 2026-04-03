import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  listFlakerCliCandidates,
  resolveFlakerCliPath,
} from "./flaker-cli-path.ts";

describe("listFlakerCliCandidates", () => {
  it("prefers explicit metric-ci paths, then installed package, then legacy flaker roots", () => {
    const repoRoot = "/tmp/crater";
    const candidates = listFlakerCliCandidates(repoRoot, {
      METRIC_CI_CLI_PATH: "./custom/metric-ci-cli.ts",
      METRIC_CI_ROOT: "../metric-ci-sidecar",
      FLAKER_ROOT: "../sidecar-flaker",
    });

    expect(candidates).toEqual([
      path.join(repoRoot, "custom", "metric-ci-cli.ts"),
      "/tmp/metric-ci-sidecar/dist/cli/main.js",
      "/tmp/metric-ci-sidecar/src/cli/main.ts",
      "/tmp/sidecar-flaker/dist/cli/main.js",
      "/tmp/sidecar-flaker/src/cli/main.ts",
      path.join(repoRoot, "node_modules", "@mizchi", "flaker", "dist", "cli", "main.js"),
      "/tmp/metric-ci/dist/cli/main.js",
      "/tmp/metric-ci/src/cli/main.ts",
      path.join(repoRoot, "metric-ci", "dist", "cli", "main.js"),
      path.join(repoRoot, "metric-ci", "src", "cli", "main.ts"),
      path.join(repoRoot, "flaker", "dist/cli/main.js"),
      path.join(repoRoot, "flaker", "src/cli/main.ts"),
      "/tmp/flaker/dist/cli/main.js",
      "/tmp/flaker/src/cli/main.ts",
    ]);
  });
});

describe("resolveFlakerCliPath", () => {
  it("returns the first existing candidate", () => {
    const repoRoot = "/tmp/crater";
    const resolved = resolveFlakerCliPath(repoRoot, {
      env: { METRIC_CI_ROOT: "../metric-ci-sidecar" },
      exists: (candidate) => candidate.endsWith("/src/cli/main.ts"),
    });

    expect(resolved).toBe("/tmp/metric-ci-sidecar/src/cli/main.ts");
  });
});

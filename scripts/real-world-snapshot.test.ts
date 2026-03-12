import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import {
  buildGithubMizchiSnapshot,
  inlineHtmlSnapshot,
  listRealWorldSnapshotNames,
  loadRealWorldSnapshot,
} from "./real-world-snapshot.ts";

const tempDirs: string[] = [];

afterEach(() => {
  for (const dir of tempDirs.splice(0)) {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

function makeTempRealWorldDir(): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "crater-realworld-"));
  tempDirs.push(dir);
  return dir;
}

describe("inlineHtmlSnapshot", () => {
  it("strips scripts and stylesheet links while inlining styles", () => {
    const html = `<!DOCTYPE html><html><head>
      <link rel="stylesheet" href="https://example.com/a.css">
      <script>window.bad = true;</script>
      <meta charset="utf-8">
    </head><body><h1>Hello</h1></body></html>`;

    const snapshot = inlineHtmlSnapshot({
      html,
      styles: ["body{color:red}", "h1{font-size:24px}"],
      baseHref: "https://example.com/page",
    });

    expect(snapshot).not.toContain("<script");
    expect(snapshot).not.toContain("rel=\"stylesheet\"");
    expect(snapshot).toContain("<style data-real-world-style=\"1\"");
    expect(snapshot).toContain("<style data-real-world-style=\"2\"");
    expect(snapshot).toContain("<base href=\"https://example.com/page\"");
    expect(snapshot).toContain("<h1>Hello</h1>");
  });
});

describe("buildGithubMizchiSnapshot", () => {
  it("builds a self-contained builtin snapshot", () => {
    const snapshot = buildGithubMizchiSnapshot();

    expect(snapshot.name).toBe("github-mizchi");
    expect(snapshot.viewport.width).toBeGreaterThan(1000);
    expect(snapshot.html).not.toContain("<script");
    expect(snapshot.html).not.toContain("rel=\"stylesheet\"");
    expect(snapshot.html).toContain("<style data-real-world-style=\"1\"");
    expect(snapshot.html).toContain("GitHub");
  });
});

describe("local real-world catalog", () => {
  it("lists and loads local snapshots from real-world directory", () => {
    const realWorldDir = makeTempRealWorldDir();
    const siteDir = path.join(realWorldDir, "sample-site");
    fs.mkdirSync(siteDir, { recursive: true });
    fs.writeFileSync(
      path.join(siteDir, "index.html"),
      "<!DOCTYPE html><html><head><title>Sample</title></head><body><main>ok</main></body></html>",
      "utf8",
    );
    fs.writeFileSync(
      path.join(siteDir, "meta.json"),
      JSON.stringify({
        title: "Sample Site",
        sourceUrl: "https://example.com/sample",
        viewport: { width: 1280, height: 720 },
      }),
      "utf8",
    );

    const names = listRealWorldSnapshotNames({ realWorldDir });
    expect(names).toContain("github-mizchi");
    expect(names).toContain("sample-site");

    const snapshot = loadRealWorldSnapshot("sample-site", { realWorldDir });
    expect(snapshot.title).toBe("Sample Site");
    expect(snapshot.sourceUrl).toBe("https://example.com/sample");
    expect(snapshot.viewport).toEqual({ width: 1280, height: 720 });
    expect(snapshot.html).toContain("<main>ok</main>");
  });
});

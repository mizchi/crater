import { test, expect } from "@playwright/test";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import path from "node:path";
import { CraterBidiPage } from "../webdriver/playwright/adapter.ts";

test("installed Preact renders, handles events and reconciles in Crater", async () => {
  const directory = mkdtempSync(path.join(tmpdir(), "crater-preact-package-"));
  const page = new CraterBidiPage();
  try {
    const output = path.join(directory, "preact.js");
    execFileSync(process.execPath, [
      path.resolve(import.meta.dirname, "../browser/scripts/run-rolldown.mjs"),
      createRequire(import.meta.url).resolve("preact"),
      "--format=iife",
      "--name=__CraterPreact",
      `--file=${output}`,
    ], { stdio: "pipe" });

    await page.connect();
    await page.setContent('<div id="root"></div>');
    await page.evaluate(`${readFileSync(output, "utf8")}\nglobalThis.__installedPreact = __CraterPreact;`);
    const result = await page.evaluate(() => {
      const { h, render } = (globalThis as any).__installedPreact;
      const container = document.getElementById("root")!;
      let clicks = 0;
      render(h("button", { id: "preact-button", onClick: () => clicks++ }, "first"), container);
      document.getElementById("preact-button")!.click();
      render(h("button", { id: "preact-button" }, "updated"), container);
      return { text: container.textContent, clicks, children: container.childNodes.length };
    });
    expect(result).toEqual({ text: "updated", clicks: 1, children: 1 });
  } finally {
    await page.close();
    rmSync(directory, { recursive: true, force: true });
  }
});

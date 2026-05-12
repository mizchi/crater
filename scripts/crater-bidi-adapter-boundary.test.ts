import fs from "fs";
import path from "path";
import { describe, expect, it } from "vitest";

function readScript(relativePath: string): string {
  return fs.readFileSync(path.join(process.cwd(), relativePath), "utf-8");
}

describe("crater_bidi_adapter module boundary", () => {
  it("keeps WebDriver BiDi module proxies outside the pytest adapter", () => {
    const adapter = readScript("scripts/crater_bidi_adapter.py");
    const modules = readScript("scripts/crater_bidi_modules.py");

    for (const className of [
      "BrowsingContextModule",
      "SessionModule",
      "ScriptModule",
      "NetworkModule",
      "StorageModule",
      "InputModule",
      "BrowserModule",
      "EmulationModule",
      "PermissionsModule",
      "BluetoothModule",
      "WebExtensionModule",
    ]) {
      expect(adapter).not.toContain(`class ${className}`);
      expect(modules).toContain(`class ${className}`);
    }
  });

  it("keeps the Python adapter as pytest glue instead of protocol implementation", () => {
    const adapter = readScript("scripts/crater_bidi_adapter.py");
    const lineCount = adapter.split("\n").length;

    expect(lineCount).toBeLessThanOrEqual(1800);
    expect(adapter).toContain("from scripts.crater_bidi_modules import");
  });
});

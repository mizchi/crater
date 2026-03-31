import path from "node:path";
import { describe, expect, it } from "vitest";
import { prepareHtmlContent } from "./wpt-html-utils.ts";

describe("prepareHtmlContent", () => {
  it("inlines linked Ahem stylesheets with embedded font data", () => {
    const html = prepareHtmlContent(
      path.join(process.cwd(), "wpt/css/css-flexbox/flexbox-whitespace-handling-002.xhtml"),
    );

    expect(html).toContain("@font-face");
    expect(html).toContain("font-family: 'Ahem'");
    expect(html).toContain("data:font/ttf;base64,");
    expect(html).not.toContain('href="/fonts/ahem.css"');
    expect(html).not.toContain("url('/fonts/Ahem.ttf')");
  });

  it("inlines Ahem imports inside style blocks", () => {
    const html = prepareHtmlContent(
      path.join(process.cwd(), "wpt/css/css-flexbox/flex-container-min-content-001.html"),
    );

    expect(html).toContain("@font-face");
    expect(html).toContain("data:font/ttf;base64,");
    expect(html).not.toMatch(/@import\s+["']\/fonts\/ahem\.css["']/);
  });
});

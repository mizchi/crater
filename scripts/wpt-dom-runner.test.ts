import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { buildFixtureCode, buildInterleavedFixtureCode } from "./wpt-dom-runner.ts";

const tempDirs: string[] = [];

afterEach(() => {
  for (const dir of tempDirs.splice(0)) {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

function writeFixture(html: string): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "wpt-dom-runner-"));
  tempDirs.push(dir);
  const file = path.join(dir, "fixture.html");
  fs.writeFileSync(file, html, "utf8");
  return file;
}

describe("buildFixtureCode", () => {
  it("preserves svg title elements inside svg content", () => {
    const file = writeFixture(`
<!DOCTYPE html>
<body>
  <svg>
    <title>Inside SVG</title>
  </svg>
</body>`);

    const code = buildFixtureCode(file);

    expect(code).toContain('"tag":"title"');
  });

  it("still skips html head title elements", () => {
    const file = writeFixture(`
<!DOCTYPE html>
<html>
  <head><title>Head Title</title></head>
  <body><div id="app"></div></body>
</html>`);

    const code = buildFixtureCode(file);

    expect(code).not.toContain('"tag":"title"');
    expect(code).toContain('"tag":"div"');
  });

  it("treats processing-instruction-like tokens as comment character data", () => {
    const file = writeFixture(`
<!DOCTYPE html>
<body><p><?processing data?></p></body>`);

    const code = buildFixtureCode(file);

    expect(code).toContain('"type":"comment"');
    expect(code).toContain('?processing data?');
  });
});

describe("buildInterleavedFixtureCode", () => {
  it("keeps inline scripts interleaved with later parser insertions", () => {
    const file = writeFixture(`
<!DOCTYPE html>
<body>
  <script>window.order = ["script"];</script>
  <p id="after-script"></p>
</body>`);

    const code = buildInterleavedFixtureCode(file);

    expect(code).toContain('(0, eval)(');
    expect(code.indexOf('window.order = ["script"]')).toBeLessThan(
      code.indexOf('"after-script"'),
    );
  });
});

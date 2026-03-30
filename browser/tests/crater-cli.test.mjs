import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync, spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const testFile = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(testFile), "..");
const distCraterPath = path.join(repoRoot, "dist", "crater.js");

function makeFixtureDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "crater-cli-"));
}

function writeFixture(dir, name, content) {
  const filePath = path.join(dir, name);
  fs.writeFileSync(filePath, content, "utf8");
  return filePath;
}

function runCrater(args, options = {}) {
  return spawnSync(process.execPath, [distCraterPath, ...args], {
    cwd: repoRoot,
    encoding: "utf8",
    ...options,
  });
}

test.before(() => {
  execFileSync("npm", ["run", "build:moon"], {
    cwd: repoRoot,
    stdio: "pipe",
    encoding: "utf8",
  });
  execFileSync("npm", ["run", "build:minify:crater"], {
    cwd: repoRoot,
    stdio: "pipe",
    encoding: "utf8",
  });
});

test("dist crater help explains input model and artifacts", () => {
  const result = runCrater(["--help"]);
  assert.equal(result.status, 0);
  assert.match(result.stdout, /INPUT MODEL:/);
  assert.match(result.stdout, /OUTPUT CONTRACT:/);
  assert.match(result.stdout, /ARTIFACTS:/);
  assert.match(result.stdout, /--target-selector/);
  assert.match(result.stdout, /--stdin-html/);
  assert.match(result.stdout, /--stdin-css/);
  assert.match(result.stdout, /--output-file/);
  assert.match(result.stdout, /Selector targets are normalized to the resolved DOM id in targetId\./);
  assert.match(result.stdout, /layout\s+Layout JSON/);
  assert.match(result.stdout, /image\s+PNG base64 JSON/);
  assert.match(result.stdout, /landmarks\s+Accessibility landmark tree JSON/);
});

test("dist crater emits landmark schema envelope", () => {
  const dir = makeFixtureDir();
  const htmlPath = writeFixture(
    dir,
    "fixture.html",
    `<!DOCTYPE html>
<html>
  <body>
    <div id="noise">ignore me</div>
    <section id="card-root" role="region" aria-label="Billing Card">
      <nav aria-label="Card Nav"><a href="/">Home</a></nav>
      <footer role="contentinfo" aria-label="Card Actions"><button>Open</button></footer>
    </section>
  </body>
</html>`,
  );
  const result = runCrater([
    "--html-file",
    htmlPath,
    "--target-id",
    "card-root",
    "--artifact",
    "landmarks",
  ]);
  assert.equal(result.status, 0);
  const output = JSON.parse(result.stdout);
  assert.equal(output.schemaVersion, 1);
  assert.equal(output.artifact, "landmarks");
  assert.equal(output.targetId, "card-root");
  assert.deepEqual(output.viewport, { width: 1280, height: 720 });
  assert.equal(output.data[0].role, "region");
  assert.equal(output.data[0].children[0].role, "navigation");
  assert.equal(output.data[0].children[1].role, "contentinfo");
});

test("dist crater emits image schema envelope with png encoding metadata", () => {
  const dir = makeFixtureDir();
  const htmlPath = writeFixture(
    dir,
    "fixture.html",
    `<!DOCTYPE html>
<html>
  <body>
    <div id="noise" style="width: 300px; height: 50px;">ignore me</div>
    <div id="card-root" style="width: 120px; height: 40px; background: #ff0000;"></div>
  </body>
</html>`,
  );
  const result = runCrater([
    "--html-file",
    htmlPath,
    "--target-id",
    "card-root",
    "--artifact",
    "image",
  ]);
  assert.equal(result.status, 0);
  const output = JSON.parse(result.stdout);
  assert.equal(output.schemaVersion, 1);
  assert.equal(output.artifact, "image");
  assert.equal(output.targetId, "card-root");
  assert.equal(output.encoding, "png-base64");
  assert.equal(output.width, 120);
  assert.equal(output.height, 40);
  assert.match(output.data, /^iVBORw0KGgo/);
  assert.ok(typeof output.data === "string" && output.data.length > 0);
});

test("dist crater resolves target selector to the matched component", () => {
  const dir = makeFixtureDir();
  const htmlPath = writeFixture(
    dir,
    "fixture.html",
    `<!DOCTYPE html>
<html>
  <body>
    <div class="noise"></div>
    <section id="card-root" class="card primary" role="region" aria-label="Billing Card">
      <nav aria-label="Card Nav"><a href="/">Home</a></nav>
    </section>
  </body>
</html>`,
  );
  const result = runCrater([
    "--html-file",
    htmlPath,
    "--target-selector",
    ".card.primary",
    "--artifact",
    "landmarks",
  ]);
  assert.equal(result.status, 0);
  const output = JSON.parse(result.stdout);
  assert.equal(output.artifact, "landmarks");
  assert.equal(output.targetId, "card-root");
  assert.equal(output.data[0].role, "region");
  assert.equal(output.data[0].children[0].role, "navigation");
});

test("dist crater exits non-zero when target is missing", () => {
  const dir = makeFixtureDir();
  const htmlPath = writeFixture(
    dir,
    "fixture.html",
    "<!DOCTYPE html><html><body><div id=\"other\"></div></body></html>",
  );
  const result = runCrater([
    "--html-file",
    htmlPath,
    "--target-id",
    "card-root",
  ]);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /Target element not found: #card-root/);
});

test("dist crater exits non-zero when both target-id and target-selector are given", () => {
  const dir = makeFixtureDir();
  const htmlPath = writeFixture(
    dir,
    "fixture.html",
    "<!DOCTYPE html><html><body><div id=\"card-root\" class=\"card\"></div></body></html>",
  );
  const result = runCrater([
    "--html-file",
    htmlPath,
    "--target-id",
    "card-root",
    "--target-selector",
    ".card",
  ]);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /Choose either --target-id or --target-selector/);
});

test("dist crater reads html from stdin", () => {
  const result = runCrater(
    ["--stdin-html", "--target-id", "card-root", "--artifact", "landmarks"],
    {
      input: `<!DOCTYPE html>
<html>
  <body>
    <section id="card-root" role="region" aria-label="Billing Card"></section>
  </body>
</html>`,
    },
  );
  assert.equal(result.status, 0);
  const output = JSON.parse(result.stdout);
  assert.equal(output.artifact, "landmarks");
  assert.equal(output.targetId, "card-root");
  assert.equal(output.data[0].role, "region");
});

test("dist crater reads css from stdin", () => {
  const dir = makeFixtureDir();
  const htmlPath = writeFixture(
    dir,
    "fixture.html",
    `<!DOCTYPE html>
<html>
  <body>
    <div id="card-root"></div>
  </body>
</html>`,
  );
  const result = runCrater(
    [
      "--html-file",
      htmlPath,
      "--stdin-css",
      "--target-id",
      "card-root",
      "--artifact",
      "layout",
    ],
    {
      input: "#card-root { width: 210px; height: 44px; }",
    },
  );
  assert.equal(result.status, 0);
  const output = JSON.parse(result.stdout);
  assert.equal(output.artifact, "layout");
  assert.equal(output.data.width, 210);
  assert.equal(output.data.height, 44);
});

test("dist crater writes artifact to output file", () => {
  const dir = makeFixtureDir();
  const htmlPath = writeFixture(
    dir,
    "fixture.html",
    `<!DOCTYPE html>
<html>
  <body>
    <section id="card-root" role="region" aria-label="Billing Card"></section>
  </body>
</html>`,
  );
  const outputPath = path.join(dir, "artifact.json");
  const result = runCrater([
    "--html-file",
    htmlPath,
    "--target-id",
    "card-root",
    "--output-file",
    outputPath,
  ]);
  assert.equal(result.status, 0);
  assert.equal(result.stdout, "");
  const output = JSON.parse(fs.readFileSync(outputPath, "utf8"));
  assert.equal(output.artifact, "landmarks");
  assert.equal(output.targetId, "card-root");
});

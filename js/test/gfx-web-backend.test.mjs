// The gfx web backend (WebGPU/WebGL stub driver -> set_web_graphics_hooks ->
// JS runtime) must render crater's command stream to the same pixels as the
// software backend. This exercises the exact seam a real WebGPU device plugs
// into, using the CPU runtime so it runs without a GPU.
import { strict as assert } from "node:assert";
import { test } from "node:test";

import { installDefaultRuntime } from "../gfx-web-runtime.mjs";
import {
  renderHtmlViaWebBackendRgba,
  renderHtmlToImageRgba,
} from "../dist/index.js";

const FIXTURES = [
  {
    name: "stacked blocks",
    w: 8,
    h: 8,
    html: `<html><body style="margin:0"><div style="width:8px;height:4px;background:#000"></div><div style="width:8px;height:4px;background:#888"></div></body></html>`,
  },
  {
    name: "rounded box",
    w: 12,
    h: 12,
    html: `<html><body style="margin:0;background:#fff"><div style="width:12px;height:12px;background:#000;border-radius:4px"></div></body></html>`,
  },
];

test("web backend matches the software backend pixel-for-pixel", () => {
  installDefaultRuntime();
  for (const fx of FIXTURES) {
    const web = renderHtmlViaWebBackendRgba(fx.html, fx.w, fx.h);
    const soft = renderHtmlToImageRgba(fx.html, fx.w, fx.h);
    assert.equal(web.length, soft.length, `${fx.name}: length`);
    assert.deepEqual(web, soft, `${fx.name}: pixels differ`);
  }
});

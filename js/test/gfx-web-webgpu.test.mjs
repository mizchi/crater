// Verify the WebGPU backend translates crater's command stream into the
// right WebGPU operations (pipeline, per-command draw, uniform layout,
// scissor, async readback). Uses a mock GPUDevice so it runs without a GPU;
// a real device renders the same calls.
import { strict as assert } from "node:assert";
import { test } from "node:test";

import { WebGPUBackend } from "../gfx-web-runtime.mjs";

function mockDevice() {
  const rec = { pipelines: 0, draws: [], clears: [], scissors: [], writes: [], submits: 0, copies: 0 };
  const pass = {
    setPipeline() {},
    setVertexBuffer() {},
    setIndexBuffer() {},
    setBindGroup() {},
    setScissorRect(x, y, w, h) { rec.scissors.push([x, y, w, h]); },
    drawIndexed(n) { rec.draws.push(n); },
    end() {},
  };
  const encoder = {
    beginRenderPass(desc) { rec.clears.push(desc.colorAttachments[0].clearValue); return pass; },
    copyTextureToBuffer() { rec.copies++; },
    finish() { return {}; },
  };
  const device = {
    createShaderModule: () => ({}),
    createBindGroupLayout: () => ({}),
    createPipelineLayout: () => ({}),
    createRenderPipeline: () => { rec.pipelines++; return {}; },
    createTexture: () => ({ createView: () => ({}) }),
    createBuffer: (d) => ({
      _size: d.size,
      _usage: d.usage,
      async mapAsync() {},
      getMappedRange() { return new Uint8Array(d.size).buffer; },
      unmap() {},
    }),
    createBindGroup: () => ({}),
    createCommandEncoder: () => encoder,
    queue: {
      writeBuffer(buf, _off, data) { rec.writes.push({ size: buf._size, usage: buf._usage, data }); },
      submit() { rec.submits++; },
    },
  };
  return { device, rec };
}

const QUAD = [-1, 1, 0, 0, 1, 1, 1, 0, 1, -1, 1, 1, -1, -1, 0, 1];
const IDX = [0, 1, 2, 2, 3, 0];

test("WebGPU backend translates commands to GPU operations", () => {
  const { device, rec } = mockDevice();
  const be = new WebGPUBackend(device, "rgba8unorm");
  be.init(4, 4);
  assert.equal(rec.pipelines, 1, "pipeline created once");

  be.begin([255, 255, 255, 255]);
  assert.deepEqual(rec.clears[0], { r: 1, g: 1, b: 1, a: 1 }, "clear colour");

  // plain red fill
  be.draw({ vertexData: QUAD, indices: IDX, uniforms: [255, 0, 0, 255], dstRegion: [0, 0, 4, 4] });
  // rounded fill: [r,g,b,a, rx_tl,ry_tl,rx_tr,ry_tr,rx_br,ry_br,rx_bl,ry_bl, x,y,w,h]
  be.draw({ vertexData: QUAD, indices: IDX, uniforms: [0, 0, 0, 255, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 4, 4], dstRegion: [0, 0, 4, 4] });
  be.end();

  assert.equal(rec.draws.length, 2, "one drawIndexed per command");
  assert.deepEqual(rec.draws, [6, 6], "index counts");
  assert.equal(rec.submits, 1, "submitted once");
  assert.deepEqual(rec.scissors[0], [0, 0, 4, 4], "scissor rect");

  // uniform buffers (size 80): assert colour + rounded flag
  const uniforms = rec.writes.filter((w) => (w.usage & 0x40) !== 0).map((w) => w.data);
  assert.equal(uniforms.length, 2, "two uniform writes");
  assert.deepEqual(Array.from(uniforms[0].slice(0, 4)), [1, 0, 0, 1], "red colour");
  assert.equal(uniforms[1][16], 1, "rounded flag set");
  assert.deepEqual(Array.from(uniforms[1].slice(4, 8)), [2, 2, 2, 2], "corner radii");
});

test("WebGPU backend reads pixels back asynchronously", async () => {
  const { device } = mockDevice();
  const be = new WebGPUBackend(device, "rgba8unorm");
  be.init(2, 2);
  be.begin([0, 0, 0, 255]);
  be.end();
  const pixels = await be.readPixelsAsync();
  assert.equal(pixels.length, 2 * 2 * 4, "rgba length");
});

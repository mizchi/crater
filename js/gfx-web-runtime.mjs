// crater gfx web backend host runtime.
//
// gfx's WebGPU / WebGL stub drivers forward the DrawTrianglesCommand stream
// to a globally-registered host (the `set_web_graphics_hooks` seam). This is
// that host: it renders the command stream to an RGBA framebuffer. A real
// GPU backend would submit the same commands to WebGPU; here a CPU
// rasterizer (matching gfx_software's NDC-quad + uniform conventions) makes
// the path work and be testable without a device. The WGSL below is what a
// WebGPU pipeline would use for the same uniform layout.
//
// Install with `installDefaultRuntime()`; the MoonBit gfx_web hooks call the
// `globalThis.__craterGfxWeb` object it sets.

// WGSL the WebGPU path uses: a solid / rounded-rect fill whose colour and
// shape come from the same uniforms crater packs
// ([r,g,b,a, r_tl,r_tr,r_br,r_bl, x,y,w,h]).
export const FILL_WGSL = `
struct Uniforms {
  color : vec4<f32>,
  radii : vec4<f32>,   // r_tl, r_tr, r_br, r_bl
  rect  : vec4<f32>,   // x, y, w, h (pixels)
  flags : vec4<f32>,   // flags.x: rounded (1) or plain (0)
};
@group(0) @binding(0) var<uniform> u : Uniforms;

struct VSOut { @builtin(position) pos : vec4<f32>, @location(0) frag : vec2<f32> };

@vertex
fn vs_main(@location(0) ndc : vec2<f32>, @location(1) uv : vec2<f32>) -> VSOut {
  var out : VSOut;
  out.pos = vec4<f32>(ndc, 0.0, 1.0);
  // Reconstruct the pixel-space position from the unit uv and the rect so
  // the fragment stage can test the rounded corners.
  out.frag = u.rect.xy + uv * u.rect.zw;
  return out;
}

fn corner_clip(p : vec2<f32>) -> bool {
  let x = u.rect.x; let y = u.rect.y; let w = u.rect.z; let h = u.rect.w;
  // top-left
  if (u.radii.x > 0.0 && p.x < x + u.radii.x && p.y < y + u.radii.x) {
    return distance(p, vec2<f32>(x + u.radii.x, y + u.radii.x)) > u.radii.x;
  }
  if (u.radii.y > 0.0 && p.x > x + w - u.radii.y && p.y < y + u.radii.y) {
    return distance(p, vec2<f32>(x + w - u.radii.y, y + u.radii.y)) > u.radii.y;
  }
  if (u.radii.z > 0.0 && p.x > x + w - u.radii.z && p.y > y + h - u.radii.z) {
    return distance(p, vec2<f32>(x + w - u.radii.z, y + h - u.radii.z)) > u.radii.z;
  }
  if (u.radii.w > 0.0 && p.x < x + u.radii.w && p.y > y + h - u.radii.w) {
    return distance(p, vec2<f32>(x + u.radii.w, y + h - u.radii.w)) > u.radii.w;
  }
  return false;
}

@fragment
fn fs_main(in : VSOut) -> @location(0) vec4<f32> {
  if (u.flags.x > 0.5 && corner_clip(in.frag)) { discard; }
  return u.color;
}
`;

// ---- CPU rasterizer (port of gfx_software) -------------------------------

function edge(ax, ay, bx, by, cx, cy) {
  return (cx - ax) * (by - ay) - (cy - ay) * (bx - ax);
}
function topLeft(ax, ay, bx, by) {
  const dx = bx - ax, dy = by - ay;
  return dy > 0 || (dy === 0 && dx < 0);
}

class CpuBackend {
  init(width, height) {
    this.width = width;
    this.height = height;
    this.pixels = new Int32Array(width * height * 4);
    return true;
  }
  begin(clear) {
    if (!clear) return;
    const [r, g, b, a] = clear;
    for (let i = 0; i < this.width * this.height; i++) {
      const o = i * 4;
      this.pixels[o] = r; this.pixels[o + 1] = g; this.pixels[o + 2] = b; this.pixels[o + 3] = a;
    }
  }
  end() {}
  blend(x, y, sr, sg, sb, sa, blendMode) {
    if (x < 0 || y < 0 || x >= this.width || y >= this.height) return;
    const o = (y * this.width + x) * 4;
    if (blendMode === 0) { // Copy
      this.pixels[o] = sr; this.pixels[o + 1] = sg; this.pixels[o + 2] = sb; this.pixels[o + 3] = sa;
      return;
    }
    const af = sa / 255, inv = 1 - af;
    this.pixels[o] = Math.trunc(sr * af + this.pixels[o] * inv);
    this.pixels[o + 1] = Math.trunc(sg * af + this.pixels[o + 1] * inv);
    this.pixels[o + 2] = Math.trunc(sb * af + this.pixels[o + 2] * inv);
    this.pixels[o + 3] = Math.trunc(sa + this.pixels[o + 3] * inv);
  }
  draw({ vertexData, indices, uniforms, blend, dstRegion }) {
    const sr = uniforms[0] | 0, sg = uniforms[1] | 0, sb = uniforms[2] | 0, sa = uniforms.length > 3 ? uniforms[3] | 0 : 255;
    const rounded = uniforms.length >= 12 && (uniforms[4] || uniforms[5] || uniforms[6] || uniforms[7]);
    const [rx, ry, rw, rh] = dstRegion ?? [0, 0, this.width, this.height];
    const sx0 = Math.max(0, rx), sx1 = Math.min(this.width, rx + rw) - 1;
    const sy0 = Math.max(0, ry), sy1 = Math.min(this.height, ry + rh) - 1;
    const toPx = (ndcx, ndcy) => [(ndcx + 1) * 0.5 * this.width, (1 - ndcy) * 0.5 * this.height];
    for (let t = 0; t + 2 < indices.length; t += 3) {
      const i0 = indices[t], i1 = indices[t + 1], i2 = indices[t + 2];
      let [x0, y0] = toPx(vertexData[i0 * 4], vertexData[i0 * 4 + 1]);
      let [x1, y1] = toPx(vertexData[i1 * 4], vertexData[i1 * 4 + 1]);
      let [x2, y2] = toPx(vertexData[i2 * 4], vertexData[i2 * 4 + 1]);
      const area = edge(x0, y0, x1, y1, x2, y2);
      if (area === 0) continue;
      let ax = x0, ay = y0, bx = x1, by = y1, cx = x2, cy = y2;
      if (area < 0) { bx = x2; by = y2; cx = x1; cy = y1; }
      const tl0 = topLeft(bx, by, cx, cy), tl1 = topLeft(cx, cy, ax, ay), tl2 = topLeft(ax, ay, bx, by);
      const minX = Math.max(sx0, Math.trunc(Math.min(x0, x1, x2)));
      const maxX = Math.min(sx1, Math.trunc(Math.max(x0, x1, x2)));
      const minY = Math.max(sy0, Math.trunc(Math.min(y0, y1, y2)));
      const maxY = Math.min(sy1, Math.trunc(Math.max(y0, y1, y2)));
      for (let py = minY; py <= maxY; py++) {
        for (let px = minX; px <= maxX; px++) {
          const pcx = px + 0.5, pcy = py + 0.5;
          const w0 = edge(bx, by, cx, cy, pcx, pcy);
          const w1 = edge(cx, cy, ax, ay, pcx, pcy);
          const w2 = edge(ax, ay, bx, by, pcx, pcy);
          const ok = (w) => w > 0;
          const inside =
            (w0 > 0 || (w0 === 0 && tl0)) &&
            (w1 > 0 || (w1 === 0 && tl1)) &&
            (w2 > 0 || (w2 === 0 && tl2));
          if (!inside) continue;
          if (rounded && this.#cornerClipped(pcx, pcy, uniforms)) continue;
          this.blend(px, py, sr, sg, sb, sa, blend);
        }
      }
    }
  }
  #cornerClipped(pcx, pcy, u) {
    const rtl = u[4], rtr = u[5], rbr = u[6], rbl = u[7], x = u[8], y = u[9], w = u[10], h = u[11];
    const out = (cx, cy, r) => (pcx - cx) ** 2 + (pcy - cy) ** 2 > r * r;
    if (rtl > 0 && pcx < x + rtl && pcy < y + rtl) return out(x + rtl, y + rtl, rtl);
    if (rtr > 0 && pcx > x + w - rtr && pcy < y + rtr) return out(x + w - rtr, y + rtr, rtr);
    if (rbr > 0 && pcx > x + w - rbr && pcy > y + h - rbr) return out(x + w - rbr, y + h - rbr, rbr);
    if (rbl > 0 && pcx < x + rbl && pcy > y + h - rbl) return out(x + rbl, y + h - rbl, rbl);
    return false;
  }
  readPixels() { return Array.from(this.pixels); }
}

/**
 * Install the default crater gfx web backend on globalThis. Uses a CPU
 * rasterizer. A real WebGPU backend can replace globalThis.__craterGfxWeb
 * with one that submits the same commands (see FILL_WGSL) to a GPU device.
 */
export function installDefaultRuntime() {
  if (!globalThis.__craterGfxWeb) {
    globalThis.__craterGfxWeb = new CpuBackend();
  }
  return globalThis.__craterGfxWeb;
}

// ---- WebGPU backend ------------------------------------------------------

// Build the uniform buffer bytes (64) crater's FILL_WGSL expects:
// color(vec4) | radii(vec4) | rect(vec4) | flags(vec4).
function packUniforms(uniforms) {
  const f = new Float32Array(16);
  f[0] = (uniforms[0] | 0) / 255;
  f[1] = (uniforms[1] | 0) / 255;
  f[2] = (uniforms[2] | 0) / 255;
  f[3] = (uniforms.length > 3 ? uniforms[3] | 0 : 255) / 255;
  const rounded = uniforms.length >= 12 && (uniforms[4] || uniforms[5] || uniforms[6] || uniforms[7]);
  if (rounded) {
    f[4] = uniforms[4]; f[5] = uniforms[5]; f[6] = uniforms[6]; f[7] = uniforms[7];
    f[8] = uniforms[8]; f[9] = uniforms[9]; f[10] = uniforms[10]; f[11] = uniforms[11];
    f[12] = 1;
  }
  return f;
}

/**
 * A WebGPU-backed host: submits crater's command stream to a real GPU
 * device using FILL_WGSL. Rendering/submit is synchronous-record (begin /
 * draw / end); pixel readback is asynchronous (readPixelsAsync), since
 * WebGPU buffer mapping is async. Plug it in with installWebGPURuntime(device).
 */
export class WebGPUBackend {
  constructor(device, format = "rgba8unorm") {
    this.device = device;
    this.format = format;
    this.pipeline = null;
    this.layout = null;
  }
  #ensurePipeline() {
    if (this.pipeline) return;
    const module = this.device.createShaderModule({ code: FILL_WGSL });
    this.layout = this.device.createBindGroupLayout({
      entries: [{ binding: 0, visibility: 3 /* VERTEX|FRAGMENT */, buffer: { type: "uniform" } }],
    });
    const pipelineLayout = this.device.createPipelineLayout({ bindGroupLayouts: [this.layout] });
    this.pipeline = this.device.createRenderPipeline({
      layout: pipelineLayout,
      vertex: {
        module,
        entryPoint: "vs_main",
        buffers: [{
          arrayStride: 16,
          attributes: [
            { shaderLocation: 0, offset: 0, format: "float32x2" },
            { shaderLocation: 1, offset: 8, format: "float32x2" },
          ],
        }],
      },
      fragment: {
        module,
        entryPoint: "fs_main",
        targets: [{
          format: this.format,
          blend: {
            color: { srcFactor: "src-alpha", dstFactor: "one-minus-src-alpha", operation: "add" },
            alpha: { srcFactor: "one", dstFactor: "one-minus-src-alpha", operation: "add" },
          },
        }],
      },
      primitive: { topology: "triangle-list" },
    });
  }
  init(width, height) {
    this.width = width;
    this.height = height;
    this.#ensurePipeline();
    this.target = this.device.createTexture({
      size: [width, height],
      format: this.format,
      usage: 0x10 /* RENDER_ATTACHMENT */ | 0x01 /* COPY_SRC */,
    });
    return true;
  }
  begin(clear) {
    const [r, g, b, a] = clear ?? [0, 0, 0, 255];
    this.encoder = this.device.createCommandEncoder();
    this.pass = this.encoder.beginRenderPass({
      colorAttachments: [{
        view: this.target.createView(),
        clearValue: { r: r / 255, g: g / 255, b: b / 255, a: a / 255 },
        loadOp: "clear",
        storeOp: "store",
      }],
    });
    this.pass.setPipeline(this.pipeline);
  }
  draw({ vertexData, indices, uniforms, dstRegion }) {
    const device = this.device;
    const vb = device.createBuffer({ size: vertexData.length * 4, usage: 0x20 /* VERTEX */ | 0x08 /* COPY_DST */ });
    device.queue.writeBuffer(vb, 0, new Float32Array(vertexData));
    const ib = device.createBuffer({ size: indices.length * 4, usage: 0x10 /* INDEX */ | 0x08, });
    device.queue.writeBuffer(ib, 0, new Uint32Array(indices));
    const ub = device.createBuffer({ size: 64, usage: 0x40 /* UNIFORM */ | 0x08 });
    device.queue.writeBuffer(ub, 0, packUniforms(uniforms));
    const bindGroup = device.createBindGroup({ layout: this.layout, entries: [{ binding: 0, resource: { buffer: ub } }] });
    if (dstRegion) {
      const [rx, ry, rw, rh] = dstRegion;
      const x = Math.max(0, rx), y = Math.max(0, ry);
      const w = Math.max(0, Math.min(this.width, rx + rw) - x);
      const h = Math.max(0, Math.min(this.height, ry + rh) - y);
      this.pass.setScissorRect(x, y, w, h);
    }
    this.pass.setVertexBuffer(0, vb);
    this.pass.setIndexBuffer(ib, "uint32");
    this.pass.setBindGroup(0, bindGroup);
    this.pass.drawIndexed(indices.length);
  }
  end() {
    this.pass.end();
    this.device.queue.submit([this.encoder.finish()]);
  }
  // WebGPU readback is async; the sync hook interface cannot use it.
  readPixels() { return []; }
  async readPixelsAsync() {
    const bytesPerRow = Math.ceil((this.width * 4) / 256) * 256;
    const readback = this.device.createBuffer({ size: bytesPerRow * this.height, usage: 0x01 /* MAP_READ */ | 0x08 /* COPY_DST */ });
    const enc = this.device.createCommandEncoder();
    enc.copyTextureToBuffer(
      { texture: this.target },
      { buffer: readback, bytesPerRow, rowsPerImage: this.height },
      [this.width, this.height],
    );
    this.device.queue.submit([enc.finish()]);
    await readback.mapAsync(0x01);
    const mapped = new Uint8Array(readback.getMappedRange());
    const out = new Array(this.width * this.height * 4);
    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width * 4; x++) {
        out[y * this.width * 4 + x] = mapped[y * bytesPerRow + x];
      }
    }
    readback.unmap?.();
    return out;
  }
}

/**
 * Install a WebGPU-backed host runtime that submits to `device`. The host
 * (browser / Deno / node-webgpu) provides the GPUDevice and target format.
 */
export function installWebGPURuntime(device, format = "rgba8unorm") {
  globalThis.__craterGfxWeb = new WebGPUBackend(device, format);
  return globalThis.__craterGfxWeb;
}

export { CpuBackend };

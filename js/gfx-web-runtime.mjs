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
// ([r,g,b,a, rx_tl,ry_tl, rx_tr,ry_tr, rx_br,ry_br, rx_bl,ry_bl, x,y,w,h]).
export const FILL_WGSL = `
struct Uniforms {
  color  : vec4<f32>,
  radii0 : vec4<f32>,  // rx_tl, ry_tl, rx_tr, ry_tr
  radii1 : vec4<f32>,  // rx_br, ry_br, rx_bl, ry_bl
  rect   : vec4<f32>,  // x, y, w, h (pixels)
  flags  : vec4<f32>,  // flags.x: rounded (1) or plain (0)
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

// Coverage of an axis-aligned elliptical corner centred at c with radii r;
// the signed distance to the ellipse (positive inside) is approximated as
// -f / |grad f| for f = (d/r)^2 - 1, softened over a 1px band. Reduces to the
// circular case when r.x == r.y.
fn arc_cov(p : vec2<f32>, c : vec2<f32>, r : vec2<f32>) -> f32 {
  let d = p - c;
  if (abs(r.x - r.y) < 0.001) {
    return clamp(r.x - length(d) + 0.5, 0.0, 1.0);
  }
  let n = d / r;
  let g = d / (r * r);
  let glen = 2.0 * length(g);
  if (glen < 1e-6) { return 1.0; }
  let signed_inside = (1.0 - dot(n, n)) / glen;
  return clamp(signed_inside + 0.5, 0.0, 1.0);
}

fn corner_coverage(p : vec2<f32>) -> f32 {
  let x = u.rect.x; let y = u.rect.y; let w = u.rect.z; let h = u.rect.w;
  let tl = u.radii0.xy; let tr = u.radii0.zw;
  let br = u.radii1.xy; let bl = u.radii1.zw;
  if (tl.x > 0.0 && tl.y > 0.0 && p.x < x + tl.x && p.y < y + tl.y) {
    return arc_cov(p, vec2<f32>(x + tl.x, y + tl.y), tl);
  }
  if (tr.x > 0.0 && tr.y > 0.0 && p.x > x + w - tr.x && p.y < y + tr.y) {
    return arc_cov(p, vec2<f32>(x + w - tr.x, y + tr.y), tr);
  }
  if (br.x > 0.0 && br.y > 0.0 && p.x > x + w - br.x && p.y > y + h - br.y) {
    return arc_cov(p, vec2<f32>(x + w - br.x, y + h - br.y), br);
  }
  if (bl.x > 0.0 && bl.y > 0.0 && p.x < x + bl.x && p.y > y + h - bl.y) {
    return arc_cov(p, vec2<f32>(x + bl.x, y + h - bl.y), bl);
  }
  return 1.0;
}

@fragment
fn fs_main(in : VSOut) -> @location(0) vec4<f32> {
  var cov = 1.0;
  if (u.flags.x > 0.5) { cov = corner_coverage(in.frag); }
  return vec4<f32>(u.color.rgb, u.color.a * cov);
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
    const rounded = uniforms.length >= 16 && (uniforms[4] || uniforms[5] || uniforms[6] || uniforms[7] || uniforms[8] || uniforms[9] || uniforms[10] || uniforms[11]);
    const [rx, ry, rw, rh] = dstRegion ?? [0, 0, this.width, this.height];
    const sx0 = Math.max(0, rx), sx1 = Math.min(this.width, rx + rw) - 1;
    const sy0 = Math.max(0, ry), sy1 = Math.min(this.height, ry + rh) - 1;
    const toPx = (ndcx, ndcy) => [(ndcx + 1) * 0.5 * this.width, (1 - ndcy) * 0.5 * this.height];
    // Fast path: a single axis-aligned rectangle (backgrounds, borders,
    // gradient strips, rounded boxes) fills a contiguous span; skip the
    // per-pixel edge test. For rounded rects only the corner-radius row bands
    // need per-pixel coverage. Bit-identical to the general path.
    if (indices.length === 6) {
      let rminx = Infinity, rmaxx = -Infinity, rminy = Infinity, rmaxy = -Infinity;
      for (let k = 0; k < 6; k++) {
        const vi = indices[k];
        const [vx, vy] = toPx(vertexData[vi * 4], vertexData[vi * 4 + 1]);
        if (vx < rminx) rminx = vx; if (vx > rmaxx) rmaxx = vx;
        if (vy < rminy) rminy = vy; if (vy > rmaxy) rmaxy = vy;
      }
      const eps = 1e-4;
      let aa = rmaxx - rminx > eps && rmaxy - rminy > eps;
      if (aa) {
        for (let k = 0; k < 6; k++) {
          const vi = indices[k];
          const [vx, vy] = toPx(vertexData[vi * 4], vertexData[vi * 4 + 1]);
          if (!((Math.abs(vx - rminx) < eps || Math.abs(vx - rmaxx) < eps) && (Math.abs(vy - rminy) < eps || Math.abs(vy - rmaxy) < eps))) { aa = false; break; }
        }
      }
      if (aa) {
        const ceil = (v) => { const t = Math.trunc(v); return t < v ? t + 1 : t; };
        const fx0 = Math.max(sx0, ceil(rminx - 0.5)), fx1 = Math.min(sx1 + 1, ceil(rmaxx - 0.5));
        const fy0 = Math.max(sy0, ceil(rminy - 0.5)), fy1 = Math.min(sy1 + 1, ceil(rmaxy - 0.5));
        const fillRow = (py) => {
          if (sa >= 255) {
            const row = py * this.width;
            for (let px = fx0; px < fx1; px++) {
              const o = (row + px) * 4;
              this.pixels[o] = sr; this.pixels[o + 1] = sg; this.pixels[o + 2] = sb; this.pixels[o + 3] = 255;
            }
          } else {
            for (let px = fx0; px < fx1; px++) this.blend(px, py, sr, sg, sb, sa, blend);
          }
        };
        const coverageRow = (py) => {
          const pcy = py + 0.5;
          for (let px = fx0; px < fx1; px++) {
            const cov = this.#cornerCoverage(px + 0.5, pcy, uniforms);
            if (cov > 0) this.blend(px, py, sr, sg, sb, Math.trunc(sa * cov), blend);
          }
        };
        if (fx1 > fx0 && fy1 > fy0) {
          if (!rounded) {
            for (let py = fy0; py < fy1; py++) fillRow(py);
          } else {
            const uy = uniforms[13], uh = uniforms[15];
            const innerY0 = uy + Math.max(uniforms[5], uniforms[7]);
            const innerY1 = uy + uh - Math.max(uniforms[9], uniforms[11]);
            for (let py = fy0; py < fy1; py++) {
              const pcy = py + 0.5;
              if (pcy >= innerY0 && pcy < innerY1) fillRow(py); else coverageRow(py);
            }
          }
        }
        return;
      }
    }
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
          let a = sa;
          if (rounded) {
            const cov = this.#cornerCoverage(pcx, pcy, uniforms);
            if (cov <= 0) continue;
            // Match gfx_software: round alpha to an integer before blending.
            a = Math.trunc(sa * cov);
          }
          this.blend(px, py, sr, sg, sb, a, blend);
        }
      }
    }
  }
  #cornerCoverage(pcx, pcy, u) {
    const rxtl = u[4], rytl = u[5], rxtr = u[6], rytr = u[7];
    const rxbr = u[8], rybr = u[9], rxbl = u[10], rybl = u[11];
    const x = u[12], y = u[13], w = u[14], h = u[15];
    // Elliptical corner coverage (see FILL_WGSL arc_cov): signed distance to
    // the ellipse boundary approximated as -f / |grad f|, softened over 1px.
    const cov = (cx, cy, rx, ry) => {
      const dx = pcx - cx, dy = pcy - cy;
      let c;
      if (Math.abs(rx - ry) < 0.001) {
        c = rx - Math.hypot(dx, dy) + 0.5;
      } else {
        const nx = dx / rx, ny = dy / ry;
        const gx = dx / (rx * rx), gy = dy / (ry * ry);
        const glen = 2 * Math.hypot(gx, gy);
        if (glen < 1e-6) return 1;
        c = (1 - (nx * nx + ny * ny)) / glen + 0.5;
      }
      return c < 0 ? 0 : c > 1 ? 1 : c;
    };
    if (rxtl > 0 && rytl > 0 && pcx < x + rxtl && pcy < y + rytl) return cov(x + rxtl, y + rytl, rxtl, rytl);
    if (rxtr > 0 && rytr > 0 && pcx > x + w - rxtr && pcy < y + rytr) return cov(x + w - rxtr, y + rytr, rxtr, rytr);
    if (rxbr > 0 && rybr > 0 && pcx > x + w - rxbr && pcy > y + h - rybr) return cov(x + w - rxbr, y + h - rybr, rxbr, rybr);
    if (rxbl > 0 && rybl > 0 && pcx < x + rxbl && pcy > y + h - rybl) return cov(x + rxbl, y + h - rybl, rxbl, rybl);
    return 1;
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

// Build the uniform buffer bytes (80) crater's FILL_WGSL expects:
// color(vec4) | radii0(vec4) | radii1(vec4) | rect(vec4) | flags(vec4).
function packUniforms(uniforms) {
  const f = new Float32Array(20);
  f[0] = (uniforms[0] | 0) / 255;
  f[1] = (uniforms[1] | 0) / 255;
  f[2] = (uniforms[2] | 0) / 255;
  f[3] = (uniforms.length > 3 ? uniforms[3] | 0 : 255) / 255;
  const rounded = uniforms.length >= 16 && (uniforms[4] || uniforms[5] || uniforms[6] || uniforms[7] || uniforms[8] || uniforms[9] || uniforms[10] || uniforms[11]);
  if (rounded) {
    // radii0 (rx_tl,ry_tl,rx_tr,ry_tr), radii1 (rx_br,ry_br,rx_bl,ry_bl)
    for (let i = 4; i < 12; i++) f[i] = uniforms[i];
    // rect (x,y,w,h)
    f[12] = uniforms[12]; f[13] = uniforms[13]; f[14] = uniforms[14]; f[15] = uniforms[15];
    f[16] = 1;
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
    const ub = device.createBuffer({ size: 80, usage: 0x40 /* UNIFORM */ | 0x08 });
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

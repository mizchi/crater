///|
pub using @paint_output {type PaintNode, type Framebuffer, type DynamicPalette}

///|
#borrow(pixels)
extern "js" fn framebuffer_to_png_base64_js(
  width : Int,
  height : Int,
  pixels : Array[Int],
  palette_r : Array[Int],
  palette_g : Array[Int],
  palette_b : Array[Int],
) -> String =
  #|(width, height, pixels, pr, pg, pb) => {
  #|  const zlib = require("node:zlib");
  #|  let crcTable = globalThis.__craterPngCrcTable;
  #|  if (!crcTable) {
  #|    crcTable = new Uint32Array(256);
  #|    for (let n = 0; n < 256; n++) {
  #|      let c = n;
  #|      for (let k = 0; k < 8; k++) {
  #|        c = (c & 1) !== 0 ? (0xedb88320 ^ (c >>> 1)) >>> 0 : (c >>> 1) >>> 0;
  #|      }
  #|      crcTable[n] = c >>> 0;
  #|    }
  #|    globalThis.__craterPngCrcTable = crcTable;
  #|  }
  #|  const raw = Buffer.allocUnsafe(height * (width * 4 + 1));
  #|  let src = 0;
  #|  let dst = 0;
  #|  for (let y = 0; y < height; y++) {
  #|    raw[dst++] = 0;
  #|    for (let x = 0; x < width; x++) {
  #|      const idx = pixels[src++] | 0;
  #|      raw[dst++] = idx >= 0 && idx < pr.length ? (pr[idx] | 0) : 255;
  #|      raw[dst++] = idx >= 0 && idx < pg.length ? (pg[idx] | 0) : 255;
  #|      raw[dst++] = idx >= 0 && idx < pb.length ? (pb[idx] | 0) : 255;
  #|      raw[dst++] = 255;
  #|    }
  #|  }
  #|  const compressed = zlib.deflateSync(raw, {
  #|    level: 1,
  #|    strategy: zlib.constants.Z_RLE,
  #|  });
  #|  function crc32(typeBuf, dataBuf) {
  #|    let crc = 0xffffffff;
  #|    for (let i = 0; i < typeBuf.length; i++) {
  #|      crc = (crcTable[(crc ^ typeBuf[i]) & 0xff] ^ (crc >>> 8)) >>> 0;
  #|    }
  #|    for (let i = 0; i < dataBuf.length; i++) {
  #|      crc = (crcTable[(crc ^ dataBuf[i]) & 0xff] ^ (crc >>> 8)) >>> 0;
  #|    }
  #|    return (crc ^ 0xffffffff) >>> 0;
  #|  }
  #|  function chunk(type, data) {
  #|    const typeBuf = Buffer.from(type, "ascii");
  #|    const out = Buffer.allocUnsafe(8 + data.length + 4);
  #|    out.writeUInt32BE(data.length, 0);
  #|    typeBuf.copy(out, 4);
  #|    data.copy(out, 8);
  #|    out.writeUInt32BE(crc32(typeBuf, data), 8 + data.length);
  #|    return out;
  #|  }
  #|  const signature =
  #|    globalThis.__craterPngSignature ||
  #|    (globalThis.__craterPngSignature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  #|  const ihdr = Buffer.allocUnsafe(13);
  #|  ihdr.writeUInt32BE(width >>> 0, 0);
  #|  ihdr.writeUInt32BE(height >>> 0, 4);
  #|  ihdr[8] = 8;
  #|  ihdr[9] = 6;
  #|  ihdr[10] = 0;
  #|  ihdr[11] = 0;
  #|  ihdr[12] = 0;
  #|  const png = Buffer.concat([
  #|    signature,
  #|    chunk("IHDR", ihdr),
  #|    chunk("IDAT", compressed),
  #|    chunk("IEND", Buffer.alloc(0)),
  #|  ]);
  #|  return png.toString("base64");
  #|}

///|
pub fn framebuffer_to_png_base64(
  fb : Framebuffer,
  palette : DynamicPalette,
) -> String {
  let palette_r : Array[Int] = []
  let palette_g : Array[Int] = []
  let palette_b : Array[Int] = []
  for color in palette.colors {
    palette_r.push(color.r)
    palette_g.push(color.g)
    palette_b.push(color.b)
  }
  framebuffer_to_png_base64_js(
    fb.width,
    fb.height,
    fb.pixels,
    palette_r,
    palette_g,
    palette_b,
  )
}

///|
pub fn raster_to_png_base64(
  paint_node : PaintNode,
  width : Int,
  height : Int,
) -> String {
  let (fb, palette) = @paint_output.raster_to_framebuffer(
    paint_node, width, height,
  )
  framebuffer_to_png_base64(fb, palette)
}

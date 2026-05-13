///|
extern "js" fn js_test_png_dimensions(encoded : String) -> String =
  #| (encoded) => {
  #|   try {
  #|     const raw = atob(String(encoded || ""));
  #|     if (raw.length < 24) return "{}";
  #|     const width =
  #|       ((raw.charCodeAt(16) & 0xff) << 24) |
  #|       ((raw.charCodeAt(17) & 0xff) << 16) |
  #|       ((raw.charCodeAt(18) & 0xff) << 8) |
  #|       (raw.charCodeAt(19) & 0xff);
  #|     const height =
  #|       ((raw.charCodeAt(20) & 0xff) << 24) |
  #|       ((raw.charCodeAt(21) & 0xff) << 16) |
  #|       ((raw.charCodeAt(22) & 0xff) << 8) |
  #|       (raw.charCodeAt(23) & 0xff);
  #|     return JSON.stringify({ width: width >>> 0, height: height >>> 0 });
  #|   } catch (_err) {
  #|     return "{}";
  #|   }
  #| }

///|
extern "js" fn js_test_png_pixel_meta(
  encoded : String,
  x : Int,
  y : Int,
) -> String =
  #| (encoded, x, y) => {
  #|   try {
  #|     const zlib = require("node:zlib");
  #|     const buf = Buffer.from(String(encoded || ""), "base64");
  #|     if (buf.length < 33 || buf.readUInt32BE(16) <= 0 || buf.readUInt32BE(20) <= 0) return "{}";
  #|     const width = buf.readUInt32BE(16);
  #|     const height = buf.readUInt32BE(20);
  #|     const colorType = buf[25];
  #|     let offset = 8;
  #|     const idat = [];
  #|     let plte = null;
  #|     while (offset + 8 <= buf.length) {
  #|       const len = buf.readUInt32BE(offset);
  #|       const type = buf.toString("ascii", offset + 4, offset + 8);
  #|       const start = offset + 8;
  #|       const end = start + len;
  #|       if (end > buf.length) break;
  #|       if (type === "IDAT") idat.push(buf.subarray(start, end));
  #|       if (type === "PLTE") plte = buf.subarray(start, end);
  #|       offset = end + 4;
  #|       if (type === "IEND") break;
  #|     }
  #|     const raw = zlib.inflateSync(Buffer.concat(idat));
  #|     const px = Math.max(0, Math.min(width - 1, Number(x) | 0));
  #|     const py = Math.max(0, Math.min(height - 1, Number(y) | 0));
  #|     let nonWhite = 0;
  #|     let r = -1, g = -1, b = -1, a = 255;
  #|     if (colorType === 6) {
  #|       const rowStride = width * 4 + 1;
  #|       const idx = py * rowStride + 1 + px * 4;
  #|       for (let row = 0; row < height; row++) {
  #|         const base = row * rowStride + 1;
  #|         for (let col = 0; col < width; col++) {
  #|           const p = base + col * 4;
  #|           if (raw[p] !== 255 || raw[p + 1] !== 255 || raw[p + 2] !== 255) nonWhite++;
  #|         }
  #|       }
  #|       r = raw[idx] ?? -1;
  #|       g = raw[idx + 1] ?? -1;
  #|       b = raw[idx + 2] ?? -1;
  #|       a = raw[idx + 3] ?? -1;
  #|     } else if (colorType === 3 && plte) {
  #|       const rowStride = width + 1;
  #|       const idx = py * rowStride + 1 + px;
  #|       for (let row = 0; row < height; row++) {
  #|         const base = row * rowStride + 1;
  #|         for (let col = 0; col < width; col++) {
  #|           const p = (raw[base + col] | 0) * 3;
  #|           const pr = plte[p] ?? 255;
  #|           const pg = plte[p + 1] ?? 255;
  #|           const pb = plte[p + 2] ?? 255;
  #|           if (pr !== 255 || pg !== 255 || pb !== 255) nonWhite++;
  #|         }
  #|       }
  #|       const p = (raw[idx] | 0) * 3;
  #|       r = plte[p] ?? -1;
  #|       g = plte[p + 1] ?? -1;
  #|       b = plte[p + 2] ?? -1;
  #|     } else {
  #|       return "{}";
  #|     }
  #|     return JSON.stringify({
  #|       width,
  #|       height,
  #|       colorType,
  #|       r,
  #|       g,
  #|       b,
  #|       a,
  #|       nonWhite,
  #|     });
  #|   } catch (_err) {
  #|     return "{}";
  #|   }
  #| }

///|
extern "js" fn js_test_pdf_meta(encoded : String) -> String =
  #| (encoded) => {
  #|   try {
  #|     const raw = atob(String(encoded || ""));
  #|     const marker = "%CRATER_META ";
  #|     const start = raw.indexOf(marker);
  #|     if (start < 0) return "{}";
  #|     const lineStart = start + marker.length;
  #|     const lineEnd = raw.indexOf("\n", lineStart);
  #|     return lineEnd >= 0 ? raw.slice(lineStart, lineEnd) : raw.slice(lineStart);
  #|   } catch (_err) {
  #|     return "{}";
  #|   }
  #| }

///|
extern "js" fn js_test_build_html_data_url(html : String) -> String =
  #| (html) => {
  #|   const text = String(html ?? "");
  #|   return "data:text/html;charset=utf-8;base64," + btoa(unescape(encodeURIComponent(text)));
  #| }

///|
extern "js" fn js_test_rgba_meta(
  encoded : String,
  width : Int,
  x : Int,
  y : Int,
) -> String =
  #| (encoded, width, x, y) => {
  #|   try {
  #|     const raw = atob(String(encoded || ""));
  #|     const bytes = Uint8Array.from(raw, (ch) => ch.charCodeAt(0));
  #|     const index = ((Number(y) * Number(width)) + Number(x)) * 4;
  #|     return JSON.stringify({
  #|       length: bytes.length,
  #|       r: bytes[index] ?? -1,
  #|       g: bytes[index + 1] ?? -1,
  #|       b: bytes[index + 2] ?? -1,
  #|       a: bytes[index + 3] ?? -1,
  #|     });
  #|   } catch (_err) {
  #|     return "{}";
  #|   }
  #| }

///|
fn extract_success_result(msgs : Array[BidiOutMessage]) -> Map[String, Json] {
  let json = @json.parse(msgs[0].to_json()) catch { _ => make_object({}) }
  match json {
    Object(map) =>
      match map.get("result") {
        Some(Object(result)) => result
        _ => {}
      }
    _ => {}
  }
}

///|
fn png_dimensions_from_base64(encoded : String) -> (Int, Int) {
  let parsed = @json.parse(js_test_png_dimensions(encoded)) catch {
    _ => make_object({})
  }
  match parsed {
    Object(map) => {
      let width = match map.get("width") {
        Some(Number(value, ..)) => value.to_int()
        _ => 0
      }
      let height = match map.get("height") {
        Some(Number(value, ..)) => value.to_int()
        _ => 0
      }
      (width, height)
    }
    _ => (0, 0)
  }
}

///|
fn png_pixel_meta_from_base64(
  encoded : String,
  x : Int,
  y : Int,
) -> Map[String, Json] {
  let parsed = @json.parse(js_test_png_pixel_meta(encoded, x, y)) catch {
    _ => make_object({})
  }
  match parsed {
    Object(map) => map
    _ => {}
  }
}

///|
fn pdf_meta_from_base64(encoded : String) -> Map[String, Json] {
  let parsed = @json.parse(js_test_pdf_meta(encoded)) catch {
    _ => make_object({})
  }
  match parsed {
    Object(map) => map
    _ => {}
  }
}

///|
fn rgba_meta_from_base64(
  encoded : String,
  width : Int,
  x : Int,
  y : Int,
) -> Map[String, Json] {
  let parsed = @json.parse(js_test_rgba_meta(encoded, width, x, y)) catch {
    _ => make_object({})
  }
  match parsed {
    Object(map) => map
    _ => {}
  }
}

///|
fn extract_script_remote_value(result : Map[String, Json]) -> Map[String, Json] {
  match result.get("result") {
    Some(Object(value)) => value
    _ => {}
  }
}

///|
fn extract_shared_id(result : Map[String, Json]) -> String {
  match result.get("sharedId") {
    Some(String(value)) => value
    _ => ""
  }
}

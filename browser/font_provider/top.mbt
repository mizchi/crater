///|
#cfg(target="js")
extern "js" fn js_read_binary_file(path : String) -> Bytes =
  #| (path) => {
  #|   if (typeof process === "undefined") return new Uint8Array(0);
  #|   try {
  #|     const fs = require("node:fs");
  #|     const buf = fs.readFileSync(String(path));
  #|     return new Uint8Array(buf.buffer, buf.byteOffset, buf.byteLength);
  #|   } catch (_err) {
  #|     return new Uint8Array(0);
  #|   }
  #| }

///|
#cfg(not(target="js"))
fn js_read_binary_file(_path : String) -> Bytes {
  Bytes::new(0)
}

///|
pub fn load_system_glyph_provider() -> @glyph.GlyphProvider? {
  match @system_provider.load_system_glyph_provider(js_read_binary_file) {
    Some(provider) => Some(@glyph.glyph_provider_from_delegate(provider))
    None => None
  }
}

///|
pub fn install_system_glyph_provider() -> Bool {
  match load_system_glyph_provider() {
    Some(provider) => {
      @glyph.set_glyph_provider(provider)
      true
    }
    None => false
  }
}

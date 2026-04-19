///|
pub fn loadFont(data : Bytes) -> String {
  @font_js.loadFont(data)
}

///|
pub fn glyphToSvgPath(codepoint : Int, font_size : Double) -> String {
  @font_js.glyphToSvgPath(codepoint, font_size)
}

///|
pub fn glyphAdvance(codepoint : Int, font_size : Double) -> Double {
  @font_js.glyphAdvance(codepoint, font_size)
}

///|
pub fn getFontInfo() -> String {
  @font_js.getFontInfo()
}

///|
pub fn fontName(name_id : Int) -> String {
  @font_js.fontName(name_id)
}

///|
pub fn kernAdvance(cp1 : Int, cp2 : Int, font_size : Double) -> Double {
  @font_js.kernAdvance(cp1, cp2, font_size)
}

///|
pub fn layoutText(text : String, font_size : Double) -> String {
  @font_js.layoutText(text, font_size)
}

///|
pub fn measureText(text : String, font_size : Double) -> Double {
  @font_js.measureText(text, font_size)
}

///|
pub fn fontWeightClass() -> Int {
  @font_js.fontWeightClass()
}

///|
pub fn isFixedPitch() -> Bool {
  @font_js.isFixedPitch() != 0
}

///|
pub fn codepointCoverage() -> String {
  @font_js.codepointCoverage()
}

///|
pub fn glyphIds() -> String {
  @font_js.glyphIds()
}

///|
pub fn tableSizes() -> String {
  @font_js.tableSizes()
}

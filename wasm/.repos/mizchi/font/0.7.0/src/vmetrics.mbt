///|
/// Parse vhea table: returns (v_ascent, v_descent, num_v_metrics)
pub fn parse_vhea(reader : BinaryReader, offset : Int) -> (Int, Int, Int) {
  let v_ascent = reader.peek_int16_at(offset + 4)
  let v_descent = reader.peek_int16_at(offset + 6)
  let num_v_metrics = reader.peek_uint16_at(offset + 34)
  (v_ascent, v_descent, num_v_metrics)
}

///|
/// Parse vmtx table: returns (advance_heights, top_side_bearings)
pub fn parse_vmtx(
  reader : BinaryReader,
  offset : Int,
  num_glyphs : Int,
  num_v_metrics : Int,
) -> (Array[Int], Array[Int]) {
  let advance_heights = Array::new(capacity=num_glyphs)
  let top_side_bearings = Array::new(capacity=num_glyphs)
  reader.seek(offset)
  let mut last_advance = 0
  for i = 0; i < num_glyphs; i = i + 1 {
    if i < num_v_metrics {
      last_advance = reader.read_uint16()
      advance_heights.push(last_advance)
      top_side_bearings.push(reader.read_int16())
    } else {
      advance_heights.push(last_advance)
      top_side_bearings.push(reader.read_int16())
    }
  }
  (advance_heights, top_side_bearings)
}

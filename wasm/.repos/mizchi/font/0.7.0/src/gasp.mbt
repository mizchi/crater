///|
/// Parse gasp table: returns array of GaspRange records
pub fn parse_gasp(reader : BinaryReader, offset : Int) -> Array[GaspRange] {
  let _version = reader.peek_uint16_at(offset)
  let num_ranges = reader.peek_uint16_at(offset + 2)
  let ranges : Array[GaspRange] = Array::new(capacity=num_ranges)
  for i = 0; i < num_ranges; i = i + 1 {
    let rec_offset = offset + 4 + i * 4
    let max_ppem = reader.peek_uint16_at(rec_offset)
    let behavior = reader.peek_uint16_at(rec_offset + 2)
    ranges.push({ max_ppem, behavior })
  }
  ranges
}

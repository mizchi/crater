///|
pub fn brotli_decompress(data : Bytes) -> Bytes raise BrotliError {
  let br = BitReader::new(data)
  brotli_decompress_internal(br)
}

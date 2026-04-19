///|
pub(all) suberror BrotliError {
  InvalidData(String)
}

///|
priv struct HuffmanCode {
  bits : Int
  value : Int
}

///|
priv struct MetaBlockLength {
  mut meta_block_length : Int
  mut input_end : Bool
  mut is_uncompressed : Bool
  mut is_metadata : Bool
}

///|
fn MetaBlockLength::new() -> MetaBlockLength {
  {
    meta_block_length: 0,
    input_end: false,
    is_uncompressed: false,
    is_metadata: false,
  }
}

///|
let kDefaultCodeLength : Int = 8

///|
let kCodeLengthRepeatCode : Int = 16

///|
let kNumLiteralCodes : Int = 256

///|
let kNumInsertAndCopyCodes : Int = 704

///|
let kNumBlockLengthCodes : Int = 26

///|
let kLiteralContextBits : Int = 6

///|
let kDistanceContextBits : Int = 2

///|
let huffman_table_bits : Int = 8

///|
let huffman_table_mask : Int = 0xff

///|
let huffman_max_table_size : Int = 1080

///|
let code_length_codes : Int = 18

///|
let kCodeLengthCodeOrder : FixedArray[Int] = [
  1, 2, 3, 4, 0, 5, 17, 6, 16, 7, 8, 9, 10, 11, 12, 13, 14, 15,
]

///|
let num_distance_short_codes : Int = 16

///|
let kDistanceShortCodeIndexOffset : FixedArray[Int] = [
  3, 2, 1, 0, 3, 3, 3, 3, 3, 3, 2, 2, 2, 2, 2, 2,
]

///|
let kDistanceShortCodeValueOffset : FixedArray[Int] = [
  0, 0, 0, 0, -1, 1, -2, 2, -3, 3, -1, 1, -2, 2, -3, 3,
]

///|
let kMaxHuffmanTableSize : FixedArray[Int] = [
  256, 402, 436, 468, 500, 534, 566, 598, 630, 662, 694, 726, 758, 790, 822, 854,
  886, 920, 952, 984, 1016, 1048, 1080,
]

///|
let kBitMask : FixedArray[Int] = [
  0, 1, 3, 7, 15, 31, 63, 127, 255, 511, 1023, 2047, 4095, 8191, 16383, 32767, 65535,
  131071, 262143, 524287, 1048575, 2097151, 4194303, 8388607, 16777215,
]

///|
/// Unsigned right shift (logical shift right)
fn ushr(x : Int, n : Int) -> Int {
  (x.reinterpret_as_uint() >> n).reinterpret_as_int()
}

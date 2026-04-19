///|
let brotli_dictionary : Bytes = load_dictionary()

///|
let offsets_by_length : FixedArray[Int] = [
  0, 0, 0, 0, 0, 4096, 9216, 21504, 35840, 44032, 53248, 63488, 74752, 87040, 93696,
  100864, 104704, 106752, 108928, 113536, 115968, 118528, 119872, 121280, 122016,
]

///|
let size_bits_by_length : FixedArray[Int] = [
  0, 0, 0, 0, 10, 10, 11, 11, 10, 10, 10, 10, 10, 9, 9, 8, 7, 7, 8, 7, 7, 6, 6, 5,
  5,
]

///|
let min_dictionary_word_length : Int = 4

///|
let max_dictionary_word_length : Int = 24

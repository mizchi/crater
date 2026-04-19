///|
let kIdentity : Int = 0

///|
let kOmitLast1 : Int = 1

///|
let kOmitLast2 : Int = 2

///|
let kOmitLast3 : Int = 3

///|
let kOmitLast4 : Int = 4

///|
let kOmitLast5 : Int = 5

///|
let kOmitLast6 : Int = 6

///|
let kOmitLast7 : Int = 7

///|
let kOmitLast8 : Int = 8

///|
let kOmitLast9 : Int = 9

///|
let kUppercaseFirst : Int = 10

///|
let kUppercaseAll : Int = 11

///|
let kOmitFirst1 : Int = 12

///|
priv struct TransformRule {
  prefix : Bytes
  transform : Int
  suffix : Bytes
}

///|
fn str_to_bytes(s : String) -> Bytes {
  let buf = Array::new(capacity=s.length())
  for c in s {
    buf.push(c.to_int().to_byte())
  }
  Bytes::from_array(buf)
}

///|
fn make_transform(
  prefix : String,
  transform : Int,
  suffix : String,
) -> TransformRule {
  { prefix: str_to_bytes(prefix), transform, suffix: str_to_bytes(suffix) }
}

///|
let kTransforms : Array[TransformRule] = {
  let t = make_transform
  let id = kIdentity
  let o1 = kOmitLast1
  let o2 = kOmitLast2
  let o3 = kOmitLast3
  let o4 = kOmitLast4
  let o5 = kOmitLast5
  let o6 = kOmitLast6
  let o7 = kOmitLast7
  let o8 = kOmitLast8
  let o9 = kOmitLast9
  let uf = kUppercaseFirst
  let ua = kUppercaseAll
  let f1 = kOmitFirst1
  let f2 = 13
  let f3 = 14
  let f4 = 15
  let f5 = 16
  let f6 = 17
  let f7 = 18
  let f9 = 20
  [
    t("", id, ""),
    t("", id, " "),
    t(" ", id, " "),
    t("", f1, ""),
    t("", uf, " "),
    t("", id, " the "),
    t(" ", id, ""),
    t("s ", id, " "),
    t("", id, " of "),
    t("", uf, ""),
    t("", id, " and "),
    t("", f2, ""),
    t("", o1, ""),
    t(", ", id, " "),
    t("", id, ", "),
    t(" ", uf, " "),
    t("", id, " in "),
    t("", id, " to "),
    t("e ", id, " "),
    t("", id, "\""),
    t("", id, "."),
    t("", id, "\">"),
    t("", id, "\n"),
    t("", o3, ""),
    t("", id, "]"),
    t("", id, " for "),
    t("", f3, ""),
    t("", o2, ""),
    t("", id, " a "),
    t("", id, " that "),
    t(" ", uf, ""),
    t("", id, ". "),
    t(".", id, ""),
    t(" ", id, ", "),
    t("", f4, ""),
    t("", id, " with "),
    t("", id, "'"),
    t("", id, " from "),
    t("", id, " by "),
    t("", f5, ""),
    t("", f6, ""),
    t(" the ", id, ""),
    t("", o4, ""),
    t("", id, ". The "),
    t("", ua, ""),
    t("", id, " on "),
    t("", id, " as "),
    t("", id, " is "),
    t("", o7, ""),
    t("", o1, "ing "),
    t("", id, "\n\t"),
    t("", id, ":"),
    t(" ", id, ". "),
    t("", id, "ed "),
    t("", f9, ""),
    t("", f7, ""),
    t("", o6, ""),
    t("", id, "("),
    t("", uf, ", "),
    t("", o8, ""),
    t("", id, " at "),
    t("", id, "ly "),
    t(" the ", id, " of "),
    t("", o5, ""),
    t("", o9, ""),
    t(" ", uf, ", "),
    t("", uf, "\""),
    t(".", id, "("),
    t("", ua, " "),
    t("", uf, "\">"),
    t("", id, "=\""),
    t(" ", id, "."),
    t(".com/", id, ""),
    t(" the ", id, " of the "),
    t("", uf, "'"),
    t("", id, ". This "),
    t("", id, ","),
    t(".", id, " "),
    t("", uf, "("),
    t("", uf, "."),
    t("", id, " not "),
    t(" ", id, "=\""),
    t("", id, "er "),
    t(" ", ua, " "),
    t("", id, "al "),
    t(" ", ua, ""),
    t("", id, "='"),
    t("", ua, "\""),
    t("", uf, ". "),
    t(" ", id, "("),
    t("", id, "ful "),
    t(" ", uf, ". "),
    t("", id, "ive "),
    t("", id, "less "),
    t("", ua, "'"),
    t("", id, "est "),
    t(" ", uf, "."),
    t("", ua, "\">"),
    t(" ", id, "='"),
    t("", uf, ","),
    t("", id, "ize "),
    t("", ua, "."),
    t("\u00c2\u00a0", id, ""),
    t(" ", id, ","),
    t("", uf, "=\""),
    t("", ua, "=\""),
    t("", id, "ous "),
    t("", ua, ", "),
    t("", uf, "='"),
    t(" ", uf, ","),
    t(" ", ua, "=\""),
    t(" ", ua, ", "),
    t("", ua, ","),
    t("", ua, "("),
    t("", ua, ". "),
    t(" ", ua, "."),
    t("", ua, "='"),
    t(" ", ua, ". "),
    t(" ", uf, "=\""),
    t(" ", ua, "='"),
    t(" ", uf, "='"),
  ]
}

///|
let kNumTransforms : Int = 121

///|
fn to_upper_case(p : FixedArray[Int], i : Int) -> Int {
  if p[i] < 0xc0 {
    if p[i] >= 97 && p[i] <= 122 {
      p[i] = p[i] ^ 32
    }
    return 1
  }
  if p[i] < 0xe0 {
    p[i + 1] = p[i + 1] ^ 32
    return 2
  }
  p[i + 2] = p[i + 2] ^ 5
  3
}

///|
fn transform_dictionary_word(
  dst : FixedArray[Int],
  idx : Int,
  word : Int,
  len : Int,
  transform : Int,
) -> Int {
  let prefix = kTransforms[transform].prefix
  let suffix = kTransforms[transform].suffix
  let t = kTransforms[transform].transform
  let mut skip = if t < kOmitFirst1 { 0 } else { t - (kOmitFirst1 - 1) }
  let mut idx = idx
  let start_idx = idx
  let mut len = len
  if skip > len {
    skip = len
  }
  for i in 0..<prefix.length() {
    dst[idx] = prefix[i].to_int()
    idx += 1
  }
  let word = word + skip
  len -= skip
  if t <= kOmitLast9 {
    len -= t
  }
  for i in 0..<len {
    dst[idx] = brotli_dictionary[word + i].to_int()
    idx += 1
  }
  let mut uppercase = idx - len
  if t == kUppercaseFirst {
    let _ = to_upper_case(dst, uppercase)
  } else if t == kUppercaseAll {
    while len > 0 {
      let step = to_upper_case(dst, uppercase)
      uppercase += step
      len -= step
    }
  }
  for i in 0..<suffix.length() {
    dst[idx] = suffix[i].to_int()
    idx += 1
  }
  idx - start_idx
}

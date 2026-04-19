// SQLite common types for MoonBit

///|
pub(all) enum SqlValue {
  Null
  Int(Int)
  Int64(Int64)
  Double(Double)
  Text(Bytes)
  Blob(Bytes)
}

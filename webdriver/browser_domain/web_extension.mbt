///|
/// Pure helpers for synthetic web extension domain handling.

///|
pub fn is_valid_web_extension_archive_payload(decoded : String) -> Bool {
  decoded.has_prefix("Cr24") || decoded.has_prefix("PK")
}

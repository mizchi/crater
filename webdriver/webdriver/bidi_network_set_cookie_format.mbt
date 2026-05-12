///|
fn synthetic_network_format_set_cookie_header(
  entry : Map[String, Json],
) -> String {
  let parts : Array[String] = []
  let name = match entry.get("name") {
    Some(String(name)) => name
    _ => ""
  }
  let value = match entry.get("value") {
    Some(String(value)) => value
    _ => ""
  }
  parts.push(name + "=" + value)
  match entry.get("path") {
    Some(String(path)) => parts.push("Path=" + path)
    _ => ()
  }
  match entry.get("domain") {
    Some(String(domain)) => parts.push("Domain=" + domain)
    _ => ()
  }
  match entry.get("expiry") {
    Some(String(expiry)) => parts.push("Expires=" + expiry)
    _ => ()
  }
  match entry.get("maxAge") {
    Some(Number(max_age, ..)) =>
      parts.push("Max-Age=" + max_age.to_int().to_string())
    _ => ()
  }
  match entry.get("httpOnly") {
    Some(True) => parts.push("HttpOnly")
    _ => ()
  }
  match entry.get("secure") {
    Some(True) => parts.push("Secure")
    _ => ()
  }
  match entry.get("sameSite") {
    Some(String(raw_same_site)) => {
      let same_site = raw_same_site.to_lower()
      let mapped = if same_site == "none" {
        "None"
      } else if same_site == "lax" {
        "Lax"
      } else if same_site == "strict" {
        "Strict"
      } else {
        raw_same_site
      }
      parts.push("SameSite=" + mapped)
    }
    _ => ()
  }
  parts.join(";")
}

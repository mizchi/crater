///|
/// Public Suffix List lookup for SameSite / cookie eTLD+1 classification.
/// See `psl_data.mbt` for the curated rule set and refresh policy.
///
/// The algorithm follows the publicsuffix.org reference:
///
/// 1. Split the host into labels.
/// 2. Find the longest matching rule (literal beats wildcard at the
///    same length).
/// 3. If the longest match is an exception, the public suffix is one
///    label shorter than the matched rule.
/// 4. Registrable domain (eTLD+1) is one label longer than the public
///    suffix, i.e. the first label to the left of the suffix joined
///    with the suffix.
///
/// localhost and IP literals are returned as their own registrable
/// domain so they only match themselves.

///|
/// Reduce `host` to its registrable domain (eTLD+1) using the curated
/// PSL. Falls back to the simple "last two labels" heuristic when no
/// PSL rule matches — that matches pre-PSL behaviour for hosts whose
/// TLD is not in the curated subset and keeps fixture tests stable.
pub fn registrable_domain(host : String) -> String {
  let normalized = normalize_host(host)
  if normalized == "" {
    return normalized
  }
  if is_unsplittable_host(normalized) {
    return normalized
  }
  match registrable_domain_via_psl(normalized) {
    Some(d) => d
    None => registrable_domain_heuristic(normalized)
  }
}

///|
/// Lowercase the host and strip a single trailing dot (FQDN form).
/// Returns the empty string for input that has no labels.
pub fn normalize_host(host : String) -> String {
  let lower = host.to_lower()
  if lower == "" {
    return lower
  }
  if lower.has_suffix(".") && lower.length() > 1 {
    lower.unsafe_substring(start=0, end=lower.length() - 1)
  } else {
    lower
  }
}

///|
/// Hosts that should not be reduced: localhost and IP literals.
pub fn is_unsplittable_host(host : String) -> Bool {
  host == "localhost" || is_ip_literal(host)
}

///|
/// IPv4 dotted-quad heuristic plus IPv6 bracketed form. Matches the
/// pre-PSL behaviour in `samesite.mbt`.
pub fn is_ip_literal(host : String) -> Bool {
  if host.has_prefix("[") && host.has_suffix("]") {
    return true
  }
  let parts : Array[StringView] = host.split(".").collect()
  if parts.length() != 4 {
    return false
  }
  for p in parts {
    let s = p.to_owned()
    if s == "" || s.length() > 3 {
      return false
    }
    let mut value = 0
    for i = 0; i < s.length(); i = i + 1 {
      let c = s[i]
      if c < '0' || c > '9' {
        return false
      }
      value = value * 10 + (c.to_int() - '0'.to_int())
    }
    if value > 255 {
      return false
    }
  }
  true
}

///|
fn registrable_domain_via_psl(host : String) -> String? {
  let labels = split_labels(host)
  let n = labels.length()
  if n == 0 {
    return None
  }
  let literals = literal_map()
  let wildcards = wildcard_map()
  let exceptions = exception_map()
  let mut best_match : Int = 0
  let mut best_is_exception = false
  for i = 1; i <= n; i = i + 1 {
    let suffix = join_labels(labels, n - i, n)
    if exceptions.contains(suffix) {
      if i > best_match {
        best_match = i
        best_is_exception = true
      }
      continue
    }
    if literals.contains(suffix) {
      if i > best_match {
        best_match = i
        best_is_exception = false
      }
      continue
    }
    if i >= 2 {
      let parent = join_labels(labels, n - i + 1, n)
      if wildcards.contains(parent) && i > best_match {
        best_match = i
        best_is_exception = false
      }
    }
  }
  if best_match == 0 {
    return None
  }
  let public_suffix_len = if best_is_exception {
    best_match - 1
  } else {
    best_match
  }
  if public_suffix_len <= 0 {
    return None
  }
  if public_suffix_len >= n {
    return Some(host)
  }
  Some(join_labels(labels, n - public_suffix_len - 1, n))
}

///|
fn registrable_domain_heuristic(host : String) -> String {
  let labels = split_labels(host)
  let n = labels.length()
  if n <= 2 {
    return host
  }
  join_labels(labels, n - 2, n)
}

///|
fn split_labels(host : String) -> Array[String] {
  let out : Array[String] = []
  let views : Array[StringView] = host.split(".").collect()
  for v in views {
    out.push(v.to_owned())
  }
  out
}

///|
fn join_labels(labels : Array[String], start : Int, end : Int) -> String {
  let buf = StringBuilder::new()
  for i = start; i < end; i = i + 1 {
    if i > start {
      buf.write_char('.')
    }
    buf.write_string(labels[i])
  }
  buf.to_string()
}

///|
fn literal_map() -> Map[String, Bool] {
  let m : Map[String, Bool] = Map([], capacity=32)
  for r in psl_literal_rules() {
    m[r] = true
  }
  m
}

///|
fn wildcard_map() -> Map[String, Bool] {
  let m : Map[String, Bool] = Map([], capacity=32)
  for r in psl_wildcard_rules() {
    m[r] = true
  }
  m
}

///|
fn exception_map() -> Map[String, Bool] {
  let m : Map[String, Bool] = Map([], capacity=32)
  for r in psl_exception_rules() {
    m[r] = true
  }
  m
}

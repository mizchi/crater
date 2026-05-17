///|
/// Whether a request origin and a cookie domain live on the same site
/// (same registrable domain, a.k.a. eTLD+1). Used to decide SameSite
/// cookie attach.
pub(all) enum SiteContext {
  SameSite
  CrossSite
} derive(Eq)

///|
pub impl Show for SiteContext with output(self, logger) {
  match self {
    SameSite => logger.write_string("SameSite")
    CrossSite => logger.write_string("CrossSite")
  }
}

///|
/// Conservative eTLD+1 extractor. P1 uses a hard-coded "second-to-last
/// label" heuristic: it correctly handles example.com / *.example.com
/// vs unrelated.com, treats localhost / IP literals as their own site,
/// and falls back to CrossSite on parse failure so we never over-attach.
///
/// Limitation: not Public Suffix List-aware. `example.co.uk` and
/// `other.co.uk` would both reduce to `co.uk` and be treated as
/// same-site. Acceptable for P1 fixture testing; PSL upgrade is tracked
/// as a separate scenario.
pub fn classify_site_context(
  request_origin : String,
  cookie_domain : String,
) -> SiteContext {
  match parse_host(request_origin) {
    None => CrossSite
    Some(req_host) => {
      let req_site = registrable_domain(req_host)
      let cookie_site = registrable_domain(cookie_domain)
      if req_site == cookie_site {
        SameSite
      } else {
        CrossSite
      }
    }
  }
}

///|
/// Extract the host portion of `scheme://host[:port][/path][?q][#f]`.
/// Returns None if the input does not contain `://` or yields an empty
/// host — both are treated as malformed and fall back to CrossSite by
/// the caller.
fn parse_host(origin : String) -> String? {
  // strip scheme
  let after_scheme = match origin.find("://") {
    Some(i) => origin.unsafe_substring(start=i + 3, end=origin.length())
    None => return None
  }
  // strip path / query / fragment by truncating at the first occurrence
  // of any of '/', '?', '#'
  let host_port = truncate_at_any(after_scheme, ['/', '?', '#'])
  if host_port == "" {
    return None
  }
  // strip port (use the part before the first ':')
  let host = truncate_at_any(host_port, [':'])
  if host == "" {
    return None
  }
  Some(host)
}

///|
/// Return the prefix of `s` up to (but not including) the first
/// occurrence of any character in `stops`. If no stop char is present,
/// returns `s` unchanged.
fn truncate_at_any(s : String, stops : Array[Char]) -> String {
  let chars = s.to_array()
  let mut end = chars.length()
  for i = 0; i < chars.length(); i = i + 1 {
    if stops.contains(chars[i]) {
      end = i
      break
    }
  }
  s.unsafe_substring(start=0, end~)
}

///|
/// Reduce a host to its registrable domain ("eTLD+1") via the simple
/// "last two labels" heuristic. localhost and IP literals are returned
/// as-is so they only match themselves.
fn registrable_domain(host : String) -> String {
  if host == "localhost" || is_ip_literal(host) {
    return host
  }
  let labels : Array[StringView] = host.split(".").collect()
  let n = labels.length()
  if n <= 2 {
    return host
  }
  // last two labels: works for .com / .net / etc.; not PSL-aware but
  // sufficient for fixture testing — PSL upgrade is a separate scenario.
  labels[n - 2].to_owned() + "." + labels[n - 1].to_owned()
}

///|
/// IPv4 dotted-quad heuristic plus IPv6 bracketed form. Conservative:
/// any host that "looks like" an IP is treated as its own site.
fn is_ip_literal(host : String) -> Bool {
  if host.has_prefix("[") && host.has_suffix("]") {
    return true
  }
  let parts : Array[StringView] = host.split(".").collect()
  if parts.length() != 4 {
    return false
  }
  for part in parts {
    let s = part.to_owned()
    if s == "" || s.length() > 3 {
      return false
    }
    let chars = s.to_array()
    for i = 0; i < chars.length(); i = i + 1 {
      let c = chars[i]
      if c < '0' || c > '9' {
        return false
      }
    }
  }
  true
}

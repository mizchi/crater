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
/// eTLD+1 extractor backed by the curated Public Suffix List in
/// `http/psl`. Hosts whose TLD appears in the curated PSL subset
/// (e.g. `co.uk`, `co.jp`, `github.io`) reduce to their PSL-derived
/// registrable domain; hosts whose TLD is not in the subset fall back
/// to the simple "last two labels" heuristic for compatibility with
/// existing fixture tests. localhost and IP literals are returned as
/// their own site, and malformed origins fall back to CrossSite so
/// we never over-attach.
pub fn classify_site_context(
  request_origin : String,
  cookie_domain : String,
) -> SiteContext {
  match parse_host(request_origin) {
    None => CrossSite
    Some(req_host) => {
      let req_site = @psl.registrable_domain(req_host)
      let cookie_site = @psl.registrable_domain(cookie_domain)
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
  // Strip a single trailing dot — FQDN forms like "example.com." are
  // equivalent to "example.com" for site comparison.
  let host = if host.has_suffix(".") && host.length() > 1 {
    host.unsafe_substring(start=0, end=host.length() - 1)
  } else {
    host
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
/// Decide whether `cookie` should be attached to a request, given the
/// precomputed `site_context` (cookie domain vs request origin) and
/// whether the request is a top-level navigation.
///
/// Implements the WHATWG cookies-bis SameSite attach filter:
///
/// - `Strict`: attach only when same-site (regardless of navigation kind).
/// - `Lax`: attach when same-site; for cross-site, attach only on a
///   top-level navigation (e.g. clicking a link).
/// - `None` / unspecified: always attach. (Note: SameSite=None requires
///   the Secure attribute, but that's enforced at parse / store time, not
///   here — by the time a cookie is in the jar, the Secure check has
///   already passed.)
/// - Unknown values default to Lax per RFC 6265bis.
pub fn should_attach_cookie(
  cookie : @cookie_jar.ParsedCookie,
  site_context : SiteContext,
  is_top_level_navigation : Bool,
) -> Bool {
  // ParsedCookie stores SameSite as a lowercased string ("strict" / "lax"
  // / "none" / ""). Unknown / empty values are treated as Lax per
  // RFC 6265bis "Lax by default".
  match cookie.same_site {
    "strict" =>
      match site_context {
        SameSite => true
        CrossSite => false
      }
    "none" => true
    // "lax" and the empty / unknown default
    _ =>
      match site_context {
        SameSite => true
        CrossSite => is_top_level_navigation
      }
  }
}


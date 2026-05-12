///|
/// Remove URL fragment part (after `#`) if present.
fn strip_url_fragment(url : String) -> String {
  match find_substring(url, "#", 0) {
    Some(idx) => url.unsafe_substring(start=0, end=idx)
    None => url
  }
}

///|
/// Remove URL query part (after `?`) if present.
fn strip_url_query(url : String) -> String {
  match find_substring(url, "?", 0) {
    Some(idx) => url.unsafe_substring(start=0, end=idx)
    None => url
  }
}

///|
fn extract_url_fragment_suffix(url : String) -> String {
  match find_substring(url, "#", 0) {
    Some(idx) => url.unsafe_substring(start=idx, end=url.length())
    None => ""
  }
}

///|
fn extract_http_url_authority(url : String) -> String? {
  match find_substring(url, "://", 0) {
    Some(scheme_idx) => {
      let host_start = scheme_idx + 3
      let chars = url.to_array()
      let mut host_end = chars.length()
      for i = host_start; i < chars.length(); i = i + 1 {
        let ch = chars[i]
        if ch == '/' || ch == '?' || ch == '#' {
          host_end = i
          break
        }
      }
      if host_start >= host_end {
        None
      } else {
        Some(url.unsafe_substring(start=host_start, end=host_end))
      }
    }
    None => None
  }
}

///|
fn extract_http_url_path(url : String) -> String? {
  match find_substring(url, "://", 0) {
    Some(scheme_idx) => {
      let host_start = scheme_idx + 3
      let chars = url.to_array()
      let mut path_start = chars.length()
      for i = host_start; i < chars.length(); i = i + 1 {
        let ch = chars[i]
        if ch == '/' {
          path_start = i
          break
        }
        if ch == '?' || ch == '#' {
          return Some("/")
        }
      }
      if path_start >= chars.length() {
        return Some("/")
      }
      let mut path_end = chars.length()
      for i = path_start; i < chars.length(); i = i + 1 {
        let ch = chars[i]
        if ch == '?' || ch == '#' {
          path_end = i
          break
        }
      }
      Some(url.unsafe_substring(start=path_start, end=path_end))
    }
    None => None
  }
}

///|
fn resolve_relative_url_against_base(
  base_url : String,
  target_url : String,
) -> String {
  match find_substring(base_url, "://", 0) {
    Some(scheme_idx) => {
      let host_start = scheme_idx + 3
      let path_start = find_substring(base_url, "/", host_start).unwrap_or(
        base_url.length(),
      )
      let origin = base_url.unsafe_substring(start=0, end=path_start)
      if target_url.has_prefix("/") {
        return origin + target_url
      }
      let normalized_base = strip_url_query(strip_url_fragment(base_url))
      if path_start >= normalized_base.length() {
        return origin + "/" + target_url
      }
      let chars = normalized_base.to_array()
      let mut last_slash = path_start
      for i = path_start; i < chars.length(); i = i + 1 {
        if chars[i] == '/' {
          last_slash = i
        }
      }
      let base_dir = normalized_base.unsafe_substring(
        start=0,
        end=last_slash + 1,
      )
      origin +
      normalize_relative_url_path(
        base_dir.unsafe_substring(start=origin.length(), end=base_dir.length()) +
        target_url,
      )
    }
    None => target_url
  }
}

///|
fn normalize_relative_url_path(path : String) -> String {
  let absolute = path.has_prefix("/")
  let parts : Array[String] = []
  for segment in path.split("/") {
    let segment = segment.to_owned()
    if segment == "" || segment == "." {
      continue
    }
    if segment == ".." {
      if parts.length() > 0 {
        ignore(parts.pop())
      }
      continue
    }
    parts.push(segment)
  }
  let normalized = parts.join("/")
  if absolute {
    "/" + normalized
  } else {
    normalized
  }
}

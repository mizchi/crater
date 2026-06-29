///|
/// Get character at index from string (returns '\0' if out of bounds)
fn char_at(s : String, i : Int) -> Char {
  if i < 0 || i >= s.length() {
    '\u0000'
  } else {
    s[i].to_int().unsafe_to_char()
  }
}

///|
/// Extract links from HTML content (portable fallback version)
#cfg(not(target="js"))
fn extract_links_fallback(html : String) -> Array[Link] {
  let links : Array[Link] = []
  let len = html.length()
  let mut i = 0
  while i < len {
    // Look for <a
    if i + 2 < len &&
      char_at(html, i) == '<' &&
      (char_at(html, i + 1) == 'a' || char_at(html, i + 1) == 'A') &&
      (char_at(html, i + 2) == ' ' || char_at(html, i + 2) == '\t') {
      // Find href="
      let mut j = i + 2
      let mut href = ""
      let mut source_id = ""
      while j < len && char_at(html, j) != '>' {
        if j + 6 < len &&
          (char_at(html, j) == 'h' || char_at(html, j) == 'H') &&
          (char_at(html, j + 1) == 'r' || char_at(html, j + 1) == 'R') &&
          (char_at(html, j + 2) == 'e' || char_at(html, j + 2) == 'E') &&
          (char_at(html, j + 3) == 'f' || char_at(html, j + 3) == 'F') &&
          char_at(html, j + 4) == '=' {
          let quote = char_at(html, j + 5)
          if quote == '"' || quote == '\'' {
            let mut k = j + 6
            while k < len && char_at(html, k) != quote {
              k = k + 1
            }
            href = html.unsafe_substring(start=j + 6, end=k)
          }
        } else if j + 4 < len &&
          (char_at(html, j) == 'i' || char_at(html, j) == 'I') &&
          (char_at(html, j + 1) == 'd' || char_at(html, j + 1) == 'D') &&
          char_at(html, j + 2) == '=' {
          let quote = char_at(html, j + 3)
          if quote == '"' || quote == '\'' {
            let mut k = j + 4
            while k < len && char_at(html, k) != quote {
              k = k + 1
            }
            source_id = html.unsafe_substring(start=j + 4, end=k)
          }
        }
        j = j + 1
      }
      // Find link text (between > and </a>)
      if j < len && char_at(html, j) == '>' {
        let text_start = j + 1
        let mut text_end = text_start
        while text_end + 3 < len {
          if char_at(html, text_end) == '<' &&
            char_at(html, text_end + 1) == '/' &&
            (
              char_at(html, text_end + 2) == 'a' ||
              char_at(html, text_end + 2) == 'A'
            ) {
            break
          }
          text_end = text_end + 1
        }
        let text = html
          .unsafe_substring(start=text_start, end=text_end)
          .trim()
          .to_owned()
        if href.length() > 0 {
          links.push({ href, text, source_id })
        }
        i = text_end
      }
    }
    i = i + 1
  }
  links
}

///|
#cfg(target="js")
extern "js" fn extract_links_js(html : String) -> Array[Link] =
  #| (html) => {
  #|   const links = [];
  #|   const anchorRe = /<a\b([^>]*)>([\s\S]*?)<\/a\s*>/gi;
  #|   const readAttr = (attrs, name) => {
  #|     const re = new RegExp(
  #|       "\\b" + name + "\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s\"'>]+))",
  #|       "i",
  #|     );
  #|     const match = re.exec(attrs);
  #|     return match ? String(match[1] ?? match[2] ?? match[3] ?? "") : "";
  #|   };
  #|   let match;
  #|   while ((match = anchorRe.exec(html)) !== null) {
  #|     const attrs = String(match[1] ?? "");
  #|     const href = readAttr(attrs, "href");
  #|     if (!href) continue;
  #|     links.push({
  #|       href,
  #|       text: String(match[2] ?? "").trim(),
  #|       source_id: readAttr(attrs, "id"),
  #|     });
  #|   }
  #|   return links;
  #| }

///|
#cfg(target="js")
fn extract_links(html : String) -> Array[Link] {
  extract_links_js(html)
}

///|
#cfg(not(target="js"))
fn extract_links(html : String) -> Array[Link] {
  extract_links_fallback(html)
}

///|
fn Browser::refresh_links_from_render_source(self : Browser) -> Unit {
  self.links = extract_links(self.html_content)
}

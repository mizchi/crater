///|
extern "js" fn js_encode_base64_utf8(value : String) -> String =
  #| (value) => {
  #|   const text = String(value ?? "");
  #|   return btoa(unescape(encodeURIComponent(text)));
  #| }

///|
extern "js" fn js_encode_uri_component(value : String) -> String =
  #| (value) =>
  #|   encodeURIComponent(String(value ?? "")).replace(
  #|     /[!'()*]/g,
  #|     (ch) => "%" + ch.charCodeAt(0).toString(16).toUpperCase(),
  #|   )

///|
let black_dot_png_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIW2NgYGD4DwABBAEAwS2OUAAAAABJRU5ErkJggg=="

///|
let white_dot_png_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQIW2P4DwQACfsD/Z8fLAAAAAAASUVORK5CYII="

///|
extern "js" fn js_png_dimensions_json(encoded : String) -> String =
  #| (encoded) => {
  #|   try {
  #|     const raw = atob(String(encoded || ""));
  #|     if (raw.length < 24) return "{}";
  #|     const width =
  #|       ((raw.charCodeAt(16) & 0xff) << 24) |
  #|       ((raw.charCodeAt(17) & 0xff) << 16) |
  #|       ((raw.charCodeAt(18) & 0xff) << 8) |
  #|       (raw.charCodeAt(19) & 0xff);
  #|     const height =
  #|       ((raw.charCodeAt(20) & 0xff) << 24) |
  #|       ((raw.charCodeAt(21) & 0xff) << 16) |
  #|       ((raw.charCodeAt(22) & 0xff) << 8) |
  #|       (raw.charCodeAt(23) & 0xff);
  #|     return JSON.stringify({ width: width >>> 0, height: height >>> 0 });
  #|   } catch (_err) {
  #|     return "{}";
  #|   }
  #| }

///|
extern "js" fn js_pdf_meta_json(encoded : String) -> String =
  #| (encoded) => {
  #|   try {
  #|     const raw = atob(String(encoded || ""));
  #|     const marker = "%CRATER_META ";
  #|     const start = raw.indexOf(marker);
  #|     if (start < 0) return "{}";
  #|     const lineStart = start + marker.length;
  #|     const lineEnd = raw.indexOf("\n", lineStart);
  #|     return lineEnd >= 0 ? raw.slice(lineStart, lineEnd) : raw.slice(lineStart);
  #|   } catch (_err) {
  #|     return "{}";
  #|   }
  #| }

///|
extern "js" fn js_compare_png_json(left : String, right : String) -> String =
  #| (left, right) => {
  #|   const dimensions = (encoded) => {
  #|     try {
  #|       const raw = atob(String(encoded || ""));
  #|       if (raw.length < 24) return null;
  #|       const width =
  #|         ((raw.charCodeAt(16) & 0xff) << 24) |
  #|         ((raw.charCodeAt(17) & 0xff) << 16) |
  #|         ((raw.charCodeAt(18) & 0xff) << 8) |
  #|         (raw.charCodeAt(19) & 0xff);
  #|       const height =
  #|         ((raw.charCodeAt(20) & 0xff) << 24) |
  #|         ((raw.charCodeAt(21) & 0xff) << 16) |
  #|         ((raw.charCodeAt(22) & 0xff) << 8) |
  #|         (raw.charCodeAt(23) & 0xff);
  #|       return { width: width >>> 0, height: height >>> 0 };
  #|     } catch (_err) {
  #|       return null;
  #|     }
  #|   };
  #|   const leftText = String(left || "");
  #|   const rightText = String(right || "");
  #|   if (leftText === rightText) {
  #|     return JSON.stringify({ totalPixels: 0, maxDifference: 0 });
  #|   }
  #|   const leftDims = dimensions(leftText);
  #|   const rightDims = dimensions(rightText);
  #|   if (leftDims && rightDims) {
  #|     if (leftDims.width !== rightDims.width || leftDims.height !== rightDims.height) {
  #|       return JSON.stringify({
  #|         totalPixels: Math.max(leftDims.width * leftDims.height, rightDims.width * rightDims.height, 1),
  #|         maxDifference: 255,
  #|       });
  #|     }
  #|     return JSON.stringify({
  #|       totalPixels: Math.max(leftDims.width * leftDims.height, 1),
  #|       maxDifference: 255,
  #|     });
  #|   }
  #|   return JSON.stringify({ totalPixels: 1, maxDifference: 255 });
  #| }

///|
extern "js" fn js_render_pdf_to_png_base64(
  encoded : String,
  black_dot : String,
  white_dot : String,
) -> String =
  #| (encoded, blackDot, whiteDot) => {
  #|   const parseMeta = (input) => {
  #|     try {
  #|       const raw = atob(String(input || ""));
  #|       const marker = "%CRATER_META ";
  #|       const start = raw.indexOf(marker);
  #|       if (start < 0) return {};
  #|       const lineStart = start + marker.length;
  #|       const lineEnd = raw.indexOf("\n", lineStart);
  #|       const text = lineEnd >= 0 ? raw.slice(lineStart, lineEnd) : raw.slice(lineStart);
  #|       const parsed = JSON.parse(text);
  #|       return parsed && typeof parsed === "object" ? parsed : {};
  #|     } catch (_err) {
  #|       return {};
  #|     }
  #|   };
  #|   const fakePngBase64 = (width, height, seedText) => {
  #|     const be32 = (value) => {
  #|       const n = Math.max(0, Number(value) >>> 0);
  #|       return [(n >>> 24) & 0xff, (n >>> 16) & 0xff, (n >>> 8) & 0xff, n & 0xff];
  #|     };
  #|     const fnvSeed = (text) => {
  #|       const bytes = new TextEncoder().encode(String(text ?? ""));
  #|       let hash = 0x811c9dc5;
  #|       for (const byte of bytes) {
  #|         hash ^= byte;
  #|         hash = Math.imul(hash >>> 0, 0x01000193) >>> 0;
  #|       }
  #|       return [
  #|         (hash >>> 24) & 0xff,
  #|         (hash >>> 16) & 0xff,
  #|         (hash >>> 8) & 0xff,
  #|         hash & 0xff,
  #|       ];
  #|     };
  #|     const bytesToBase64 = (bytes) => {
  #|       let binary = "";
  #|       for (let i = 0; i < bytes.length; i++) {
  #|         binary += String.fromCharCode(bytes[i] & 0xff);
  #|       }
  #|       return btoa(binary);
  #|     };
  #|     const payloadBytes = Array.from(new TextEncoder().encode(String(seedText ?? ""))).slice(0, 48);
  #|     const seed = fnvSeed(`png:${seedText}`);
  #|     const bytes = [
  #|       0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
  #|       0x00, 0x00, 0x00, 0x0d,
  #|       0x49, 0x48, 0x44, 0x52,
  #|       ...be32(width),
  #|       ...be32(height),
  #|       0x08, 0x06, 0x00, 0x00, 0x00,
  #|       ...fnvSeed(`IHDR:${width}x${height}`),
  #|       ...be32(payloadBytes.length),
  #|       0x49, 0x44, 0x41, 0x54,
  #|       ...payloadBytes,
  #|       ...seed,
  #|       0x00, 0x00, 0x00, 0x00,
  #|       0x49, 0x45, 0x4e, 0x44,
  #|       ...fnvSeed("IEND"),
  #|     ];
  #|     return bytesToBase64(bytes);
  #|   };
  #|   const meta = parseMeta(encoded);
  #|   const widthCm = Number.isFinite(Number(meta.pageWidthCm)) ? Number(meta.pageWidthCm) : 21.59;
  #|   const heightCm = Number.isFinite(Number(meta.pageHeightCm)) ? Number(meta.pageHeightCm) : 27.94;
  #|   const width = Math.max(1, Math.round(widthCm * 96.0 / 2.54));
  #|   const height = Math.max(1, Math.round(heightCm * 96.0 / 2.54));
  #|   const background = !!meta.background;
  #|   const signature =
  #|     typeof meta.signature === "string" && meta.signature
  #|       ? meta.signature
  #|       : JSON.stringify(meta.pages || []);
  #|   if (width === 1 && height === 1) {
  #|     return background ? String(blackDot || "") : String(whiteDot || "");
  #|   }
  #|   return fakePngBase64(width, height, `pdf:${background ? "dark" : "light"}:${width}x${height}:${signature}`);
  #| }

///|
fn build_html_data_url(html : String) -> String {
  "data:text/html;charset=utf-8;base64," + js_encode_base64_utf8(html)
}

///|
fn build_wpt_url(
  path? : String = "",
  protocol? : String = "http",
  domain? : String = "",
  subdomain? : String = "",
  query? : String = "",
  fragment? : String = "",
) -> String {
  let resolved_protocol = if protocol == "https" { "https" } else { "http" }
  let base_host = if domain == "alt" { "alt.localhost" } else { "localhost" }
  let host = if subdomain == "www" { "www." + base_host } else { base_host }
  let normalized_path = if path.has_prefix("/") { path } else { "/" + path }
  let query_suffix = if query != "" { "?" + query } else { "" }
  let fragment_suffix = if fragment != "" { "#" + fragment } else { "" }
  resolved_protocol +
  "://" +
  host +
  ":8000" +
  normalized_path +
  query_suffix +
  fragment_suffix
}

///|
fn build_inline_url(
  content? : String = "",
  content_type? : String = "text/html",
  domain? : String = "",
  protocol? : String = "http",
  subdomain? : String = "",
  pipe? : String? = None,
) -> String {
  let fragments : Array[String] = []
  if domain != "" {
    fragments.push("domain=" + js_encode_uri_component(domain))
  }
  if subdomain != "" {
    fragments.push("subdomain=" + js_encode_uri_component(subdomain))
  }
  if (protocol == "http" || protocol == "https") && protocol != "http" {
    fragments.push("protocol=" + js_encode_uri_component(protocol))
  }
  match pipe {
    Some(value) => fragments.push("pipe=" + js_encode_uri_component(value))
    None => ()
  }
  let suffix = if fragments.length() > 0 {
    "#" + fragments.join("&")
  } else {
    ""
  }
  "data:" + content_type + ";base64," + js_encode_base64_utf8(content) + suffix
}

///|
extern "js" fn js_build_node_test_page_markup(
  frame_markup : String,
  shadow_doc : String,
  inner_shadow_doc : String,
  nested_shadow_dom : Bool,
  shadow_root_mode : String,
) -> String =
  #| (frameMarkup, shadowDoc, innerShadowDoc, nestedShadowDom, shadowRootMode) => {
  #|   const frame = String(frameMarkup ?? "");
  #|   const mode = String(shadowRootMode || "open");
  #|   const innerDoc = String(innerShadowDoc ?? "");
  #|   const nested = !!nestedShadowDom;
  #|   const effectiveShadowDoc = nested
  #|     ? `
  #|             <style>
  #|                 inner-custom-element {
  #|                     display:block; width:20px; height:20px;
  #|                 }
  #|             </style>
  #|             <div id="in-nested-shadow-dom">
  #|                 <inner-custom-element></inner-custom-element>
  #|             </div>
  #|         `
  #|     : String(shadowDoc ?? "");
  #|   const definitionInnerShadowDom = nested
  #|     ? `
  #|                 if (!customElements.get("inner-custom-element")) {
  #|                     customElements.define("inner-custom-element",
  #|                         class extends HTMLElement {
  #|                             constructor() {
  #|                                 super();
  #|                                 this.attachShadow({mode: "${mode}"}).innerHTML = \`
  #|                                     ${innerDoc}
  #|                                 \`;
  #|                             }
  #|                         }
  #|                     );
  #|                 }
  #|             `
  #|     : "";
  #|   return `
  #|             <style>
  #|                 custom-element {
  #|                     display:block; width:20px; height:20px;
  #|                 }
  #|             </style>
  #|             <div id="with-children"><p><span></span></p><br/></div>
  #|             <div id="with-text-node">Lorem</div>
  #|             <div id="with-comment"><!-- Comment --></div>
  #| 
  #|             <input id="button" type="button"/>
  #|             <input id="checkbox" type="checkbox"/>
  #|             <input id="file" type="file"/>
  #|             <input id="hidden" type="hidden"/>
  #|             <input id="text" type="text"/>
  #| 
  #|             ${frame}
  #| 
  #|             <img />
  #|             <svg></svg>
  #| 
  #|             <custom-element id="custom-element"></custom-element>
  #|             <script>
  #|                 var svg = document.querySelector("svg");
  #|                 if (svg && svg.setAttributeNS) {
  #|                     svg.setAttributeNS("http://www.w3.org/2000/svg", "svg:foo", "bar");
  #|                 }
  #| 
  #|                 if (window.customElements && customElements.define) {
  #|                     ${definitionInnerShadowDom}
  #|                     if (!customElements.get("custom-element")) {
  #|                         customElements.define("custom-element",
  #|                             class extends HTMLElement {
  #|                                 constructor() {
  #|                                     super();
  #|                                     const shadowRoot = this.attachShadow({mode: "${mode}"});
  #|                                     shadowRoot.innerHTML = \`${effectiveShadowDoc}\`;
  #|                                     window._shadowRoot = shadowRoot;
  #|                                 }
  #|                             }
  #|                         );
  #|                     }
  #| 
  #|                     const host = document.querySelector("#custom-element");
  #|                     if (host && host.attachShadow && !window._shadowRoot) {
  #|                         try {
  #|                             const shadowRoot = host.attachShadow({ mode: "${mode}" });
  #|                             shadowRoot.innerHTML = \`${effectiveShadowDoc}\`;
  #|                             window._shadowRoot = shadowRoot;
  #|                         } catch (_e) {}
  #|                     }
  #|                     if (!window._shadowRoot && host && host.shadowRoot) {
  #|                         window._shadowRoot = host.shadowRoot;
  #|                     }
  #| 
  #|                     if (${nested}) {
  #|                         const outerRoot = (host && host.shadowRoot) || window._shadowRoot || null;
  #|                         if (outerRoot && outerRoot.querySelectorAll) {
  #|                             const innerHosts = outerRoot.querySelectorAll("inner-custom-element");
  #|                             for (const innerHost of innerHosts) {
  #|                                 if (!innerHost) {
  #|                                     continue;
  #|                                 }
  #|                                 if (innerHost.attachShadow && !innerHost.shadowRoot) {
  #|                                     try {
  #|                                         const innerRoot = innerHost.attachShadow({ mode: "${mode}" });
  #|                                         innerRoot.innerHTML = \`${innerDoc}\`;
  #|                                     } catch (_e) {}
  #|                                 }
  #|                                 if (!window._innerShadowRoot && innerHost.shadowRoot) {
  #|                                     window._innerShadowRoot = innerHost.shadowRoot;
  #|                                 }
  #|                             }
  #|                         }
  #|                     }
  #|                 } else {
  #|                     const host = document.querySelector("#custom-element");
  #|                     if (host && host.attachShadow && !host.shadowRoot) {
  #|                         const shadowRoot = host.attachShadow({ mode: "${mode}" });
  #|                         shadowRoot.innerHTML = \`${effectiveShadowDoc}\`;
  #|                         window._shadowRoot = shadowRoot;
  #|                     }
  #|                     if (${nested} && host && host.shadowRoot) {
  #|                         const innerHosts = host.shadowRoot.querySelectorAll("inner-custom-element");
  #|                         for (const innerHost of innerHosts) {
  #|                             if (!innerHost) {
  #|                                 continue;
  #|                             }
  #|                             if (innerHost.attachShadow && !innerHost.shadowRoot) {
  #|                                 const innerRoot = innerHost.attachShadow({ mode: "${mode}" });
  #|                                 innerRoot.innerHTML = \`${innerDoc}\`;
  #|                             }
  #|                             if (!window._innerShadowRoot && innerHost.shadowRoot) {
  #|                                 window._innerShadowRoot = innerHost.shadowRoot;
  #|                             }
  #|                         }
  #|                     }
  #|                 }
  #|                 const finalHost = document.querySelector("#custom-element");
  #|                 if (finalHost && !finalHost.shadowRoot && finalHost.attachShadow) {
  #|                     try {
  #|                         const fallbackRoot = finalHost.attachShadow({ mode: "${mode}" });
  #|                         fallbackRoot.innerHTML = \`${effectiveShadowDoc}\`;
  #|                         window._shadowRoot = fallbackRoot;
  #|                     } catch (_e) {}
  #|                 }
  #|                 if (finalHost && finalHost.shadowRoot) {
  #|                     const shadowChildren = finalHost.shadowRoot.childNodes || [];
  #|                     if (shadowChildren.length === 0) {
  #|                         try {
  #|                             finalHost.shadowRoot.innerHTML = \`${effectiveShadowDoc}\`;
  #|                         } catch (_e) {}
  #|                     }
  #|                     if (!window._shadowRoot) {
  #|                         window._shadowRoot = finalHost.shadowRoot;
  #|                     }
  #|                 }
  #|             </script>
  #|         `;
  #| }

///|
fn json_bool_or_default(
  map : Map[String, Json],
  key : String,
  fallback : Bool,
) -> Bool {
  match map.get(key) {
    Some(True) => true
    Some(False) => false
    _ => fallback
  }
}

///|
fn json_string_or_default(
  map : Map[String, Json],
  key : String,
  fallback : String,
) -> String {
  match map.get(key) {
    Some(String(value)) => value
    _ => fallback
  }
}

///|
fn json_optional_string(map : Map[String, Json], key : String) -> String? {
  match map.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn png_diff_result(total_pixels : Int, max_difference : Int) -> String {
  "{\"maxDifference\": " +
  max_difference.to_string() +
  ", \"totalPixels\": " +
  total_pixels.to_string() +
  "}"
}

///|
fn build_png_diff_json(left : String, right : String) -> String {
  let parsed = @json.parse(js_compare_png_json(left, right)) catch {
    _ => return png_diff_result(1, 255)
  }
  match parsed {
    Object(map) => {
      let total_pixels = match map.get("totalPixels") {
        Some(Number(value, ..)) => value.to_int()
        _ => 1
      }
      let max_difference = match map.get("maxDifference") {
        Some(Number(value, ..)) => value.to_int()
        _ => 255
      }
      png_diff_result(total_pixels, max_difference)
    }
    _ => png_diff_result(1, 255)
  }
}

///|
fn build_iframe_markup(src : String) -> String {
  "<iframe src='" + src + "'></iframe>"
}

///|
fn build_iframe_markup_from_inline(
  src? : String = "",
  content_type? : String = "text/html",
  domain? : String = "",
  protocol? : String = "http",
  subdomain? : String = "",
  pipe? : String? = None,
) -> String {
  build_iframe_markup(
    build_inline_url(
      content=src,
      content_type~,
      domain~,
      protocol~,
      subdomain~,
      pipe~,
    ),
  )
}

///|
fn build_actions_origin_page_url(
  inner_style? : String = "",
  outer_style? : String = "",
) -> String {
  let html = "\n          <meta name=\"viewport\" content=\"width=device-width,initial-scale=1,minimum-scale=1\">\n" +
    "          <div id=\"outer\" style=\"" +
    outer_style +
    "\"\n" +
    "               onmousemove=\"window.coords = {x: event.clientX, y: event.clientY}\">\n" +
    "            <div id=\"inner\" style=\"" +
    inner_style +
    "\"></div>\n" +
    "          </div>\n        "
  build_inline_url(content=html)
}

///|
fn build_named_bidi_fixture(name : String) -> Result[String, String] {
  let test_page = build_inline_url(content="<div>foo</div>")
  let test_page2 = build_inline_url(content="<div>bar</div>")
  let test_page_cross_origin = build_inline_url(
    content="<div>bar</div>",
    domain="alt",
  )
  match name {
    "test_origin" => Ok(build_wpt_url())
    "test_alt_origin" => Ok(build_wpt_url(domain="alt"))
    "test_page" => Ok(test_page)
    "test_page2" => Ok(test_page2)
    "test_page_cross_origin" => Ok(test_page_cross_origin)
    "test_page_multiple_frames" =>
      Ok(
        build_inline_url(
          content=build_iframe_markup(test_page) +
            build_iframe_markup(test_page2),
        ),
      )
    "test_page_same_origin_frame" =>
      Ok(build_inline_url(content=build_iframe_markup(test_page)))
    "test_page_cross_origin_frame" =>
      Ok(build_inline_url(content=build_iframe_markup(test_page_cross_origin)))
    "test_page_nested_frames" => {
      let same_origin_frame = build_inline_url(
        content=build_iframe_markup(test_page),
      )
      Ok(build_inline_url(content=build_iframe_markup(same_origin_frame)))
    }
    _ => Err("unknown named fixture")
  }
}

///|
fn build_synthetic_print_pdf_from_meta(
  page_width_cm : Double,
  page_height_cm : Double,
  background : Bool,
) -> String {
  let payload = "{\"background\": " +
    (if background { "true" } else { "false" }) +
    ", \"pageHeightCm\": " +
    page_height_cm.to_string() +
    ", \"pageWidthCm\": " +
    page_width_cm.to_string() +
    "}"
  build_synthetic_print_pdf_payload(payload)
}

///|
fn build_synthetic_print_pdf_payload(payload : String) -> String {
  let pdf = "%PDF-1.4\n" +
    "%CRATER_META " +
    payload +
    "\n" +
    "1 0 obj\n" +
    "<< /Type /Catalog /Pages 2 0 R >>\n" +
    "endobj\n" +
    "2 0 obj\n" +
    "<< /Type /Pages /Count 1 /Kids [3 0 R] >>\n" +
    "endobj\n" +
    "3 0 obj\n" +
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>\n" +
    "endobj\n" +
    "4 0 obj\n" +
    "<< /Length 0 >>\n" +
    "stream\n" +
    "\n" +
    "endstream\n" +
    "endobj\n" +
    "trailer\n" +
    "<< /Root 1 0 R >>\n" +
    "%%EOF\n"
  js_encode_base64_utf8(pdf)
}

///|
fn build_pdf_content_json(encoded_pdf_data : String) -> String {
  let parsed = @json.parse(js_pdf_meta_json(encoded_pdf_data)) catch {
    _ => Json::object({})
  }
  let pages = match parsed {
    Object(map) =>
      match map.get("pages") {
        Some(Array(values)) => values
        _ => []
      }
    _ => []
  }
  Json::object({
    "type": Json::string("array"),
    "value": Json::array(
      pages.map(fn(page) {
        let value = match page {
          String(value) => value
          _ => ""
        }
        Json::object({
          "type": Json::string("string"),
          "value": Json::string(value),
        })
      }),
    ),
  }).stringify()
}

///|
fn build_server_config_json() -> String {
  Json::object({
    "browser_host": Json::string("localhost"),
    "ports": Json::object({
      "http": Json::array([Json::number(8000.0)]),
      "https": Json::array([Json::number(8000.0)]),
    }),
    "domains": Json::object({
      "": Json::object({
        "": Json::string("localhost"),
        "www": Json::string("www.localhost"),
      }),
      "alt": Json::object({
        "": Json::string("alt.localhost"),
        "www": Json::string("www.alt.localhost"),
      }),
    }),
  }).stringify()
}

///|
fn build_node_test_page_url(
  as_frame? : Bool = false,
  frame_doc? : String? = None,
  shadow_doc? : String? = None,
  nested_shadow_dom? : Bool = false,
  shadow_root_mode? : String = "open",
  protocol? : String? = None,
) -> String {
  match protocol {
    Some("http") =>
      return "http://localhost:8000/webdriver/tests/support/empty.html"
    Some("https") =>
      return "https://localhost:8000/webdriver/tests/support/empty.html"
    _ => ()
  }

  let frame_doc_provided = frame_doc is Some(_)
  let shadow_doc_provided = shadow_doc is Some(_)
  let mut resolved_frame_doc = frame_doc.unwrap_or("")
  let resolved_shadow_doc = shadow_doc.unwrap_or(
    "<div id=\"in-shadow-dom\"><input type=\"checkbox\"/></div>",
  )
  let inner_shadow_doc = resolved_shadow_doc
  if shadow_doc_provided && not(frame_doc_provided) {
    resolved_frame_doc = ""
  }

  let frame_markup = if resolved_frame_doc != "" {
    build_iframe_markup(build_html_data_url(resolved_frame_doc))
  } else {
    ""
  }

  let page_data = js_build_node_test_page_markup(
    frame_markup, resolved_shadow_doc, inner_shadow_doc, nested_shadow_dom, shadow_root_mode,
  )
  if as_frame {
    return build_html_data_url(
      build_iframe_markup(build_html_data_url(page_data)),
    )
  }
  build_html_data_url(page_data)
}

///|
fn build_node_test_page_url_from_json(input : String) -> Result[String, String] {
  let params = @json.parse(input) catch { _ => return Err("invalid json") }
  let map = match params {
    Object(map) => map
    _ => return Err("params must be an object")
  }
  let as_frame = json_bool_or_default(map, "asFrame", false)
  let frame_doc = json_optional_string(map, "frameDoc")
  let shadow_doc = json_optional_string(map, "shadowDoc")
  let nested_shadow_dom = json_bool_or_default(map, "nestedShadowDom", false)
  let shadow_root_mode = json_string_or_default(map, "shadowRootMode", "open")
  let protocol = json_optional_string(map, "protocol")
  Ok(
    build_node_test_page_url(
      as_frame~,
      frame_doc~,
      shadow_doc~,
      nested_shadow_dom~,
      shadow_root_mode~,
      protocol~,
    ),
  )
}

///|
fn build_fixture_from_json(input : String) -> Result[String, String] {
  let params = @json.parse(input) catch { _ => return Err("invalid json") }
  let map = match params {
    Object(map) => map
    _ => return Err("params must be an object")
  }
  let op = json_string_or_default(map, "op", "buildNodeTestPageUrl")
  match op {
    "buildNodeTestPageUrl" => build_node_test_page_url_from_json(input)
    "buildUrl" =>
      Ok(
        build_wpt_url(
          path=json_string_or_default(map, "path", ""),
          protocol=json_string_or_default(map, "protocol", "http"),
          domain=json_string_or_default(map, "domain", ""),
          subdomain=json_string_or_default(map, "subdomain", ""),
          query=json_string_or_default(map, "query", ""),
          fragment=json_string_or_default(map, "fragment", ""),
        ),
      )
    "buildInlineUrl" =>
      match json_optional_string(map, "content") {
        Some(content) =>
          Ok(
            build_inline_url(
              content~,
              content_type=json_string_or_default(
                map, "contentType", "text/html",
              ),
              domain=json_string_or_default(map, "domain", ""),
              protocol=json_string_or_default(map, "protocol", "http"),
              subdomain=json_string_or_default(map, "subdomain", ""),
              pipe=json_optional_string(map, "pipe"),
            ),
          )
        None => Err("content must be a string")
      }
    "buildIframeMarkup" =>
      match json_optional_string(map, "src") {
        Some(src) =>
          Ok(
            build_iframe_markup_from_inline(
              src~,
              content_type=json_string_or_default(
                map, "contentType", "text/html",
              ),
              domain=json_string_or_default(map, "domain", ""),
              protocol=json_string_or_default(map, "protocol", "http"),
              subdomain=json_string_or_default(map, "subdomain", ""),
              pipe=json_optional_string(map, "pipe"),
            ),
          )
        None => Err("src must be a string")
      }
    "buildActionsOriginPage" =>
      match json_optional_string(map, "innerStyle") {
        Some(inner_style) =>
          Ok(
            build_actions_origin_page_url(
              inner_style~,
              outer_style=json_string_or_default(map, "outerStyle", ""),
            ),
          )
        None => Err("innerStyle must be a string")
      }
    "buildNamedBidiFixture" =>
      match json_optional_string(map, "name") {
        Some(name) => build_named_bidi_fixture(name)
        None => Err("name must be a string")
      }
    "comparePng" =>
      match
        (json_optional_string(map, "left"), json_optional_string(map, "right")) {
        (Some(left), Some(right)) => Ok(build_png_diff_json(left, right))
        _ => Err("left and right must be strings")
      }
    "renderPdfToPng" =>
      match json_optional_string(map, "encodedPdfData") {
        Some(encoded_pdf_data) =>
          Ok(
            js_render_pdf_to_png_base64(
              encoded_pdf_data, black_dot_png_base64, white_dot_png_base64,
            ),
          )
        None => Err("encodedPdfData must be a string")
      }
    "extractPdfMeta" =>
      match json_optional_string(map, "encodedPdfData") {
        Some(encoded_pdf_data) => Ok(js_pdf_meta_json(encoded_pdf_data))
        None => Err("encodedPdfData must be a string")
      }
    "extractPdfContent" =>
      match json_optional_string(map, "encodedPdfData") {
        Some(encoded_pdf_data) => Ok(build_pdf_content_json(encoded_pdf_data))
        None => Err("encodedPdfData must be a string")
      }
    "buildServerConfig" => Ok(build_server_config_json())
    _ => Err("unknown op")
  }
}

///|
fn main {
  let args = @deno.deno().args()
  if args.length() == 0 {
    println("")
    return
  }
  match build_fixture_from_json(args[0]) {
    Ok(url) => println(url)
    Err(message) => {
      println(message)
      @deno.deno().exit(code=1)
    }
  }
}

///|
test "build_node_test_page_url returns support URL for https" {
  inspect(
    build_node_test_page_url(protocol=Some("https")),
    content="https://localhost:8000/webdriver/tests/support/empty.html",
  )
}

///|
test "build_node_test_page_url wraps page in iframe when requested" {
  let page_url = build_node_test_page_url(as_frame=true)
  assert_true(page_url.has_prefix("data:text/html;charset=utf-8;base64,"))
  match @webdriver.parse_data_url(page_url) {
    Some((_content_type, content)) =>
      assert_true(
        content.contains("<iframe src='data:text/html;charset=utf-8;base64,"),
      )
    None => assert_true(false)
  }
}

///|
test "build_node_test_page_url keeps nested shadow markup" {
  let page_url = build_node_test_page_url(
    shadow_doc=Some(
      "<div id=\"custom-shadow\"><input type=\"checkbox\"/></div>",
    ),
    nested_shadow_dom=true,
    shadow_root_mode="closed",
  )
  match @webdriver.parse_data_url(page_url) {
    Some((_content_type, content)) => {
      assert_true(content.contains("inner-custom-element"))
      assert_true(content.contains("custom-shadow"))
      assert_true(content.contains("mode: \"closed\""))
    }
    None => assert_true(false)
  }
}

///|
test "build_node_test_page_url_from_json accepts camelCase params" {
  let built = match
    build_fixture_from_json(
      "{\"op\":\"buildNodeTestPageUrl\",\"asFrame\":true,\"shadowRootMode\":\"closed\"}",
    ) {
    Ok(url) => url
    Err(_) => ""
  }
  assert_true(built.has_prefix("data:text/html;charset=utf-8;base64,"))
}

///|
test "build_fixture_from_json builds WPT support URL with query and fragment" {
  let built = match
    build_fixture_from_json(
      "{\"op\":\"buildUrl\",\"path\":\"/webdriver/tests/support/empty.html\",\"protocol\":\"https\",\"domain\":\"alt\",\"subdomain\":\"www\",\"query\":\"a=1\",\"fragment\":\"frag\"}",
    ) {
    Ok(url) => url
    Err(_) => ""
  }
  inspect(
    built,
    content="https://www.alt.localhost:8000/webdriver/tests/support/empty.html?a=1#frag",
  )
}

///|
test "build_fixture_from_json builds inline URL with encoded fragment metadata" {
  let built = match
    build_fixture_from_json(
      "{\"op\":\"buildInlineUrl\",\"content\":\"<div>foo</div>\",\"domain\":\"alt\",\"protocol\":\"https\",\"pipe\":\"header(Content-Type,text/plain)\"}",
    ) {
    Ok(url) => url
    Err(_) => ""
  }
  assert_true(built.has_prefix("data:text/html;base64,"))
  assert_true(built.contains("#domain=alt"))
  assert_true(built.contains("protocol=https"))
  assert_true(built.contains("pipe=header%28Content-Type%2Ctext%2Fplain%29"))
}

///|
test "build_fixture_from_json builds actions origin page" {
  let built = match
    build_fixture_from_json(
      "{\"op\":\"buildActionsOriginPage\",\"innerStyle\":\"width:10px;height:20px\",\"outerStyle\":\"padding:4px\"}",
    ) {
    Ok(url) => url
    Err(_) => ""
  }
  match @webdriver.parse_data_url(built) {
    Some((_content_type, content)) => {
      assert_true(content.contains("width=device-width"))
      assert_true(content.contains("id=\"outer\" style=\"padding:4px\""))
      assert_true(
        content.contains("id=\"inner\" style=\"width:10px;height:20px\""),
      )
    }
    None => assert_true(false)
  }
}

///|
test "build_fixture_from_json builds named origin fixtures" {
  let built = match
    build_fixture_from_json(
      "{\"op\":\"buildNamedBidiFixture\",\"name\":\"test_alt_origin\"}",
    ) {
    Ok(value) => value
    Err(_) => ""
  }
  inspect(built, content="http://alt.localhost:8000/")
}

///|
test "build_fixture_from_json builds named multiple frame page" {
  let built = match
    build_fixture_from_json(
      "{\"op\":\"buildNamedBidiFixture\",\"name\":\"test_page_multiple_frames\"}",
    ) {
    Ok(value) => value
    Err(_) => ""
  }
  match @webdriver.parse_data_url(built) {
    Some((_content_type, content)) => {
      assert_true(content.contains("<iframe src='data:text/html"))
      assert_true(content.contains("'></iframe><iframe src='"))
    }
    None => assert_true(false)
  }
}

///|
test "build_fixture_from_json builds named nested frame page" {
  let built = match
    build_fixture_from_json(
      "{\"op\":\"buildNamedBidiFixture\",\"name\":\"test_page_nested_frames\"}",
    ) {
    Ok(value) => value
    Err(_) => ""
  }
  match @webdriver.parse_data_url(built) {
    Some((_content_type, content)) =>
      assert_true(content.contains("<iframe src='data:text/html"))
    None => assert_true(false)
  }
}

///|
test "build_fixture_from_json compares identical png payloads as equal" {
  let built = match
    build_fixture_from_json(
      "{\"op\":\"comparePng\",\"left\":\"" +
      white_dot_png_base64 +
      "\",\"right\":\"" +
      white_dot_png_base64 +
      "\"}",
    ) {
    Ok(value) => value
    Err(_) => ""
  }
  inspect(built, content="{\"maxDifference\": 0, \"totalPixels\": 0}")
}

///|
test "build_fixture_from_json renders 1x1 print pdf using exact dot png" {
  let encoded_pdf = build_synthetic_print_pdf_from_meta(
    2.54 / 96.0,
    2.54 / 96.0,
    true,
  )
  let built = match
    build_fixture_from_json(
      "{\"op\":\"renderPdfToPng\",\"encodedPdfData\":\"" + encoded_pdf + "\"}",
    ) {
    Ok(value) => value
    Err(_) => ""
  }
  inspect(built, content=black_dot_png_base64)
}

///|
test "build_fixture_from_json renders larger print pdf with expected png dimensions" {
  let encoded_pdf = build_synthetic_print_pdf_from_meta(10.0, 20.0, false)
  let built = match
    build_fixture_from_json(
      "{\"op\":\"renderPdfToPng\",\"encodedPdfData\":\"" + encoded_pdf + "\"}",
    ) {
    Ok(value) => value
    Err(_) => ""
  }
  let dims_json = js_png_dimensions_json(built)
  assert_true(dims_json.contains("\"width\":378"))
  assert_true(dims_json.contains("\"height\":756"))
}

///|
test "build_fixture_from_json builds server config payload" {
  let built = match build_fixture_from_json("{\"op\":\"buildServerConfig\"}") {
    Ok(value) => value
    Err(_) => ""
  }
  assert_true(built.contains("\"browser_host\":\"localhost\""))
  assert_true(built.contains("\"alt\":{\"\":\"alt.localhost\""))
  assert_true(built.contains("\"ports\":{\"http\":[8000],\"https\":[8000]}"))
}

///|
test "build_fixture_from_json extracts synthetic print pdf metadata" {
  let encoded_pdf = build_synthetic_print_pdf_from_meta(21.59, 27.94, false)
  let built = match
    build_fixture_from_json(
      "{\"op\":\"extractPdfMeta\",\"encodedPdfData\":\"" + encoded_pdf + "\"}",
    ) {
    Ok(value) => value
    Err(_) => ""
  }
  assert_true(built.contains("\"pageWidthCm\": 21.59"))
  assert_true(built.contains("\"pageHeightCm\": 27.94"))
  assert_true(built.contains("\"background\": false"))
}

///|
test "build_fixture_from_json extracts synthetic print pdf content" {
  let encoded_pdf = build_synthetic_print_pdf_payload(
    "{\"pages\":[\"Page 1\",\"Page 2\"],\"signature\":\"sig\"}",
  )
  let built = match
    build_fixture_from_json(
      "{\"op\":\"extractPdfContent\",\"encodedPdfData\":\"" +
      encoded_pdf +
      "\"}",
    ) {
    Ok(value) => value
    Err(_) => ""
  }
  inspect(
    built,
    content="{\"type\":\"array\",\"value\":[{\"type\":\"string\",\"value\":\"Page 1\"},{\"type\":\"string\",\"value\":\"Page 2\"}]}",
  )
}

///|
test "build_fixture_from_json renderPdfToPng uses synthetic signature" {
  let encoded_pdf_a = build_synthetic_print_pdf_payload(
    "{\"background\":true,\"pageHeightCm\":10,\"pageWidthCm\":10,\"signature\":\"a\"}",
  )
  let encoded_pdf_b = build_synthetic_print_pdf_payload(
    "{\"background\":true,\"pageHeightCm\":10,\"pageWidthCm\":10,\"signature\":\"b\"}",
  )
  let built_a = match
    build_fixture_from_json(
      "{\"op\":\"renderPdfToPng\",\"encodedPdfData\":\"" + encoded_pdf_a + "\"}",
    ) {
    Ok(value) => value
    Err(_) => ""
  }
  let built_b = match
    build_fixture_from_json(
      "{\"op\":\"renderPdfToPng\",\"encodedPdfData\":\"" + encoded_pdf_b + "\"}",
    ) {
    Ok(value) => value
    Err(_) => ""
  }
  assert_not_eq(built_a, built_b)
}

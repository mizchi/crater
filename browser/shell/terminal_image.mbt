///|
fn stable_kitty_id(seed : String) -> Int {
  let mut hash = 5381
  let modulus = 16777213
  for c in seed {
    hash = (hash * 131 + c.to_int()) % modulus
  }
  (hash + 1).max(1)
}

///|
fn kitty_image_id_for_src(src : String) -> Int {
  stable_kitty_id("image:" + src)
}

///|
fn kitty_placement_id_for_source(source_id : String) -> Int {
  stable_kitty_id("placement:" + source_id)
}

///|
fn current_kitty_placement(region : @tui.ImageRegion) -> KittyPlacement {
  let image_id = kitty_image_id_for_src(region.src)
  let placement_id = kitty_placement_id_for_source(region.source_id)
  {
    image_id,
    placement_id,
    col: region.col,
    row: region.row,
    width: region.width,
    height: region.height,
  }
}

///|
fn same_kitty_placement(lhs : KittyPlacement, rhs : KittyPlacement) -> Bool {
  lhs.image_id == rhs.image_id &&
  lhs.placement_id == rhs.placement_id &&
  lhs.col == rhs.col &&
  lhs.row == rhs.row &&
  lhs.width == rhs.width &&
  lhs.height == rhs.height
}

///|
/// Build kitty graphics overlay commands for image regions
fn Browser::build_kitty_image_overlay(self : Browser) -> String {
  let next_visible : Map[String, KittyPlacement] = {}
  let render_specs : Array[KittyRenderSpec] = []
  for region in self.image_regions {
    match self.image_cache.get(region.src) {
      Some(cached_data) => {
        let placement = current_kitty_placement(region)
        next_visible.set(region.source_id, placement)
        render_specs.push({ region, cached_data, placement })
      }
      None => ()
    }
  }
  if next_visible.is_empty() && self.kitty_visible_placements.is_empty() {
    return ""
  }
  let buf = StringBuilder::new()
  for source_id, previous in self.kitty_visible_placements {
    match next_visible.get(source_id) {
      Some(current) if current.image_id == previous.image_id => ()
      _ =>
        buf.write_string(
          @painter_terminal.encode_kitty_delete_placement(
            previous.image_id,
            previous.placement_id,
          ),
        )
    }
  }
  for spec in render_specs {
    let placement_key = spec.region.source_id
    let uploaded = self.kitty_uploaded_image_ids.contains(
      spec.placement.image_id,
    )
    let previous = self.kitty_visible_placements.get(placement_key)
    let unchanged = match previous {
      Some(prev) => same_kitty_placement(prev, spec.placement)
      None => false
    }
    if uploaded && unchanged {
      continue
    }
    buf.write_string(
      "\u001b[" +
      (spec.region.row + 1).to_string() +
      ";" +
      (spec.region.col + 1).to_string() +
      "H",
    )
    let kitty_data = if uploaded {
      @painter_terminal.encode_kitty_put_placement(
        spec.placement.image_id,
        spec.placement.placement_id,
        spec.placement.width,
        spec.placement.height,
      )
    } else {
      render_cached_kitty_image_with_placement(
        spec.cached_data,
        spec.region,
        spec.placement.image_id,
        spec.placement.placement_id,
      )
    }
    if kitty_data.length() > 0 {
      buf.write_string(kitty_data)
      self.kitty_uploaded_image_ids.set(spec.placement.image_id, true)
    }
  }
  self.kitty_visible_placements = next_visible
  buf.to_string()
}

///|
fn Browser::cache_image_data(
  self : Browser,
  src : String,
  data : String,
) -> Unit {
  self.image_cache.put(src, data)
}

///|
/// Prefetch images from HTML and cache rendered kitty graphics data
async fn Browser::prefetch_images(self : Browser) -> Unit {
  if self.html_content.length() == 0 {
    return
  }
  let srcs = extract_img_srcs(self.html_content)
  for src in srcs {
    if self.image_cache.contains(src) {
      continue
    }
    if self.cache_data_image_src(src) {
      continue
    }
    if src.to_lower().has_prefix("data:") {
      continue
    }
    let abs_url = resolve_url(self.current_url, src)
    if abs_url.length() == 0 {
      continue
    }
    let body = try {
      let options = {
        ..@http.FetchOptions::default(),
        sandbox: self.request_sandbox,
      }
      let response = @http_cache.cached_fetch_async(
        url=abs_url,
        options~,
        cache=self.profile.http_cache,
        fetcher=http_fetch_adapter,
      )
      response.body
    } catch {
      _ => continue
    }
    if body.length() == 0 {
      continue
    }
    let is_svg = abs_url.to_lower().has_suffix(".svg") ||
      abs_url.to_lower().contains(".svg?")
    if is_svg {
      self.cache_image_data(src, "svg:" + body)
    } else if body.has_prefix("base64:") {
      let b64 = body.unsafe_substring(start=7, end=body.length())
      self.cache_image_data(
        src,
        @terminal_image_cache.prepare_raster_image_for_kitty_cache(b64),
      )
    }
  }
}

///|
fn Browser::cache_data_image_src(self : Browser, src : String) -> Bool {
  match @terminal_image_cache.data_image_src_to_kitty_cache(src) {
    Some(cached_data) => {
      self.cache_image_data(src, cached_data)
      true
    }
    None => false
  }
}

///|
fn rgba_cache_entry_to_resolved_image(
  entry : @terminal_image_cache.RgbaCacheEntry,
) -> @raster.ResolvedImage? {
  match entry.decode_rgba_bytes() {
    Some(rgba) =>
      if rgba.length() >= entry.width * entry.height * 4 {
        Some(
          @raster.ResolvedImage::Raster({
            width: entry.width,
            height: entry.height,
            rgba,
          }),
        )
      } else {
        None
      }
    None => None
  }
}

///|
fn raster_base64_to_resolved_image(
  image_format : String,
  b64_data : String,
) -> @raster.ResolvedImage? {
  match
    @terminal_image_cache.decode_raster_image_to_rgba_cache_entry(
      image_format, b64_data,
    ) {
    Some(entry) => rgba_cache_entry_to_resolved_image(entry)
    None => None
  }
}

///|
fn cached_image_data_to_resolved_image(
  cached_data : String,
) -> @raster.ResolvedImage? {
  match @terminal_image_cache.parse_terminal_image_cache_entry(cached_data) {
    Some(@terminal_image_cache.TerminalImageCacheEntry::Svg(svg_text)) =>
      Some(@raster.ResolvedImage::Svg(svg_text))
    Some(@terminal_image_cache.TerminalImageCacheEntry::RgbaBase64(entry)) =>
      rgba_cache_entry_to_resolved_image(entry)
    Some(@terminal_image_cache.TerminalImageCacheEntry::PngBase64(b64_data)) =>
      raster_base64_to_resolved_image("png", b64_data)
    Some(@terminal_image_cache.TerminalImageCacheEntry::RawBase64(b64_data)) =>
      raster_base64_to_resolved_image(
        @terminal_image_cache.detect_raster_image_format_from_base64(b64_data),
        b64_data,
      )
    None => None
  }
}

///|
fn Browser::install_sixel_image_provider(self : Browser) -> Bool {
  if self.image_cache.is_empty() {
    return false
  }
  @raster.set_image_provider({
    resolve: fn(src) {
      match self.image_cache.get(src) {
        Some(cached_data) => cached_image_data_to_resolved_image(cached_data)
        None => None
      }
    },
  })
  true
}

///|
/// Extract img src attributes from HTML (lightweight, no full parsing)
fn extract_img_srcs(html : String) -> Array[String] {
  @html_assets.extract_img_srcs(html)
}

///|
fn render_cached_kitty_image_with_placement(
  cached_data : String,
  region : @tui.ImageRegion,
  image_id : Int,
  placement_id : Int,
) -> String {
  match @terminal_image_cache.parse_terminal_image_cache_entry(cached_data) {
    Some(@terminal_image_cache.TerminalImageCacheEntry::Svg(svg_text)) => {
      let render_w = region.width * 16
      let render_h = region.height * 32
      @painter_terminal.render_svg_text_to_kitty_cells(
        svg_text,
        render_w,
        render_h,
        region.width,
        region.height,
        image_id~,
        placement_id~,
      )
    }
    Some(@terminal_image_cache.TerminalImageCacheEntry::PngBase64(b64_data)) =>
      @painter_terminal.encode_png_base64_to_kitty_image(
        b64_data,
        region.width,
        region.height,
        image_id~,
        placement_id~,
      )
    Some(@terminal_image_cache.TerminalImageCacheEntry::RgbaBase64(entry)) =>
      @painter_terminal.encode_rgba_base64_to_kitty_image(
        entry.rgba_base64,
        entry.width,
        entry.height,
        region.width,
        region.height,
        image_id~,
        placement_id~,
      )
    Some(@terminal_image_cache.TerminalImageCacheEntry::RawBase64(b64_data)) =>
      @painter_terminal.encode_png_base64_to_kitty_image(
        @terminal_image_cache.normalize_raster_image_for_kitty(b64_data),
        region.width,
        region.height,
        image_id~,
        placement_id~,
      )
    None => ""
  }
}

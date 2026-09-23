///|
/// Record / replay of the external text-measurement side effect.
///
/// Text intrinsic sizing is the one non-deterministic, non-portable input to a
/// render: it crosses into whatever font engine is wired through the
/// TextMetricsProvider. Recording captures every `(text, font, …, available
/// size) -> IntrinsicSize` result a render observed; replaying serves those
/// results back without calling the provider, so the render is fully
/// deterministic and reproducible anywhere (e.g. a VRT snapshot replayed on a
/// machine with no font engine). See create_text_measure_with_provider, which
/// routes its result through record_replay_text_measure.

///|
/// A single recorded measurement: the encoded measurement key and its result.
pub(all) struct RecordedMetric {
  key : String
  min_width : Double
  max_width : Double
  min_height : Double
  max_height : Double
}

///|
/// When Some, every measurement is appended here (recording mode).
let measurement_record_buffer : Ref[Array[RecordedMetric]?] = { val: None }

///|
/// When Some, measurements are served from here (replay mode); a miss falls
/// back to the live measure func.
let measurement_replay_table : Ref[Map[String, @layout_types.IntrinsicSize]?] = {
  val: None,
}

///|
/// Field separator unlikely to appear in CSS text / font names.
let measurement_key_sep : String = "\u{0001}"

///|
fn white_space_key(ws : @style.WhiteSpace) -> String {
  match ws {
    @style.WhiteSpace::Normal => "n"
    @style.WhiteSpace::Nowrap => "w"
    @style.WhiteSpace::Pre => "p"
    @style.WhiteSpace::PreWrap => "pw"
    @style.WhiteSpace::PreLine => "pl"
  }
}

///|
fn writing_mode_key(wm : @style.WritingMode) -> String {
  match wm {
    @style.WritingMode::HorizontalTb => "h"
    @style.WritingMode::VerticalRl => "vr"
    @style.WritingMode::VerticalLr => "vl"
  }
}

///|
/// Encode the measurement inputs (everything the result depends on except the
/// available size, which is appended per call) into a stable key prefix.
fn measurement_key_prefix(
  text : String,
  font_size : Double,
  line_height : Double,
  white_space : @style.WhiteSpace,
  writing_mode : @style.WritingMode,
  font_weight : Double,
  font_family : String,
) -> String {
  let s = measurement_key_sep
  text +
  s +
  font_size.to_string() +
  s +
  line_height.to_string() +
  s +
  white_space_key(white_space) +
  s +
  writing_mode_key(writing_mode) +
  s +
  font_weight.to_string() +
  s +
  font_family
}

///|
/// Wrap a measure func so its results are recorded or replayed when those modes
/// are active; otherwise return it unchanged (the common, zero-overhead path).
/// `prefix` is the per-input key from measurement_key_prefix.
fn record_replay_text_measure(
  prefix : String,
  inner : @layout_types.MeasureFunc,
) -> @layout_types.MeasureFunc {
  match measurement_replay_table.val {
    Some(table) => {
      let sep = measurement_key_sep
      let replayed : @layout_types.MeasureFunc = {
        func: fn(available_width, available_height) {
          let key = prefix +
            sep +
            available_width.to_string() +
            sep +
            available_height.to_string()
          match table.get(key) {
            Some(result) => result
            // Unknown measurement (recording incomplete): fall back to live.
            None => (inner.func)(available_width, available_height)
          }
        },
      }
      replayed
    }
    None =>
      match measurement_record_buffer.val {
        Some(buffer) => {
          let sep = measurement_key_sep
          let recording : @layout_types.MeasureFunc = {
            func: fn(available_width, available_height) {
              let result = (inner.func)(available_width, available_height)
              let key = prefix +
                sep +
                available_width.to_string() +
                sep +
                available_height.to_string()
              buffer.push({
                key,
                min_width: result.min_width,
                max_width: result.max_width,
                min_height: result.min_height,
                max_height: result.max_height,
              })
              result
            },
          }
          recording
        }
        None => inner
      }
  }
}

///|
/// Begin recording text measurements. Clears any active replay.
pub fn start_text_metrics_recording() -> Unit {
  measurement_record_buffer.val = Some([])
  measurement_replay_table.val = None
}

///|
/// Stop recording and return everything captured since start.
pub fn take_text_metrics_recording() -> Array[RecordedMetric] {
  let recorded = match measurement_record_buffer.val {
    Some(buffer) => buffer
    None => []
  }
  measurement_record_buffer.val = None
  recorded
}

///|
/// Serve text measurements from `metrics` (replay mode); a measurement not in
/// the recording falls back to the live measure func. Clears any active
/// recording.
pub fn install_text_metrics_replay(metrics : Array[RecordedMetric]) -> Unit {
  let table : Map[String, @layout_types.IntrinsicSize] = {}
  for m in metrics {
    let size : @layout_types.IntrinsicSize = {
      min_width: m.min_width,
      max_width: m.max_width,
      min_height: m.min_height,
      max_height: m.max_height,
    }
    table[m.key] = size
  }
  measurement_replay_table.val = Some(table)
  measurement_record_buffer.val = None
}

///|
/// Disable both recording and replay.
pub fn clear_text_metrics_record_replay() -> Unit {
  measurement_record_buffer.val = None
  measurement_replay_table.val = None
}

///|
/// Serialize a recording to a self-delimiting string (length-prefixed keys, so
/// arbitrary text/newlines in keys round-trip safely).
pub fn serialize_text_metrics_recording(
  metrics : Array[RecordedMetric],
) -> String {
  let buf = StringBuilder::new()
  buf.write_string(metrics.length().to_string())
  buf.write_char('\n')
  for m in metrics {
    buf.write_string(m.min_width.to_string())
    buf.write_char(' ')
    buf.write_string(m.max_width.to_string())
    buf.write_char(' ')
    buf.write_string(m.min_height.to_string())
    buf.write_char(' ')
    buf.write_string(m.max_height.to_string())
    buf.write_char(' ')
    buf.write_string(m.key.length().to_string())
    buf.write_char(':')
    buf.write_string(m.key)
  }
  buf.to_string()
}

///|
/// Parse a recording produced by serialize_text_metrics_recording.
pub fn deserialize_text_metrics_recording(
  data : String,
) -> Array[RecordedMetric] {
  let result : Array[RecordedMetric] = []
  let len = data.length()
  let mut i = 0
  fn unit_at(idx : Int) -> Int {
    data[idx].to_int()
  }
  let nl = '\n'.to_int()
  let sp = ' '.to_int()
  let colon = ':'.to_int()
  // Read the leading count line (used only as a header; parsing is driven by
  // the per-record length prefixes).
  while i < len && unit_at(i) != nl {
    i = i + 1
  }
  i = i + 1 // skip the newline
  fn read_until(stop : Int) -> String {
    let start = i
    while i < len && unit_at(i) != stop {
      i = i + 1
    }
    let s = data[start:i].to_owned()
    i = i + 1 // consume stop
    s
  }
  while i < len {
    let mw = @string.parse_double(read_until(sp)) catch { _ => 0.0 }
    let xw = @string.parse_double(read_until(sp)) catch { _ => 0.0 }
    let mh = @string.parse_double(read_until(sp)) catch { _ => 0.0 }
    let xh = @string.parse_double(read_until(sp)) catch { _ => 0.0 }
    let key_len = @string.parse_int(read_until(colon)) catch { _ => 0 }
    let key = data[i:i + key_len].to_owned()
    i = i + key_len
    result.push({
      key,
      min_width: mw,
      max_width: xw,
      min_height: mh,
      max_height: xh,
    })
  }
  result
}

///|
/// A single recorded image intrinsic size lookup: the source and its result
/// (`has_size = false` records a provider that returned "no intrinsic size").
pub(all) struct RecordedImage {
  src : String
  has_size : Bool
  width : Double
  height : Double
}

///|
let image_record_buffer : Ref[Array[RecordedImage]?] = { val: None }

///|
let image_replay_table : Ref[Map[String, (Double, Double)?]?] = { val: None }

///|
/// Resolve an image intrinsic size through the record/replay layer. Returns
/// `Some(replayed)` to short-circuit the live resolver during replay; otherwise
/// `None` and the caller resolves live (recording observes the live result via
/// note_image_intrinsic_result).
fn image_intrinsic_replay(src : String) -> (Double, Double)?? {
  match image_replay_table.val {
    Some(table) =>
      match table.get(src) {
        Some(recorded) => Some(recorded) // hit (may itself be None = "no size")
        None => None // miss: fall back to live
      }
    None => None
  }
}

///|
/// Record the (live) result of an image intrinsic size lookup when recording.
fn note_image_intrinsic_result(
  src : String,
  result : (Double, Double)?,
) -> Unit {
  match image_record_buffer.val {
    Some(buffer) =>
      match result {
        Some((w, h)) =>
          buffer.push({ src, has_size: true, width: w, height: h })
        None => buffer.push({ src, has_size: false, width: 0.0, height: 0.0 })
      }
    None => ()
  }
}

///|
/// Begin recording image intrinsic sizes. Clears any active image replay.
pub fn start_image_intrinsic_recording() -> Unit {
  image_record_buffer.val = Some([])
  image_replay_table.val = None
}

///|
pub fn take_image_intrinsic_recording() -> Array[RecordedImage] {
  let recorded = match image_record_buffer.val {
    Some(buffer) => buffer
    None => []
  }
  image_record_buffer.val = None
  recorded
}

///|
pub fn install_image_intrinsic_replay(images : Array[RecordedImage]) -> Unit {
  let table : Map[String, (Double, Double)?] = {}
  for im in images {
    table[im.src] = if im.has_size { Some((im.width, im.height)) } else { None }
  }
  image_replay_table.val = Some(table)
  image_record_buffer.val = None
}

///|
pub fn clear_image_intrinsic_record_replay() -> Unit {
  image_record_buffer.val = None
  image_replay_table.val = None
}

///|
/// Serialize image recordings (length-prefixed src, so any URL round-trips).
pub fn serialize_image_intrinsic_recording(
  images : Array[RecordedImage],
) -> String {
  let buf = StringBuilder::new()
  buf.write_string(images.length().to_string())
  buf.write_char('\n')
  for im in images {
    buf.write_string(if im.has_size { "1" } else { "0" })
    buf.write_char(' ')
    buf.write_string(im.width.to_string())
    buf.write_char(' ')
    buf.write_string(im.height.to_string())
    buf.write_char(' ')
    buf.write_string(im.src.length().to_string())
    buf.write_char(':')
    buf.write_string(im.src)
  }
  buf.to_string()
}

///|
pub fn deserialize_image_intrinsic_recording(
  data : String,
) -> Array[RecordedImage] {
  let result : Array[RecordedImage] = []
  let len = data.length()
  let mut i = 0
  fn unit_at(idx : Int) -> Int {
    data[idx].to_int()
  }
  let nl = '\n'.to_int()
  let sp = ' '.to_int()
  let colon = ':'.to_int()
  while i < len && unit_at(i) != nl {
    i = i + 1
  }
  i = i + 1
  fn read_until(stop : Int) -> String {
    let start = i
    while i < len && unit_at(i) != stop {
      i = i + 1
    }
    let s = data[start:i].to_owned()
    i = i + 1
    s
  }
  while i < len {
    let has = read_until(sp) == "1"
    let w = @string.parse_double(read_until(sp)) catch { _ => 0.0 }
    let h = @string.parse_double(read_until(sp)) catch { _ => 0.0 }
    let src_len = @string.parse_int(read_until(colon)) catch { _ => 0 }
    let src = data[i:i + src_len].to_owned()
    i = i + src_len
    result.push({ src, has_size: has, width: w, height: h })
  }
  result
}

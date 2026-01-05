///|
/// CSS Diagnostics Collector
/// Collects and aggregates CSS parsing diagnostics

///|
/// A single diagnostic entry
pub(all) struct Diagnostic {
  property : String
  value : String
  level : SupportLevel
  severity : Severity
  selector : String // selector context where this appeared
}

///|
pub impl Show for Diagnostic with output(self, logger) {
  logger.write_string("[")
  self.severity.output(logger)
  logger.write_string("] ")
  logger.write_string(self.property)
  logger.write_string(": ")
  logger.write_string(self.value)
  logger.write_string(" (")
  self.level.output(logger)
  logger.write_string(")")
}

///|
/// Summary statistics for diagnostics
pub(all) struct DiagnosticSummary {
  total_properties : Int
  supported : Int
  partial : Int
  unsupported_layout : Int
  unsupported_visual : Int
  deprecated : Int
  unknown : Int
}

///|
pub impl Show for DiagnosticSummary with output(self, logger) {
  logger.write_string("CSS Diagnostics Summary:\n")
  logger.write_string("  Total: ")
  self.total_properties.output(logger)
  logger.write_string("\n  Supported: ")
  self.supported.output(logger)
  logger.write_string("\n  Partial: ")
  self.partial.output(logger)
  logger.write_string("\n  Unsupported (layout): ")
  self.unsupported_layout.output(logger)
  logger.write_string("\n  Unsupported (visual): ")
  self.unsupported_visual.output(logger)
  logger.write_string("\n  Deprecated: ")
  self.deprecated.output(logger)
  logger.write_string("\n  Unknown: ")
  self.unknown.output(logger)
}

///|
/// Collector for CSS diagnostics
pub struct DiagnosticsCollector {
  diagnostics : Array[Diagnostic]
  // Track unique property+value combinations to avoid duplicates
  seen : Map[String, Bool]
  // Count by support level
  mut supported_count : Int
  mut partial_count : Int
  mut unsupported_layout_count : Int
  mut unsupported_visual_count : Int
  mut deprecated_count : Int
  mut unknown_count : Int
}

///|
/// Create a new diagnostics collector
pub fn DiagnosticsCollector::new() -> DiagnosticsCollector {
  {
    diagnostics: [],
    seen: {},
    supported_count: 0,
    partial_count: 0,
    unsupported_layout_count: 0,
    unsupported_visual_count: 0,
    deprecated_count: 0,
    unknown_count: 0,
  }
}

///|
/// Add a property to the collector
pub fn DiagnosticsCollector::add_property(
  self : DiagnosticsCollector,
  property : String,
  value : String,
  selector : String,
) -> Unit {
  let level = get_support_level(property)
  let severity = support_to_severity(level)
  // Update counts
  match level {
    Supported => self.supported_count += 1
    Partial(_) => self.partial_count += 1
    UnsupportedLayout => self.unsupported_layout_count += 1
    UnsupportedVisual => self.unsupported_visual_count += 1
    Deprecated(_) => self.deprecated_count += 1
    Unknown => self.unknown_count += 1
  }
  // Only store non-supported properties to save memory
  if should_warn(level) {
    let key = property + ":" + value
    // Deduplicate
    if not(self.seen.contains(key)) {
      self.seen.set(key, true)
      self.diagnostics.push({ property, value, level, severity, selector })
    }
  }
}

///|
/// Get summary statistics
pub fn DiagnosticsCollector::get_summary(
  self : DiagnosticsCollector,
) -> DiagnosticSummary {
  {
    total_properties: self.supported_count +
    self.partial_count +
    self.unsupported_layout_count +
    self.unsupported_visual_count +
    self.deprecated_count +
    self.unknown_count,
    supported: self.supported_count,
    partial: self.partial_count,
    unsupported_layout: self.unsupported_layout_count,
    unsupported_visual: self.unsupported_visual_count,
    deprecated: self.deprecated_count,
    unknown: self.unknown_count,
  }
}

///|
/// Get all diagnostics
pub fn DiagnosticsCollector::get_diagnostics(
  self : DiagnosticsCollector,
) -> Array[Diagnostic] {
  self.diagnostics
}

///|
/// Get diagnostics filtered by severity
pub fn DiagnosticsCollector::get_by_severity(
  self : DiagnosticsCollector,
  severity : Severity,
) -> Array[Diagnostic] {
  let result : Array[Diagnostic] = []
  for diag in self.diagnostics {
    let matches = match (diag.severity, severity) {
      (Info, Info) => true
      (Warning, Warning) => true
      (Error, Error) => true
      _ => false
    }
    if matches {
      result.push(diag)
    }
  }
  result
}

///|
/// Get diagnostics that affect layout
pub fn DiagnosticsCollector::get_layout_affecting(
  self : DiagnosticsCollector,
) -> Array[Diagnostic] {
  let result : Array[Diagnostic] = []
  for diag in self.diagnostics {
    if affects_layout(diag.level) {
      result.push(diag)
    }
  }
  result
}

///|
/// Format diagnostics as a string report
pub fn DiagnosticsCollector::format_report(
  self : DiagnosticsCollector,
  max_entries : Int,
) -> String {
  let buf = StringBuilder::new()
  let summary = self.get_summary()
  // Header
  buf.write_string("=== CSS Support Report ===\n")
  buf.write_string("Total properties: ")
  buf.write_string(summary.total_properties.to_string())
  buf.write_string("\n")
  // Summary
  buf.write_string("  Supported: ")
  buf.write_string(summary.supported.to_string())
  buf.write_string("\n")
  if summary.partial > 0 {
    buf.write_string("  Partial: ")
    buf.write_string(summary.partial.to_string())
    buf.write_string("\n")
  }
  if summary.unsupported_visual > 0 {
    buf.write_string("  Unsupported (visual): ")
    buf.write_string(summary.unsupported_visual.to_string())
    buf.write_string("\n")
  }
  if summary.unsupported_layout > 0 {
    buf.write_string("  Unsupported (layout): ")
    buf.write_string(summary.unsupported_layout.to_string())
    buf.write_string(" [WARNING]\n")
  }
  if summary.deprecated > 0 {
    buf.write_string("  Deprecated: ")
    buf.write_string(summary.deprecated.to_string())
    buf.write_string("\n")
  }
  if summary.unknown > 0 {
    buf.write_string("  Unknown: ")
    buf.write_string(summary.unknown.to_string())
    buf.write_string(" [ERROR]\n")
  }
  // Layout-affecting issues (most important)
  let layout_issues = self.get_layout_affecting()
  if layout_issues.length() > 0 {
    buf.write_string("\n--- Layout-affecting issues ---\n")
    let count = if layout_issues.length() > max_entries {
      max_entries
    } else {
      layout_issues.length()
    }
    for i = 0; i < count; i = i + 1 {
      let diag = layout_issues[i]
      buf.write_string("  ")
      buf.write_string(diag.property)
      buf.write_string(": ")
      buf.write_string(diag.value)
      buf.write_string("\n")
    }
    if layout_issues.length() > max_entries {
      buf.write_string("  ... and ")
      buf.write_string((layout_issues.length() - max_entries).to_string())
      buf.write_string(" more\n")
    }
  }
  // Unknown properties (errors)
  let errors = self.get_by_severity(Error)
  if errors.length() > 0 {
    buf.write_string("\n--- Unknown properties ---\n")
    let count = if errors.length() > max_entries {
      max_entries
    } else {
      errors.length()
    }
    for i = 0; i < count; i = i + 1 {
      let diag = errors[i]
      buf.write_string("  ")
      buf.write_string(diag.property)
      buf.write_string(": ")
      buf.write_string(diag.value)
      buf.write_string("\n")
    }
    if errors.length() > max_entries {
      buf.write_string("  ... and ")
      buf.write_string((errors.length() - max_entries).to_string())
      buf.write_string(" more\n")
    }
  }
  buf.to_string()
}

///|
/// Format a compact one-line summary
pub fn DiagnosticsCollector::format_compact(
  self : DiagnosticsCollector,
) -> String {
  let summary = self.get_summary()
  let buf = StringBuilder::new()
  buf.write_string("CSS: ")
  buf.write_string(summary.supported.to_string())
  buf.write_string(" ok")
  if summary.partial > 0 {
    buf.write_string(", ")
    buf.write_string(summary.partial.to_string())
    buf.write_string(" partial")
  }
  if summary.unsupported_visual > 0 {
    buf.write_string(", ")
    buf.write_string(summary.unsupported_visual.to_string())
    buf.write_string(" visual-only")
  }
  if summary.unsupported_layout > 0 {
    buf.write_string(", ")
    buf.write_string(summary.unsupported_layout.to_string())
    buf.write_string(" layout!")
  }
  if summary.unknown > 0 {
    buf.write_string(", ")
    buf.write_string(summary.unknown.to_string())
    buf.write_string(" unknown!")
  }
  buf.to_string()
}

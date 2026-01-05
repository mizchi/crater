///|
/// CSS Property Support Level
/// Defines how well a CSS property is supported by the layout engine

///|
/// Support level for a CSS property
pub(all) enum SupportLevel {
  /// Fully supported - property is parsed and applied correctly
  Supported
  /// Partially supported - some values may not work
  Partial(String) // reason
  /// Not supported but affects layout - may cause incorrect rendering
  UnsupportedLayout
  /// Not supported but does not affect layout (visual-only properties)
  UnsupportedVisual
  /// CSS property is deprecated
  Deprecated(String) // replacement
  /// Unknown property (possibly typo or vendor prefix)
  Unknown
}

///|
pub impl Show for SupportLevel with output(self, logger) {
  match self {
    Supported => logger.write_string("Supported")
    Partial(reason) => {
      logger.write_string("Partial(")
      logger.write_string(reason)
      logger.write_string(")")
    }
    UnsupportedLayout => logger.write_string("UnsupportedLayout")
    UnsupportedVisual => logger.write_string("UnsupportedVisual")
    Deprecated(replacement) => {
      logger.write_string("Deprecated(use ")
      logger.write_string(replacement)
      logger.write_string(")")
    }
    Unknown => logger.write_string("Unknown")
  }
}

///|
/// Severity level for diagnostics
pub(all) enum Severity {
  /// Informational - property works but has limitations
  Info
  /// Warning - property may not work as expected
  Warning
  /// Error - property will definitely not work correctly
  Error
}

///|
pub impl Show for Severity with output(self, logger) {
  match self {
    Info => logger.write_string("Info")
    Warning => logger.write_string("Warning")
    Error => logger.write_string("Error")
  }
}

///|
/// Get support level for a CSS property
pub fn get_support_level(property : String) -> SupportLevel {
  let prop = property.to_lower()
  match prop {
    // === FULLY SUPPORTED - Layout Properties ===
    // Display
    "display" => Supported
    // Box Model
    "width"
    | "height"
    | "min-width"
    | "min-height"
    | "max-width"
    | "max-height" => Supported
    "margin"
    | "margin-top"
    | "margin-right"
    | "margin-bottom"
    | "margin-left" => Supported
    "padding"
    | "padding-top"
    | "padding-right"
    | "padding-bottom"
    | "padding-left" => Supported
    "border-width"
    | "border-top-width"
    | "border-right-width"
    | "border-bottom-width"
    | "border-left-width" => Supported
    // Flexbox Container
    "flex-direction" | "flex-wrap" | "flex-flow" => Supported
    "justify-content" | "align-items" | "align-content" => Supported
    // Flexbox Item
    "flex" | "flex-grow" | "flex-shrink" | "flex-basis" => Supported
    "align-self" | "order" => Supported
    // Grid Container
    "grid-template-rows" | "grid-template-columns" => Supported
    "grid-template-areas" => Partial("basic support only")
    "grid-auto-rows" | "grid-auto-columns" | "grid-auto-flow" => Supported
    "grid-template" | "grid" => Partial("shorthand parsing limited")
    // Grid Item
    "grid-row-start"
    | "grid-row-end"
    | "grid-column-start"
    | "grid-column-end" => Supported
    "grid-row" | "grid-column" | "grid-area" => Supported
    // Gap
    "gap" | "row-gap" | "column-gap" => Supported
    // Place properties (shorthand)
    "place-content" | "place-items" | "place-self" =>
      Partial("shorthand for align/justify")
    // Logical properties (CSS Logical Properties) - mapped to physical in LTR horizontal-tb
    "margin-inline"
    | "margin-inline-start"
    | "margin-inline-end"
    | "margin-block"
    | "margin-block-start"
    | "margin-block-end" => Supported
    "padding-inline"
    | "padding-inline-start"
    | "padding-inline-end"
    | "padding-block"
    | "padding-block-start"
    | "padding-block-end" => Supported
    "inset-inline"
    | "inset-inline-start"
    | "inset-inline-end"
    | "inset-block"
    | "inset-block-start"
    | "inset-block-end" => Supported
    "border-inline"
    | "border-inline-start"
    | "border-inline-end"
    | "border-block"
    | "border-block-start"
    | "border-block-end"
    | "border-inline-width"
    | "border-inline-start-width"
    | "border-inline-end-width"
    | "border-block-width"
    | "border-block-start-width"
    | "border-block-end-width" => Supported
    // Border logical color/style (visual only)
    "border-inline-color"
    | "border-inline-start-color"
    | "border-inline-end-color"
    | "border-block-color"
    | "border-block-start-color"
    | "border-block-end-color"
    | "border-inline-style"
    | "border-inline-start-style"
    | "border-inline-end-style"
    | "border-block-style"
    | "border-block-start-style"
    | "border-block-end-style" => UnsupportedVisual
    "inline-size"
    | "block-size"
    | "min-inline-size"
    | "min-block-size"
    | "max-inline-size"
    | "max-block-size" => Supported
    // Position
    "position" => Supported
    "top" | "right" | "bottom" | "left" | "inset" => Supported
    "z-index" => Supported
    // Overflow
    "overflow" | "overflow-x" | "overflow-y" => Supported
    // Float & Clear
    "float" | "clear" => Supported
    // Sizing
    "box-sizing" => Supported
    "aspect-ratio" => Supported
    // Text Layout
    "text-align" => Supported
    "vertical-align" => Supported
    "line-height" => Supported
    "direction" | "writing-mode" => Supported
    // === PARTIALLY SUPPORTED ===
    "font-size" => Partial("relative units may not work correctly")
    "font-weight" => Partial("numeric values only")
    "font-family" => Partial("limited font support")
    "font-style" => Partial("basic support")
    "font" => Partial("shorthand parsing limited")
    // Colors
    "color" => Partial("named colors, hex, rgb supported")
    "background-color" => Partial("solid colors only")
    "border-color"
    | "border-top-color"
    | "border-right-color"
    | "border-bottom-color"
    | "border-left-color" => Partial("solid colors only")
    // Border Style
    "border-style"
    | "border-top-style"
    | "border-right-style"
    | "border-bottom-style"
    | "border-left-style" => Partial("rendered as solid")
    "border"
    | "border-top"
    | "border-right"
    | "border-bottom"
    | "border-left" => Partial("shorthand parsing limited")
    // Visibility
    "visibility" => Supported
    "opacity" => Partial("rendered as visible/hidden")
    // === NOT SUPPORTED - AFFECTS LAYOUT ===
    "contain" => UnsupportedLayout
    "content-visibility" => UnsupportedLayout
    "columns" | "column-count" | "column-width" => UnsupportedLayout
    "break-before" | "break-after" | "break-inside" => UnsupportedLayout
    "page-break-before" | "page-break-after" | "page-break-inside" =>
      UnsupportedLayout
    "orphans" | "widows" => UnsupportedLayout
    "shape-outside" | "shape-margin" | "shape-image-threshold" =>
      UnsupportedLayout
    "clip-path" => UnsupportedLayout
    // === NOT SUPPORTED - VISUAL ONLY ===
    // Background
    "background"
    | "background-image"
    | "background-position"
    | "background-size"
    | "background-repeat"
    | "background-attachment"
    | "background-origin"
    | "background-clip" => UnsupportedVisual
    // Border Radius
    "border-radius"
    | "border-top-left-radius"
    | "border-top-right-radius"
    | "border-bottom-left-radius"
    | "border-bottom-right-radius" => UnsupportedVisual
    // Box Shadow
    "box-shadow" => UnsupportedVisual
    // Text Decoration
    "text-decoration"
    | "text-decoration-line"
    | "text-decoration-color"
    | "text-decoration-style"
    | "text-decoration-thickness" => UnsupportedVisual
    // Text Shadow
    "text-shadow" => UnsupportedVisual
    // Transforms
    "transform"
    | "transform-origin"
    | "transform-style"
    | "perspective"
    | "perspective-origin" => UnsupportedVisual
    // Transitions
    "transition"
    | "transition-property"
    | "transition-duration"
    | "transition-timing-function"
    | "transition-delay" => UnsupportedVisual
    // Animations
    "animation"
    | "animation-name"
    | "animation-duration"
    | "animation-timing-function"
    | "animation-delay"
    | "animation-iteration-count"
    | "animation-direction"
    | "animation-fill-mode"
    | "animation-play-state" => UnsupportedVisual
    // Filters
    "filter" | "backdrop-filter" => UnsupportedVisual
    // Outline
    "outline"
    | "outline-width"
    | "outline-style"
    | "outline-color"
    | "outline-offset" => UnsupportedVisual
    // Cursor
    "cursor" => UnsupportedVisual
    // Pointer Events
    "pointer-events" => UnsupportedVisual
    // User Select
    "user-select" => UnsupportedVisual
    // Scroll
    "scroll-behavior"
    | "scroll-snap-type"
    | "scroll-snap-align"
    | "scroll-margin"
    | "scroll-margin-top"
    | "scroll-margin-right"
    | "scroll-margin-bottom"
    | "scroll-margin-left"
    | "scroll-padding"
    | "scroll-padding-top"
    | "scroll-padding-right"
    | "scroll-padding-bottom"
    | "scroll-padding-left" => UnsupportedVisual
    // Overflow anchor
    "overflow-anchor" => UnsupportedVisual
    // Will-change
    "will-change" => UnsupportedVisual
    // Masks
    "mask" | "mask-image" | "-webkit-mask" | "-webkit-mask-image" =>
      UnsupportedVisual
    // Mix Blend Mode
    "mix-blend-mode" | "isolation" => UnsupportedVisual
    // Object Fit
    "object-fit" | "object-position" => UnsupportedVisual
    // Appearance
    "appearance" | "-webkit-appearance" | "-moz-appearance" => UnsupportedVisual
    // Resize
    "resize" => UnsupportedVisual
    // Caret
    "caret-color" => UnsupportedVisual
    // Text rendering
    "text-rendering" => UnsupportedVisual
    // Font features
    "font-feature-settings"
    | "font-variant"
    | "font-variant-ligatures"
    | "font-variant-caps"
    | "font-variant-numeric"
    | "font-variant-east-asian"
    | "font-kerning"
    | "font-optical-sizing"
    | "font-size-adjust"
    | "font-stretch"
    | "font-synthesis"
    | "font-display" => UnsupportedVisual
    // Touch/tap
    "-webkit-tap-highlight-color" | "touch-action" | "-webkit-touch-callout" =>
      UnsupportedVisual
    // Overflow behavior
    "overflow-clip-margin"
    | "-webkit-overflow-scrolling"
    | "overscroll-behavior"
    | "overscroll-behavior-x"
    | "overscroll-behavior-y" => UnsupportedVisual
    // Text emphasis
    "text-emphasis"
    | "text-emphasis-style"
    | "text-emphasis-color"
    | "text-emphasis-position" => UnsupportedVisual
    // Text orientation
    "text-orientation" | "text-combine-upright" => UnsupportedVisual
    // Text direction
    "unicode-bidi" => UnsupportedLayout
    // 3D transforms
    "backface-visibility" => UnsupportedVisual
    // SVG
    "fill" | "stroke" | "stroke-width" => UnsupportedVisual
    // Accent color
    "accent-color" => UnsupportedVisual
    // Color scheme
    "color-scheme" => UnsupportedVisual
    // Forced colors
    "forced-color-adjust" => UnsupportedVisual
    // Print
    "print-color-adjust" | "-webkit-print-color-adjust" => UnsupportedVisual
    // Line clamp
    "-webkit-line-clamp" | "line-clamp" | "-webkit-box-orient" | "box-orient" =>
      UnsupportedVisual
    // Backdrop
    "-webkit-backdrop-filter" => UnsupportedVisual
    // Mask image
    "mask-size" | "mask-repeat" | "mask-position" => UnsupportedVisual
    // Marker
    "marker" | "marker-start" | "marker-mid" | "marker-end" => UnsupportedVisual
    // Word/Letter Spacing
    "word-spacing" | "letter-spacing" => UnsupportedVisual
    // Text properties
    "text-transform"
    | "text-indent"
    | "text-overflow"
    | "white-space"
    | "word-break"
    | "word-wrap"
    | "overflow-wrap"
    | "hyphens" => UnsupportedVisual
    // List Style
    "list-style"
    | "list-style-type"
    | "list-style-position"
    | "list-style-image" => UnsupportedVisual
    // Table
    "table-layout"
    | "border-collapse"
    | "border-spacing"
    | "caption-side"
    | "empty-cells" => UnsupportedVisual
    // Quotes
    "quotes" => UnsupportedVisual
    // Content
    "content" => UnsupportedVisual
    // Counter
    "counter-reset" | "counter-increment" => UnsupportedVisual
    // === DEPRECATED ===
    "clip" => Deprecated("clip-path")
    "zoom" => Deprecated("transform: scale()")
    // === VENDOR PREFIXES (treat as visual) ===
    _ if prop.has_prefix("-webkit-") => UnsupportedVisual
    _ if prop.has_prefix("-moz-") => UnsupportedVisual
    _ if prop.has_prefix("-ms-") => UnsupportedVisual
    _ if prop.has_prefix("-o-") => UnsupportedVisual
    // === CSS CUSTOM PROPERTIES (variables) ===
    _ if prop.has_prefix("--") => UnsupportedVisual
    // === IE HACKS (underscore/asterisk prefix) ===
    _ if prop.has_prefix("_") => UnsupportedVisual
    _ if prop.has_prefix("*") => UnsupportedVisual
    // === UNKNOWN ===
    _ => Unknown
  }
}

///|
/// Get severity for a support level
pub fn support_to_severity(level : SupportLevel) -> Severity {
  match level {
    Supported => Info
    Partial(_) => Info
    UnsupportedVisual => Info
    Deprecated(_) => Warning
    UnsupportedLayout => Warning
    Unknown => Error
  }
}

///|
/// Check if a property should be warned about (not fully supported)
pub fn should_warn(level : SupportLevel) -> Bool {
  match level {
    Supported => false
    _ => true
  }
}

///|
/// Check if a property affects layout
pub fn affects_layout(level : SupportLevel) -> Bool {
  match level {
    UnsupportedLayout => true
    Unknown => true // Unknown properties might affect layout
    _ => false
  }
}

///|
/// CSS Media Query Types
/// Represents parsed media queries for @media rules

///|
/// Media type (screen, print, all, etc.)
pub enum MediaType {
  All
  Screen
  Print
  Speech
} derive(Eq, Debug)

///|
/// Comparison operator for range queries
pub enum RangeOp {
  Eq // =
  Lt // <
  Le // <=
  Gt // >
  Ge // >=
} derive(Eq, Debug)

///|
/// Media feature value
pub enum MediaValue {
  Number(Double)
  Dimension(Double, String) // value and unit (e.g., 768px, 2dppx)
  Ratio(Int, Int) // e.g., 16/9
  Ident(String) // e.g., landscape, portrait
} derive(Eq, Debug)

///|
/// Media feature (e.g., width, height, color, etc.)
pub enum MediaFeature {
  // Boolean features (no value)
  Color
  ColorGamut
  ColorIndex
  Grid
  Hover
  Monochrome
  Pointer
  Scripting
  Update
  // Range features with optional min/max prefix
  Width(MediaValue?)
  MinWidth(MediaValue)
  MaxWidth(MediaValue)
  Height(MediaValue?)
  MinHeight(MediaValue)
  MaxHeight(MediaValue)
  AspectRatio(MediaValue?)
  MinAspectRatio(MediaValue)
  MaxAspectRatio(MediaValue)
  Resolution(MediaValue?)
  MinResolution(MediaValue)
  MaxResolution(MediaValue)
  // Range syntax (CSS Media Queries Level 4)
  WidthRange(RangeOp, MediaValue)
  HeightRange(RangeOp, MediaValue)
  // Discrete features with value
  Orientation(String) // portrait | landscape
  DisplayMode(String) // fullscreen | standalone | minimal-ui | browser
  PrefersColorScheme(String) // light | dark
  PrefersReducedMotion(String) // reduce | no-preference
  // Generic feature for unknown features
  Custom(String, MediaValue?)
} derive(Eq, Debug)

///|
/// A complete media query
pub struct MediaQuery {
  /// "not" modifier
  negated : Bool
  /// "only" modifier
  only : Bool
  /// The media type (if any)
  media_type : MediaType?
  /// The conditions (features)
  conditions : Array[MediaFeature]
} derive(Eq, Debug)

///|
/// Create a default media query (matches all)
pub fn MediaQuery::default() -> MediaQuery {
  { negated: false, only: false, media_type: None, conditions: [] }
}

///|
/// A list of media queries (comma-separated in CSS)
pub struct MediaQueryList {
  queries : Array[MediaQuery]
} derive(Eq, Debug)

///|
/// Create an empty media query list
pub fn MediaQueryList::new() -> MediaQueryList {
  { queries: [] }
}

///|
/// Check if a media query list is empty
pub fn MediaQueryList::is_empty(self : MediaQueryList) -> Bool {
  self.queries.is_empty()
}

///|
/// Get the number of queries
pub fn MediaQueryList::length(self : MediaQueryList) -> Int {
  self.queries.length()
}

///|
pub impl Show for MediaType with output(self, logger) {
  let name = match self {
    All => "All"
    Screen => "Screen"
    Print => "Print"
    Speech => "Speech"
  }
  logger.write_string(name)
}

///|
pub impl Show for RangeOp with output(self, logger) {
  let name = match self {
    Eq => "Eq"
    Lt => "Lt"
    Le => "Le"
    Gt => "Gt"
    Ge => "Ge"
  }
  logger.write_string(name)
}

///|
pub impl Show for MediaValue with output(self, logger) {
  match self {
    Number(v) => logger.write_string("Number(\{v})")
    Dimension(v, unit) => {
      logger.write_string("Dimension(")
      logger.write_string(v.to_string())
      logger.write_string(", ")
      logger.write_string("\"")
      logger.write_string(unit)
      logger.write_string("\"")
      logger.write_string(")")
    }
    Ratio(left, right) => logger.write_string("Ratio(\{left}, \{right})")
    Ident(value) => {
      logger.write_string("Ident(")
      logger.write_string("\"")
      logger.write_string(value)
      logger.write_string("\"")
      logger.write_string(")")
    }
  }
}

///|
pub impl Show for MediaFeature with output(self, logger) {
  match self {
    Color => logger.write_string("Color")
    ColorGamut => logger.write_string("ColorGamut")
    ColorIndex => logger.write_string("ColorIndex")
    Grid => logger.write_string("Grid")
    Hover => logger.write_string("Hover")
    Monochrome => logger.write_string("Monochrome")
    Pointer => logger.write_string("Pointer")
    Scripting => logger.write_string("Scripting")
    Update => logger.write_string("Update")
    Width(value) => logger.write_string("Width(\{value})")
    MinWidth(value) => logger.write_string("MinWidth(\{value})")
    MaxWidth(value) => logger.write_string("MaxWidth(\{value})")
    Height(value) => logger.write_string("Height(\{value})")
    MinHeight(value) => logger.write_string("MinHeight(\{value})")
    MaxHeight(value) => logger.write_string("MaxHeight(\{value})")
    AspectRatio(value) => logger.write_string("AspectRatio(\{value})")
    MinAspectRatio(value) => logger.write_string("MinAspectRatio(\{value})")
    MaxAspectRatio(value) => logger.write_string("MaxAspectRatio(\{value})")
    Resolution(value) => logger.write_string("Resolution(\{value})")
    MinResolution(value) => logger.write_string("MinResolution(\{value})")
    MaxResolution(value) => logger.write_string("MaxResolution(\{value})")
    WidthRange(op, value) => logger.write_string("WidthRange(\{op}, \{value})")
    HeightRange(op, value) =>
      logger.write_string("HeightRange(\{op}, \{value})")
    Orientation(value) => {
      logger.write_string("Orientation(")
      logger.write_string("\"")
      logger.write_string(value)
      logger.write_string("\"")
      logger.write_string(")")
    }
    DisplayMode(value) => {
      logger.write_string("DisplayMode(")
      logger.write_string("\"")
      logger.write_string(value)
      logger.write_string("\"")
      logger.write_string(")")
    }
    PrefersColorScheme(value) => {
      logger.write_string("PrefersColorScheme(")
      logger.write_string("\"")
      logger.write_string(value)
      logger.write_string("\"")
      logger.write_string(")")
    }
    PrefersReducedMotion(value) => {
      logger.write_string("PrefersReducedMotion(")
      logger.write_string("\"")
      logger.write_string(value)
      logger.write_string("\"")
      logger.write_string(")")
    }
    Custom(name, value) => {
      logger.write_string("Custom(")
      logger.write_string("\"")
      logger.write_string(name)
      logger.write_string("\"")
      logger.write_string(", ")
      logger.write_string(value.to_string())
      logger.write_string(")")
    }
  }
}

///|
pub impl Show for MediaQuery with output(self, logger) {
  logger.write_string("{negated: ")
  logger.write_string(self.negated.to_string())
  logger.write_string(", only: ")
  logger.write_string(self.only.to_string())
  logger.write_string(", media_type: ")
  logger.write_string(self.media_type.to_string())
  logger.write_string(", conditions: ")
  logger.write_string(self.conditions.to_string())
  logger.write_string("}")
}

///|
pub impl Show for MediaQueryList with output(self, logger) {
  logger.write_string("{queries: ")
  logger.write_string(self.queries.to_string())
  logger.write_string("}")
}

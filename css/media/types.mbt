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
} derive(Eq, Show)

///|
/// Comparison operator for range queries
pub enum RangeOp {
  Eq // =
  Lt // <
  Le // <=
  Gt // >
  Ge // >=
} derive(Eq, Show)

///|
/// Media feature value
pub enum MediaValue {
  Number(Double)
  Dimension(Double, String) // value and unit (e.g., 768px, 2dppx)
  Ratio(Int, Int) // e.g., 16/9
  Ident(String) // e.g., landscape, portrait
} derive(Eq, Show)

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
} derive(Eq, Show)

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
} derive(Eq, Show)

///|
/// Create a default media query (matches all)
pub fn MediaQuery::default() -> MediaQuery {
  { negated: false, only: false, media_type: None, conditions: [] }
}

///|
/// A list of media queries (comma-separated in CSS)
pub struct MediaQueryList {
  queries : Array[MediaQuery]
} derive(Eq, Show)

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

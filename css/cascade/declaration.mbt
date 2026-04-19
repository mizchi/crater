///|
/// CSS Cascade - Declaration and Origin types
/// Based on CSS Cascading and Inheritance Level 4

///|
/// Origin of a CSS declaration
/// Ordered from lowest to highest precedence for normal declarations
pub(all) enum Origin {
  /// User-agent stylesheet (browser defaults)
  UserAgent
  /// User stylesheet (user preferences)
  User
  /// Author stylesheet (page styles)
  Author
}

///|
pub impl Show for Origin with output(self, logger) {
  match self {
    UserAgent => logger.write_string("UserAgent")
    User => logger.write_string("User")
    Author => logger.write_string("Author")
  }
}

///|
/// Importance of a declaration
pub(all) enum Importance {
  Normal
  Important
}

///|
pub impl Show for Importance with output(self, logger) {
  match self {
    Normal => logger.write_string("Normal")
    Important => logger.write_string("Important")
  }
}

///|
/// A CSS property value that can be a specific value or a keyword
pub(all) enum PropertyValue {
  /// A specific CSS value (parsed)
  Value(String)
  /// inherit keyword
  Inherit
  /// initial keyword
  Initial
  /// unset keyword
  Unset
  /// revert keyword
  Revert
  /// revert-layer keyword
  RevertLayer
}

///|
pub impl Show for PropertyValue with output(self, logger) {
  match self {
    Value(v) => {
      logger.write_string("Value(")
      logger.write_string(v)
      logger.write_string(")")
    }
    Inherit => logger.write_string("inherit")
    Initial => logger.write_string("initial")
    Unset => logger.write_string("unset")
    Revert => logger.write_string("revert")
    RevertLayer => logger.write_string("revert-layer")
  }
}

///|
/// A CSS declaration with cascade metadata
pub(all) struct Declaration {
  /// Property name (e.g., "width", "display")
  property : String
  /// Property value
  value : PropertyValue
  /// Origin of this declaration
  origin : Origin
  /// Whether this declaration has !important
  importance : Importance
  /// Selector specificity (from the rule that contains this declaration)
  specificity : @selector.Specificity
  /// Source order (higher = later in source)
  source_order : Int
}

///|
pub impl Show for Declaration with output(self, logger) {
  logger.write_string(self.property)
  logger.write_string(": ")
  self.value.output(logger)
  match self.importance {
    Important => logger.write_string(" !important")
    Normal => ()
  }
}

///|
/// Create a new declaration with default values
pub fn Declaration::new(property : String, value : String) -> Declaration {
  {
    property,
    value: Value(value),
    origin: Author,
    importance: Normal,
    specificity: @selector.Specificity::zero(),
    source_order: 0,
  }
}

///|
/// Create a declaration with full metadata
pub fn Declaration::with_metadata(
  property : String,
  value : PropertyValue,
  origin : Origin,
  importance : Importance,
  specificity : @selector.Specificity,
  source_order : Int,
) -> Declaration {
  { property, value, origin, importance, specificity, source_order }
}

///|
/// Create a declaration from inline style (highest specificity)
pub fn Declaration::from_inline(
  property : String,
  value : String,
  importance : Importance,
) -> Declaration {
  {
    property,
    value: Value(value),
    origin: Author,
    importance,
    // Inline styles have specificity (1,0,0,0) but we represent as (1,0,0) with special handling
    specificity: { a: 1, b: 0, c: 0 },
    source_order: 0,
  }
}

///|
/// Cascade precedence level
/// Higher value = higher precedence
fn cascade_precedence(origin : Origin, importance : Importance) -> Int {
  match (origin, importance) {
    // Lowest to highest precedence for cascade
    // 1. Normal user-agent
    (UserAgent, Normal) => 1
    // 2. Normal user
    (User, Normal) => 2
    // 3. Normal author
    (Author, Normal) => 3
    // 4. !important author
    (Author, Important) => 4
    // 5. !important user
    (User, Important) => 5
    // 6. !important user-agent
    (UserAgent, Important) => 6
    // Note: Transitions (7) and Animations (5) are not handled here
  }
}

///|
/// Compare two declarations for cascade ordering
/// Returns positive if a wins, negative if b wins, 0 if equal
fn compare_declarations(a : Declaration, b : Declaration) -> Int {
  // 1. Compare cascade precedence (origin + importance)
  let prec_a = cascade_precedence(a.origin, a.importance)
  let prec_b = cascade_precedence(b.origin, b.importance)
  if prec_a != prec_b {
    return prec_a - prec_b
  }

  // 2. Compare specificity
  let spec_cmp = a.specificity.compare_to(b.specificity)
  if spec_cmp != 0 {
    return spec_cmp
  }

  // 3. Compare source order (later wins)
  a.source_order - b.source_order
}

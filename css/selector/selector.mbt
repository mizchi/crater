///|
/// CSS Selector types based on Selectors Level 4

///|
/// Attribute matching mode
pub enum AttributeMatch {
  /// [attr] - has attribute
  Exists
  /// [attr=value] - exact match
  Exact(String)
  /// [attr~=value] - whitespace-separated list contains value
  Includes(String)
  /// [attr|=value] - equals or starts with value followed by hyphen
  DashMatch(String)
  /// [attr^=value] - starts with
  Prefix(String)
  /// [attr$=value] - ends with
  Suffix(String)
  /// [attr*=value] - contains
  Substring(String)
}

///|
pub impl Show for AttributeMatch with output(self, logger) {
  match self {
    Exists => logger.write_string("Exists")
    Exact(v) => {
      logger.write_string("Exact(")
      logger.write_string(v)
      logger.write_string(")")
    }
    Includes(v) => {
      logger.write_string("Includes(")
      logger.write_string(v)
      logger.write_string(")")
    }
    DashMatch(v) => {
      logger.write_string("DashMatch(")
      logger.write_string(v)
      logger.write_string(")")
    }
    Prefix(v) => {
      logger.write_string("Prefix(")
      logger.write_string(v)
      logger.write_string(")")
    }
    Suffix(v) => {
      logger.write_string("Suffix(")
      logger.write_string(v)
      logger.write_string(")")
    }
    Substring(v) => {
      logger.write_string("Substring(")
      logger.write_string(v)
      logger.write_string(")")
    }
  }
}

///|
/// Attribute selector
pub struct AttributeSelector {
  name : String
  match_type : AttributeMatch
  /// Case-insensitive flag [attr=value i]
  case_insensitive : Bool
}

///|
pub impl Show for AttributeSelector with output(self, logger) {
  logger.write_string("[")
  logger.write_string(self.name)
  match self.match_type {
    Exists => ()
    _ => {
      logger.write_string(" ")
      self.match_type.output(logger)
    }
  }
  if self.case_insensitive {
    logger.write_string(" i")
  }
  logger.write_string("]")
}

///|
/// Nth expression: An+B
pub struct NthExpr {
  a : Int // coefficient
  b : Int // offset
}

///|
pub impl Show for NthExpr with output(self, logger) {
  if self.a == 0 {
    logger.write_string(self.b.to_string())
  } else if self.a == 1 {
    logger.write_string("n")
    if self.b > 0 {
      logger.write_string("+")
      logger.write_string(self.b.to_string())
    } else if self.b < 0 {
      logger.write_string(self.b.to_string())
    }
  } else if self.a == -1 {
    logger.write_string("-n")
    if self.b > 0 {
      logger.write_string("+")
      logger.write_string(self.b.to_string())
    } else if self.b < 0 {
      logger.write_string(self.b.to_string())
    }
  } else {
    logger.write_string(self.a.to_string())
    logger.write_string("n")
    if self.b > 0 {
      logger.write_string("+")
      logger.write_string(self.b.to_string())
    } else if self.b < 0 {
      logger.write_string(self.b.to_string())
    }
  }
}

///|
/// Pseudo-class selector
pub enum PseudoClass {
  // Tree-structural
  FirstChild
  LastChild
  OnlyChild
  NthChild(NthExpr)
  NthLastChild(NthExpr)
  FirstOfType
  LastOfType
  OnlyOfType
  NthOfType(NthExpr)
  NthLastOfType(NthExpr)
  Root
  Empty
  // Negation
  Not(Array[CompoundSelector])
  // Matches-any
  Is(Array[ComplexSelector])
  Where(Array[ComplexSelector])
  Has(Array[RelativeSelector])
  // User-action
  Hover
  Active
  Focus
  FocusVisible
  FocusWithin
  // Link
  Link
  Visited
  AnyLink
  // Input
  Enabled
  Disabled
  Checked
  Indeterminate
  Required
  Optional
  Valid
  Invalid
  ReadOnly
  ReadWrite
}

///|
pub impl Show for PseudoClass with output(self, logger) {
  match self {
    FirstChild => logger.write_string(":first-child")
    LastChild => logger.write_string(":last-child")
    OnlyChild => logger.write_string(":only-child")
    NthChild(expr) => {
      logger.write_string(":nth-child(")
      expr.output(logger)
      logger.write_string(")")
    }
    NthLastChild(expr) => {
      logger.write_string(":nth-last-child(")
      expr.output(logger)
      logger.write_string(")")
    }
    FirstOfType => logger.write_string(":first-of-type")
    LastOfType => logger.write_string(":last-of-type")
    OnlyOfType => logger.write_string(":only-of-type")
    NthOfType(expr) => {
      logger.write_string(":nth-of-type(")
      expr.output(logger)
      logger.write_string(")")
    }
    NthLastOfType(expr) => {
      logger.write_string(":nth-last-of-type(")
      expr.output(logger)
      logger.write_string(")")
    }
    Root => logger.write_string(":root")
    Empty => logger.write_string(":empty")
    Not(_) => logger.write_string(":not(...)")
    Is(_) => logger.write_string(":is(...)")
    Where(_) => logger.write_string(":where(...)")
    Has(_) => logger.write_string(":has(...)")
    Hover => logger.write_string(":hover")
    Active => logger.write_string(":active")
    Focus => logger.write_string(":focus")
    FocusVisible => logger.write_string(":focus-visible")
    FocusWithin => logger.write_string(":focus-within")
    Link => logger.write_string(":link")
    Visited => logger.write_string(":visited")
    AnyLink => logger.write_string(":any-link")
    Enabled => logger.write_string(":enabled")
    Disabled => logger.write_string(":disabled")
    Checked => logger.write_string(":checked")
    Indeterminate => logger.write_string(":indeterminate")
    Required => logger.write_string(":required")
    Optional => logger.write_string(":optional")
    Valid => logger.write_string(":valid")
    Invalid => logger.write_string(":invalid")
    ReadOnly => logger.write_string(":read-only")
    ReadWrite => logger.write_string(":read-write")
  }
}

///|
/// Pseudo-element selector
pub enum PseudoElement {
  Before
  After
  FirstLine
  FirstLetter
  Marker
  Placeholder
  Selection
}

///|
pub impl Show for PseudoElement with output(self, logger) {
  match self {
    Before => logger.write_string("::before")
    After => logger.write_string("::after")
    FirstLine => logger.write_string("::first-line")
    FirstLetter => logger.write_string("::first-letter")
    Marker => logger.write_string("::marker")
    Placeholder => logger.write_string("::placeholder")
    Selection => logger.write_string("::selection")
  }
}

///|
/// Simple selector - a single component
pub enum SimpleSelector {
  /// Type selector: div, span
  Type(String)
  /// Universal selector: *
  Universal
  /// ID selector: #id
  Id(String)
  /// Class selector: .class
  Class(String)
  /// Attribute selector: [attr], [attr=value]
  Attribute(AttributeSelector)
  /// Pseudo-class: :hover, :first-child
  PseudoClass(PseudoClass)
  /// Pseudo-element: ::before, ::after
  PseudoElement(PseudoElement)
}

///|
pub impl Show for SimpleSelector with output(self, logger) {
  match self {
    Type(name) => logger.write_string(name)
    Universal => logger.write_string("*")
    Id(id) => {
      logger.write_string("#")
      logger.write_string(id)
    }
    Class(cls) => {
      logger.write_string(".")
      logger.write_string(cls)
    }
    Attribute(attr) => attr.output(logger)
    PseudoClass(pc) => pc.output(logger)
    PseudoElement(pe) => pe.output(logger)
  }
}

///|
/// Compound selector - a sequence of simple selectors without combinator
/// e.g., div.foo#bar:hover
pub struct CompoundSelector {
  /// Type or universal selector (at most one, must be first if present)
  type_selector : SimpleSelector?
  /// Other simple selectors (id, class, attribute, pseudo)
  subclasses : Array[SimpleSelector]
}

///|
pub impl Show for CompoundSelector with output(self, logger) {
  match self.type_selector {
    Some(sel) => sel.output(logger)
    None => ()
  }
  for sub in self.subclasses {
    sub.output(logger)
  }
}

///|
/// Combinator between compound selectors
pub enum Combinator {
  /// Descendant combinator (whitespace)
  Descendant
  /// Child combinator (>)
  Child
  /// Next-sibling combinator (+)
  NextSibling
  /// Subsequent-sibling combinator (~)
  SubsequentSibling
}

///|
pub impl Show for Combinator with output(self, logger) {
  match self {
    Descendant => logger.write_string(" ")
    Child => logger.write_string(" > ")
    NextSibling => logger.write_string(" + ")
    SubsequentSibling => logger.write_string(" ~ ")
  }
}

///|
/// A step in a complex selector: combinator + compound selector
pub struct ComplexSelectorStep {
  combinator : Combinator
  selector : CompoundSelector
}

///|
/// Complex selector - compound selectors joined by combinators
/// e.g., div > p.intro + span
pub struct ComplexSelector {
  /// The rightmost compound selector (the subject by default)
  head : CompoundSelector
  /// Chain of combinator + compound pairs going left
  /// e.g., for "div > p.intro", head = "p.intro", tail = [(Child, "div")]
  tail : Array[ComplexSelectorStep]
}

///|
pub impl Show for ComplexSelector with output(self, logger) {
  // Print from left to right (tail is reversed order)
  let parts : Array[String] = []
  for i = self.tail.length() - 1; i >= 0; i = i - 1 {
    let step = self.tail[i]
    let buf = StringBuilder::new()
    step.selector.output(buf)
    parts.push(buf.to_string())
    match step.combinator {
      Descendant => parts.push(" ")
      Child => parts.push(" > ")
      NextSibling => parts.push(" + ")
      SubsequentSibling => parts.push(" ~ ")
    }
  }
  for part in parts {
    logger.write_string(part)
  }
  self.head.output(logger)
}

///|
/// Relative selector for :has()
pub struct RelativeSelector {
  combinator : Combinator?
  selector : ComplexSelector
}

///|
/// Selector list - comma-separated selectors
pub struct SelectorList {
  selectors : Array[ComplexSelector]
}

///|
pub impl Show for SelectorList with output(self, logger) {
  for i, sel in self.selectors {
    if i > 0 {
      logger.write_string(", ")
    }
    sel.output(logger)
  }
}

///|
/// Specificity as (a, b, c) tuple
/// a: ID selectors count
/// b: class selectors, attribute selectors, pseudo-classes count
/// c: type selectors, pseudo-elements count
pub(all) struct Specificity {
  a : Int
  b : Int
  c : Int
} derive(Eq, Compare)

///|
pub impl Show for Specificity with output(self, logger) {
  logger.write_string("(")
  logger.write_string(self.a.to_string())
  logger.write_string(",")
  logger.write_string(self.b.to_string())
  logger.write_string(",")
  logger.write_string(self.c.to_string())
  logger.write_string(")")
}

///|
pub fn Specificity::zero() -> Specificity {
  { a: 0, b: 0, c: 0 }
}

///|
pub fn Specificity::add(self : Specificity, other : Specificity) -> Specificity {
  { a: self.a + other.a, b: self.b + other.b, c: self.c + other.c }
}

///|
/// Compare specificities for cascade ordering
/// Returns positive if self > other, negative if self < other, 0 if equal
pub fn Specificity::compare_to(self : Specificity, other : Specificity) -> Int {
  if self.a != other.a {
    return self.a - other.a
  }
  if self.b != other.b {
    return self.b - other.b
  }
  self.c - other.c
}

///|
/// Create a simple compound selector with just a type selector
pub fn CompoundSelector::from_type(tag_name : String) -> CompoundSelector {
  { type_selector: Some(Type(tag_name)), subclasses: [] }
}

///|
/// Create a simple compound selector with just a class selector
pub fn CompoundSelector::from_class(class_name : String) -> CompoundSelector {
  { type_selector: None, subclasses: [Class(class_name)] }
}

///|
/// Create a simple compound selector with just an ID selector
pub fn CompoundSelector::from_id(id : String) -> CompoundSelector {
  { type_selector: None, subclasses: [Id(id)] }
}

///|
/// Create a simple compound selector with universal selector
pub fn CompoundSelector::universal() -> CompoundSelector {
  { type_selector: Some(Universal), subclasses: [] }
}

///|
/// Create a complex selector from a single compound
pub fn ComplexSelector::simple(compound : CompoundSelector) -> ComplexSelector {
  { head: compound, tail: [] }
}

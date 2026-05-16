// ============================================================================
// Use/Symbol (Reusable Elements)
// ============================================================================

///|
/// Symbol definition (reusable graphic)
pub(all) struct Symbol {
  id : String
  content : SVGNode
  view_box : ViewBox?
  preserve_aspect_ratio : PreserveAspectRatio
}

///|
pub fn Symbol::new(id : String, content : SVGNode) -> Symbol {
  Symbol::from_msvg(@msvg.Symbol::new(id, content.to_msvg()))
}

///|
pub fn Symbol::with_viewbox(
  id : String,
  content : SVGNode,
  view_box : ViewBox,
) -> Symbol {
  Symbol::from_msvg(
    @msvg.Symbol::with_viewbox(
      id,
      content.to_msvg(),
      view_box.to_msvg(),
    ),
  )
}

///|
/// Use element (instance of a symbol)
pub(all) struct UseElement {
  href : String // Reference to symbol ID (e.g., "#mySymbol")
  x : Double
  y : Double
  width : Double?
  height : Double?
  transform : Transform
}

///|
pub fn UseElement::new(href : String, x : Double, y : Double) -> UseElement {
  UseElement::from_msvg(@msvg.UseElement::new(href, x, y))
}

///|
pub fn UseElement::with_size(
  href : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> UseElement {
  UseElement::from_msvg(@msvg.UseElement::with_size(href, x, y, width, height))
}

///|
/// Get the href ID (strips leading #)
pub fn UseElement::get_id(self : UseElement) -> String {
  self.to_msvg().get_id()
}

///|
/// Symbol registry
pub(all) struct SymbolRegistry {
  symbols : Map[String, Symbol]
}

///|
pub fn SymbolRegistry::new() -> SymbolRegistry {
  { symbols: {} }
}

///|
pub fn SymbolRegistry::add(self : SymbolRegistry, symbol : Symbol) -> Unit {
  self.symbols.set(symbol.id, symbol)
}

///|
pub fn SymbolRegistry::get(self : SymbolRegistry, id : String) -> Symbol? {
  self.symbols.get(id)
}

///|
/// Instantiate a use element with the symbol registry
pub fn UseElement::instantiate(
  self : UseElement,
  registry : SymbolRegistry,
) -> SVGNode? {
  match
    self.to_msvg().instantiate(registry.to_msvg()) {
    Some(node) => Some(SVGNode::from_msvg(node))
    None => None
  }
}

///|
fn UseElement::from_msvg(use_element : @msvg.UseElement) -> UseElement {
  {
    href: use_element.href,
    x: use_element.x,
    y: use_element.y,
    width: use_element.width,
    height: use_element.height,
    transform: Transform::from_msvg(use_element.transform),
  }
}

///|
fn UseElement::to_msvg(self : UseElement) -> @msvg.UseElement {
  @msvg.UseElement::{
    href: self.href,
    x: self.x,
    y: self.y,
    width: self.width,
    height: self.height,
    transform: self.transform.to_msvg(),
  }
}

///|
fn Symbol::from_msvg(symbol : @msvg.Symbol) -> Symbol {
  {
    id: symbol.id,
    content: SVGNode::from_msvg(symbol.content),
    view_box: ViewBox::from_msvg_option(symbol.view_box),
    preserve_aspect_ratio: PreserveAspectRatio::default(),
  }
}

///|
fn Symbol::to_msvg(self : Symbol) -> @msvg.Symbol {
  @msvg.Symbol::{
    id: self.id,
    content: self.content.to_msvg(),
    view_box: ViewBox::to_msvg_option(self.view_box),
    width: None,
    height: None,
    preserve_aspect_ratio: self.preserve_aspect_ratio.to_msvg(),
    display_none: false,
  }
}

///|
fn SymbolRegistry::to_msvg(self : SymbolRegistry) -> @msvg.SymbolRegistry {
  let converted = @msvg.SymbolRegistry::new()
  self.symbols.each(fn(_id, symbol) { converted.add(symbol.to_msvg()) })
  converted
}

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
  symbol_from_msvg(@msvg.Symbol::new(id, content.to_msvg()))
}

///|
pub fn Symbol::with_viewbox(
  id : String,
  content : SVGNode,
  view_box : ViewBox,
) -> Symbol {
  symbol_from_msvg(
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
  use_element_from_msvg(@msvg.UseElement::new(href, x, y))
}

///|
pub fn UseElement::with_size(
  href : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> UseElement {
  use_element_from_msvg(@msvg.UseElement::with_size(href, x, y, width, height))
}

///|
/// Get the href ID (strips leading #)
pub fn UseElement::get_id(self : UseElement) -> String {
  use_element_to_msvg(self).get_id()
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
    use_element_to_msvg(self).instantiate(symbol_registry_to_msvg(registry)) {
    Some(node) => Some(SVGNode::from_msvg(node))
    None => None
  }
}

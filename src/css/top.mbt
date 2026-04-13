// =============================================================================
// CSS Package - Public API Entry Point
// =============================================================================
//
// This package groups parser / selector / cascade / computed-style APIs behind
// a single import so it can be split out as an independent package later.

///|
pub using @cascade {
  type CascadedValues,
  type CSSRule,
  type Declaration,
  type Importance,
  type IndexedStylesheet,
  type Origin,
  type PropertyValue,
  type RuleMatch,
  type SelectorIndex,
  type Stylesheet,
}

///|
pub using @computed {type ComputeContext, type CssColorValue}

///|
pub using @diagnostics {
  type Diagnostic,
  type DiagnosticSummary,
  type DiagnosticsCollector,
  type Severity,
  type SupportLevel,
}

///|
pub using @media {
  type ColorScheme,
  type MediaEnvironment,
  type MediaFeature,
  type MediaQuery,
  type MediaQueryList,
  type MediaType,
  type MediaValue,
  type RangeOp,
}

///|
pub using @parser {type ParseResult}

///|
pub using @responsive {
  type BreakpointDiscoveryDiagnostics,
  type BreakpointDiscoveryResult,
  type ComputedStylesWithStateResult,
  type CssRuleViewportEntry,
  type CssRuleViewportMap,
  type RequiredTestViewport,
  type RequiredTestViewportsResult,
  type ResponsiveBreakpoint,
  type StylePropertyDiff,
}

///|
pub using @selector {
  type Attribute,
  type AttributeMatch,
  type AttributeSelector,
  type Combinator,
  type ComplexSelector,
  type ComplexSelectorStep,
  type CompoundSelector,
  type Element,
  type ForcedPseudoStates,
  type NthExpr,
  type PseudoClass,
  type PseudoElement,
  type RelativeSelector,
  type SelectorList,
  type SimpleSelector,
  type Specificity,
}

///|
pub fn parse_stylesheet(css : String) -> @cascade.Stylesheet {
  @parser.parse_stylesheet(css)
}

///|
pub fn parse_stylesheet_with_diagnostics(css : String) -> @parser.ParseResult {
  @parser.parse_stylesheet_with_diagnostics(css)
}

///|
pub fn parse_inline_style(css : String) -> @style.Style {
  @parser.parse_inline_style(css)
}

///|
pub fn parse_media_query_list(input : String) -> @media.MediaQueryList {
  @media.parse_media_query_list(input)
}

///|
pub fn parse_selector(css : String) -> @selector.ComplexSelector? {
  @selector.parse_selector_text(css)
}

///|
pub fn parse_selector_list(css : String) -> @selector.SelectorList? {
  @selector.parse_selector_list_text(css)
}

///|
pub fn matches_selector(
  element : @selector.Element,
  selector : @selector.ComplexSelector,
) -> Bool {
  @selector.matches_complex(element, selector)
}

///|
pub fn matches_selector_list(
  element : @selector.Element,
  selector_list : @selector.SelectorList,
) -> Bool {
  @selector.matches_selector_list(element, selector_list)
}

///|
pub fn cascade_declarations(
  declarations : Array[@cascade.Declaration],
) -> @cascade.CascadedValues {
  @cascade.cascade(declarations)
}

///|
pub fn cascade_element(
  element : @selector.Element,
  stylesheets : Array[@cascade.Stylesheet],
  inline_style : Array[@cascade.Declaration],
) -> @cascade.CascadedValues {
  @cascade.cascade_element(element, stylesheets, inline_style)
}

///|
pub fn cascade_element_with_media(
  element : @selector.Element,
  stylesheets : Array[@cascade.Stylesheet],
  inline_style : Array[@cascade.Declaration],
  media_env : @media.MediaEnvironment?,
) -> @cascade.CascadedValues {
  @cascade.cascade_element_with_media(
    element, stylesheets, inline_style, media_env,
  )
}

///|
pub fn cascade_element_indexed(
  element : @selector.Element,
  stylesheets : Array[@cascade.IndexedStylesheet],
  inline_style : Array[@cascade.Declaration],
  media_env : @media.MediaEnvironment?,
) -> @cascade.CascadedValues {
  @cascade.cascade_element_indexed(
    element, stylesheets, inline_style, media_env,
  )
}

///|
pub fn compute_style(
  cascaded : @cascade.CascadedValues,
  ctx : @computed.ComputeContext,
) -> @style.Style {
  @computed.compute(cascaded, ctx)
}

///|
pub fn compute_style_with_vars(
  cascaded : @cascade.CascadedValues,
  ctx : @computed.ComputeContext,
) -> (@style.Style, Map[String, String]) {
  @computed.compute_with_vars(cascaded, ctx)
}

///|
pub fn compute_inline_style(
  inline_css : String,
  ctx : @computed.ComputeContext,
) -> @style.Style {
  @computed.compute_inline(inline_css, ctx)
}

///|
pub fn compute_inline_raw(
  inline_css : String,
  ctx : @computed.ComputeContext,
) -> @style.Style {
  @computed.compute_inline_raw(inline_css, ctx)
}

///|
pub fn apply_property_direct(
  style : @style.Style,
  property : String,
  value : String,
  ctx : @computed.ComputeContext,
) -> @style.Style {
  @computed.apply_property_direct(style, property, value, ctx)
}

///|
pub fn parse_color(value : String) -> @computed.CssColorValue {
  @computed.parse_color(value)
}

///|
pub fn affects_layout(level : @diagnostics.SupportLevel) -> Bool {
  @diagnostics.affects_layout(level)
}

///|
pub fn discover_responsive_breakpoints(
  html : String,
) -> @responsive.BreakpointDiscoveryResult {
  @responsive.discover_responsive_breakpoints(html)
}

///|
pub fn discover_css_rule_viewport_map(
  html : String,
  viewport_widths : Array[Int],
) -> @responsive.CssRuleViewportMap {
  @responsive.discover_css_rule_viewport_map(html, viewport_widths)
}

///|
pub fn discover_required_test_viewports(
  html : String,
) -> @responsive.RequiredTestViewportsResult {
  @responsive.discover_required_test_viewports(html)
}

///|
pub fn discover_computed_styles_with_state(
  html : String,
  target_selector : String,
  forced_states : @selector.ForcedPseudoStates,
  properties : Array[String],
) -> @responsive.ComputedStylesWithStateResult {
  @responsive.discover_computed_styles_with_state(
    html, target_selector, forced_states, properties,
  )
}

///|
pub fn discover_computed_styles_with_state_names(
  html : String,
  target_selector : String,
  forced_state_names : Array[String],
  properties : Array[String],
) -> @responsive.ComputedStylesWithStateResult {
  @responsive.discover_computed_styles_with_state_names(
    html, target_selector, forced_state_names, properties,
  )
}

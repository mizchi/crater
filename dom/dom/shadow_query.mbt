///|
/// Shadow-scoped selector matching (#286, Step 5).
///
/// The shared `mizchi/css/selector` matcher deliberately returns `false` for
/// the shadow-scoping pseudo-classes/elements (`:host`, `:host()`,
/// `:host-context()`, `::slotted()`) because its `Element` view has no shadow
/// tree. Those pseudos can only be resolved against the live DOM, so they are
/// implemented here: the complex selector is walked over the real node tree and
/// each compound is evaluated either against the shadow relationships (host /
/// slot assignment) or, for ordinary compounds, delegated back to
/// `@selector.matches_complex`.
///
/// This is the matching primitive a shadow-tree style cascade will use; it is
/// not wired into `querySelector` because `:host` does not match there per spec.

///|
/// Match `subject` against `selector` as authored inside the shadow tree whose
/// host is `host`. Returns whether the subject is selected. An unparseable
/// selector yields `InvalidOperation`.
pub fn DomTree::matches_shadow_scoped(
  self : DomTree,
  subject : NodeId,
  selector : String,
  host : NodeId,
) -> Result[Bool, CoreError] {
  guard self.nodes.get(subject.to_int()) is Some(_) else {
    return Err(NodeNotFound(node_id=subject))
  }
  guard self.nodes.get(host.to_int()) is Some(_) else {
    return Err(NodeNotFound(node_id=host))
  }
  let list = match @selector.parse_selector_list_text(selector) {
    Some(list) => list
    None =>
      return Err(InvalidOperation(message="invalid selector: \{selector}"))
  }
  for cs in list.selectors {
    if self.complex_matches_scoped(subject, cs, host) {
      return Ok(true)
    }
  }
  Ok(false)
}

///|
/// Match a complex selector with `subject` as its rightmost (head) compound,
/// walking the tail leftward/upward over the live tree.
fn DomTree::complex_matches_scoped(
  self : DomTree,
  subject : NodeId,
  cs : @selector.ComplexSelector,
  host : NodeId,
) -> Bool {
  if !self.compound_matches_scoped(subject, cs.head, host) {
    return false
  }
  let mut current = subject
  for step in cs.tail {
    match self.find_step_match(current, step, host) {
      Some(next) => current = next
      None => return false
    }
  }
  true
}

///|
/// Resolve one combinator step, returning the matched relative node if any.
/// Shadow-scoping compounds (`:host` …) can cross the shadow-root boundary to
/// the host; ordinary compounds stay within the shadow tree.
fn DomTree::find_step_match(
  self : DomTree,
  current : NodeId,
  step : @selector.ComplexSelectorStep,
  host : NodeId,
) -> NodeId? {
  let compound = step.selector
  let host_step = is_host_compound(compound)
  match step.combinator {
    @selector.Combinator::Child =>
      match self.light_parent_id(current) {
        Some(p) =>
          if self.is_shadow_root(p) {
            self.host_boundary_match(host_step, compound, host)
          } else if self.compound_matches_scoped(p, compound, host) {
            Some(p)
          } else {
            None
          }
        None => None
      }
    @selector.Combinator::Descendant =>
      // Walk light ancestors within the shadow tree; the chain stops at the
      // shadow root (which has no light parent), then `:host` can cross it.
      match
        first_in_chain(
          self.light_parent_id(current),
          fn(n) { self.light_parent_id(n) },
          fn(a) {
            !self.is_shadow_root(a) &&
            self.compound_matches_scoped(a, compound, host)
          },
        ) {
        Some(a) => Some(a)
        None => self.host_boundary_match(host_step, compound, host)
      }
    @selector.Combinator::NextSibling =>
      match self.prev_element_sibling(current) {
        Some(s) =>
          if self.compound_matches_scoped(s, compound, host) {
            Some(s)
          } else {
            None
          }
        None => None
      }
    @selector.Combinator::SubsequentSibling =>
      first_in_chain(
        self.prev_element_sibling(current),
        fn(s) { self.prev_element_sibling(s) },
        fn(s) { self.compound_matches_scoped(s, compound, host) },
      )
  }
}

///|
/// Cross the shadow-root boundary: a `:host` family step matched against an
/// element whose parent is the shadow root resolves to the host itself.
fn DomTree::host_boundary_match(
  self : DomTree,
  host_step : Bool,
  compound : @selector.CompoundSelector,
  host : NodeId,
) -> NodeId? {
  if host_step && self.compound_matches_scoped(host, compound, host) {
    Some(host)
  } else {
    None
  }
}

///|
/// Return the first node reachable from `start` by repeatedly applying `next`
/// that satisfies `pred`, or `None` when the chain is exhausted.
fn first_in_chain(
  start : NodeId?,
  next : (NodeId) -> NodeId?,
  pred : (NodeId) -> Bool,
) -> NodeId? {
  for cur = start {
    match cur {
      Some(n) => if pred(n) { break Some(n) } else { continue next(n) }
      None => break None
    }
  }
}

///|
/// Match a single compound against `id`, intercepting the shadow-scoping
/// pseudos and delegating everything else to the shared matcher.
fn DomTree::compound_matches_scoped(
  self : DomTree,
  id : NodeId,
  compound : @selector.CompoundSelector,
  host : NodeId,
) -> Bool {
  match slotted_arg_of(compound) {
    Some(args) => return self.matches_slotted(id, args, host)
    None => ()
  }
  match host_pseudo_of(compound) {
    Some(pc) => return self.matches_host_pseudo(id, pc, host)
    None => ()
  }
  self.compound_matches_plain(id, compound)
}

///|
/// Ordinary compound match: project the node into a `@selector.Element` (with
/// element-based sibling index/count for structural pseudos) and delegate.
fn DomTree::compound_matches_plain(
  self : DomTree,
  id : NodeId,
  compound : @selector.CompoundSelector,
) -> Bool {
  match self.nodes.get(id.to_int()) {
    Some(node) if node.node_type == Element => {
      let (index, count) = self.element_sibling_position(id.to_int())
      let element = dom_node_to_selector_element(node, None, None, index, count)
      @selector.matches_complex(
        element,
        @selector.ComplexSelector::simple(compound),
      )
    }
    _ => false
  }
}

///|
/// `:host`, `:host(<compound>)`, `:host-context(<compound>)`: the subject must
/// be the host, with the functional argument tested against the host (and, for
/// `:host-context`, its light-tree ancestors).
fn DomTree::matches_host_pseudo(
  self : DomTree,
  id : NodeId,
  pc : @selector.PseudoClass,
  host : NodeId,
) -> Bool {
  if id.to_int() != host.to_int() {
    return false
  }
  match pc {
    @selector.PseudoClass::Host => true
    @selector.PseudoClass::HostFunc(c) => self.compound_matches_plain(host, c)
    @selector.PseudoClass::HostContextFunc(c) =>
      first_in_chain(Some(host), fn(n) { self.light_parent_id(n) }, fn(n) {
        self.compound_matches_plain(n, c)
      })
      is Some(_)
    _ => false
  }
}

///|
/// `::slotted(<compound>)`: the subject must be a light node assigned to a slot
/// in `host`'s shadow tree and match the compound argument.
fn DomTree::matches_slotted(
  self : DomTree,
  id : NodeId,
  args : Array[@selector.CompoundSelector],
  host : NodeId,
) -> Bool {
  match self.get_assigned_slot_for_light_node(host, id) {
    Some(_) =>
      match args {
        [] => true
        [first, ..] => self.compound_matches_plain(id, first)
      }
    None => false
  }
}

///|
/// The host pseudo-class carried by a compound, if any.
fn host_pseudo_of(
  compound : @selector.CompoundSelector,
) -> @selector.PseudoClass? {
  for sub in compound.subclasses {
    match sub {
      @selector.SimpleSelector::PseudoClass(pc) =>
        match pc {
          @selector.PseudoClass::Host
          | @selector.PseudoClass::HostFunc(_)
          | @selector.PseudoClass::HostContextFunc(_) => return Some(pc)
          _ => ()
        }
      _ => ()
    }
  }
  None
}

///|
fn is_host_compound(compound : @selector.CompoundSelector) -> Bool {
  host_pseudo_of(compound) is Some(_)
}

///|
/// The `::slotted()` argument compounds carried by a compound, if any.
fn slotted_arg_of(
  compound : @selector.CompoundSelector,
) -> Array[@selector.CompoundSelector]? {
  for sub in compound.subclasses {
    match sub {
      @selector.SimpleSelector::PseudoElement(
        @selector.PseudoElement::Slotted(args)
      ) => return Some(args)
      _ => ()
    }
  }
  None
}

///|
fn DomTree::light_parent_id(self : DomTree, id : NodeId) -> NodeId? {
  match self.get_parent(id) {
    Ok(parent) => parent
    Err(_) => None
  }
}

///|
fn DomTree::is_shadow_root(self : DomTree, id : NodeId) -> Bool {
  match self.nodes.get(id.to_int()) {
    Some(node) => node.node_type == ShadowRoot
    None => false
  }
}

///|
/// The previous element sibling of `id` (skipping text/comment nodes).
fn DomTree::prev_element_sibling(self : DomTree, id : NodeId) -> NodeId? {
  guard self.nodes.get(id.to_int()) is Some(node) else { return None }
  guard node.parent_id is Some(pid) else { return None }
  guard self.nodes.get(pid) is Some(parent) else { return None }
  let mut prev : NodeId? = None
  for child_id in parent.children {
    if child_id == id.to_int() {
      break
    }
    if self.nodes.get(child_id) is Some(child) && child.node_type == Element {
      prev = Some(NodeId::from_int(child_id))
    }
  }
  prev
}

///|
/// 1-based index of `node_id` among its element siblings and the element
/// sibling count, defaulting to `(1, 1)` for a root / parentless node.
fn DomTree::element_sibling_position(
  self : DomTree,
  node_id : Int,
) -> (Int, Int) {
  guard self.nodes.get(node_id) is Some(node) else { return (1, 1) }
  guard node.parent_id is Some(pid) else { return (1, 1) }
  guard self.nodes.get(pid) is Some(parent) else { return (1, 1) }
  let mut index = 0
  let mut count = 0
  for child_id in parent.children {
    if self.nodes.get(child_id) is Some(child) && child.node_type == Element {
      count = count + 1
      if child_id == node_id {
        index = count
      }
    }
  }
  if index == 0 {
    (1, 1)
  } else {
    (index, count)
  }
}

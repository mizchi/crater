///|
test "DomTree stores shadow root metadata beyond mode" {
  let tree = DomTree::new()
  let host = tree.create_element("div")
  let init : ShadowRootInit = {
    ..ShadowRootInit::default(mode="closed"),
    delegates_focus: true,
    slot_assignment: "manual",
    clonable: true,
    serializable: true,
  }
  let shadow = tree.attach_shadow_with_init(host, init).unwrap()

  match tree.get_shadow_init(shadow) {
    Ok(Some(actual)) => {
      inspect(actual.mode, content="closed")
      inspect(actual.delegates_focus, content="true")
      inspect(actual.slot_assignment, content="manual")
      inspect(actual.clonable, content="true")
      inspect(actual.serializable, content="true")
    }
    Ok(None) => fail("expected shadow init")
    Err(err) => fail("\{err}")
  }
}

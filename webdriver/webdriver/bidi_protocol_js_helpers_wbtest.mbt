///|
test "locate node JS helpers expose shared roots and shadow child traversal" {
  let roots = locate_nodes_js_shared_roots_from_ids()
  assert_true(roots.contains("globalThis.__bidiSharedNodeStore"))
  assert_true(roots.contains("const __roots = []"))
  assert_true(roots.contains("for (const __id of __ids)"))
  let to_array = locate_nodes_js_to_array()
  assert_true(to_array.contains("const __toArray"))
  assert_true(to_array.contains("Array.from"))
  let collect = locate_nodes_js_collect_element_children()
  assert_true(collect.contains("const __collectChildren"))
  assert_true(collect.contains("shadowRoot"))
  assert_true(collect.contains("__toArray"))
}

///|
test "shared node lookup JS literal escapes ids" {
  inspect(
    bidi_shared_node_lookup_js("node\"\\x"),
    content="((globalThis.__bidiSharedNodeStore && globalThis.__bidiSharedNodeStore.get(\"node\\\"\\\\x\")) ?? undefined)",
  )
  inspect(
    bidi_handle_lookup_js("handle\"\\x"),
    content="((globalThis.__bidiHandleStore && globalThis.__bidiHandleStore.get(\"handle\\\"\\\\x\")) ?? undefined)",
  )
}

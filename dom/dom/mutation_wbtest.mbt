///|
test "DomTree runtime nodes keep explicit ids for later lookup" {
  let tree = DomTree::new()
  let doc = tree.get_document()
  let container = tree.create_runtime_node(
    1000,
    NodeType::Element,
    tag_name="div",
  )
  let text = tree.create_runtime_node(
    1001,
    NodeType::Text,
    text_content="before",
  )
  inspect(container, content="Ok(NodeId(1000))")
  inspect(text, content="Ok(NodeId(1001))")
  match (container, text) {
    (Ok(container_id), Ok(text_id)) => {
      let _ = tree.append_child(doc, container_id)
      let _ = tree.append_child(container_id, text_id)
      let _ = tree.set_text_content(text_id, "after")
      inspect(tree.get_text_content(container_id), content="Ok(\"after\")")
    }
    _ => fail("expected explicit runtime ids")
  }
}

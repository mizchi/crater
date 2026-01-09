///|
test "Document::new creates empty document with viewport" {
  let doc = Document::new(800.0, 600.0)
  inspect(doc.layout.viewport_width, content="800")
  inspect(doc.layout.viewport_height, content="600")
  inspect(doc.needs_layout(), content="true") // Initially needs layout
}

///|
test "Document processes append_child mutation" {
  let doc = Document::new(800.0, 600.0)
  let root = doc.get_document_root()

  // Create and append a div
  let div = doc.create_element("div")
  let _ = doc.append_child(root, div)

  // Should have pending mutations
  inspect(doc.dom.has_pending_mutations(), content="true")

  // Process mutations
  let count = doc.process_mutations()
  inspect(count, content="1")

  // Should have created a layout node
  inspect(doc.dom_to_layout.contains(div.to_int()), content="true")
}

///|
test "Document processes multiple children" {
  let doc = Document::new(800.0, 600.0)
  let root = doc.get_document_root()

  // Create and append multiple divs
  let div1 = doc.create_element("div")
  let div2 = doc.create_element("div")
  let div3 = doc.create_element("div")
  let _ = doc.append_child(root, div1)
  let _ = doc.append_child(root, div2)
  let _ = doc.append_child(root, div3)

  // Process all mutations
  let count = doc.process_mutations()
  // Note: mutations are merged so we get 1 record
  inspect(count, content="1")

  // All should be in layout tree
  inspect(doc.dom_to_layout.contains(div1.to_int()), content="true")
  inspect(doc.dom_to_layout.contains(div2.to_int()), content="true")
  inspect(doc.dom_to_layout.contains(div3.to_int()), content="true")

  // Layout root should have children
  inspect(doc.layout.root.children.length(), content="3")
}

///|
test "Document processes nested structure" {
  let doc = Document::new(800.0, 600.0)
  let root = doc.get_document_root()

  // Create nested structure: root > parent > child
  let parent = doc.create_element("div")
  let _ = doc.append_child(root, parent)
  let _ = doc.process_mutations()
  let child = doc.create_element("span")
  let _ = doc.append_child(parent, child)
  let _ = doc.process_mutations()

  // Child should be in layout tree
  inspect(doc.dom_to_layout.contains(child.to_int()), content="true")

  // Parent should have child in layout tree
  let parent_uid = doc.dom_to_layout.get(parent.to_int())
  match parent_uid {
    Some(uid) =>
      match doc.layout.find_node(uid) {
        Some(parent_node) => inspect(parent_node.children.length(), content="1")
        None => inspect("parent not found", content="parent found")
      }
    None => inspect("mapping not found", content="mapping found")
  }
}

///|
test "Document processes remove_child mutation" {
  let doc = Document::new(800.0, 600.0)
  let root = doc.get_document_root()

  // Create and append a div
  let div = doc.create_element("div")
  let _ = doc.append_child(root, div)
  let _ = doc.process_mutations()

  // Verify it was added
  inspect(doc.dom_to_layout.contains(div.to_int()), content="true")
  let initial_children = doc.layout.root.children.length()

  // Remove it
  let _ = doc.dom.remove_child(root, div)
  let _ = doc.process_mutations()

  // Should be removed from layout tree
  inspect(doc.dom_to_layout.contains(div.to_int()), content="false")
  inspect(doc.layout.root.children.length() < initial_children, content="true")
}

///|
test "Document update combines mutation processing and layout" {
  let doc = Document::new(400.0, 300.0)
  let root = doc.get_document_root()

  // Create a div with style
  let div = doc.create_element("div")
  let _ = doc.append_child(root, div)

  // Update should process mutations and compute layout
  let layout = doc.update()

  // Layout should have been computed
  inspect(layout.width > 0.0, content="true")
  inspect(layout.height > 0.0, content="true")
}

///|
test "Document resize_viewport triggers layout" {
  let doc = Document::new(800.0, 600.0)

  // Initial state
  inspect(doc.layout.viewport_width, content="800")

  // Resize
  doc.resize_viewport(1024.0, 768.0)
  inspect(doc.layout.viewport_width, content="1024")
  inspect(doc.layout.viewport_height, content="768")
  inspect(doc.needs_layout(), content="true")
}

///|
test "Document set_attribute records mutation" {
  let doc = Document::new(800.0, 600.0)
  let root = doc.get_document_root()
  let div = doc.create_element("div")
  let _ = doc.append_child(root, div)
  let _ = doc.process_mutations()

  // Set an attribute
  let _ = doc.set_attribute(div, "class", "container")

  // Should have pending mutation
  inspect(doc.dom.has_pending_mutations(), content="true")

  // Process
  let _ = doc.process_mutations()
  inspect(doc.dom.has_pending_mutations(), content="false")
}

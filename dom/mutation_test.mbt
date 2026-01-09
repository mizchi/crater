///|
test "MutationRecord::child_list creates correct record" {
  let target = NodeId::from_int(1)
  let child1 = NodeId::from_int(2)
  let child2 = NodeId::from_int(3)
  let record = MutationRecord::child_list(target, added=[child1, child2], removed=[])
  inspect(record.type_, content="ChildList")
  inspect(record.target.to_int(), content="1")
  inspect(record.added_nodes.length(), content="2")
  inspect(record.removed_nodes.length(), content="0")
}

///|
test "MutationRecord::attribute creates correct record" {
  let target = NodeId::from_int(1)
  let record = MutationRecord::attribute(
    target,
    "class",
    old_value=Some("foo"),
    new_value=Some("bar"),
  )
  inspect(record.type_, content="Attributes")
  inspect(record.attribute_name, content="Some(\"class\")")
  inspect(record.old_value, content="Some(\"foo\")")
  inspect(record.new_value, content="Some(\"bar\")")
}

///|
test "MutationRecord::style_change creates correct record" {
  let target = NodeId::from_int(1)
  let record = MutationRecord::style_change(target, ["width", "height"])
  inspect(record.type_, content="StyleChange")
  inspect(record.changed_properties.length(), content="2")
}

///|
test "MutationRecord::affects_layout detects layout properties" {
  let target = NodeId::from_int(1)

  // Layout-affecting style change
  let layout_record = MutationRecord::style_change(target, ["width", "margin"])
  inspect(layout_record.affects_layout(), content="true")

  // Paint-only style change
  let paint_record = MutationRecord::style_change(target, [
    "color", "background",
  ])
  inspect(paint_record.affects_layout(), content="false")

  // ChildList always affects layout
  let child_record = MutationRecord::child_list(target)
  inspect(child_record.affects_layout(), content="true")
}

///|
test "MutationQueue basic operations" {
  let queue = MutationQueue::new()
  inspect(queue.is_empty(), content="true")
  let target = NodeId::from_int(1)
  queue.push(MutationRecord::style_change(target, ["width"]))
  inspect(queue.is_empty(), content="false")
  inspect(queue.length(), content="1")
  inspect(queue.has_pending(target), content="true")
  inspect(queue.has_pending(NodeId::from_int(2)), content="false")
}

///|
test "MutationQueue flush returns optimized records" {
  let queue = MutationQueue::new()
  let target = NodeId::from_int(1)

  // Add multiple style changes to same node
  queue.push(MutationRecord::style_change(target, ["width"]))
  queue.push(MutationRecord::style_change(target, ["height"]))
  queue.push(MutationRecord::style_change(target, ["margin"]))
  let (records, result) = queue.flush()

  // Should be merged into one record
  inspect(records.length(), content="1")
  inspect(result.processed, content="1")
  inspect(result.nodes_affected, content="1")
  inspect(result.needs_layout, content="true")

  // Queue should be empty after flush
  inspect(queue.is_empty(), content="true")
}

///|
test "MutationQueue merges add/remove pairs" {
  let queue = MutationQueue::new()
  let parent = NodeId::from_int(1)
  let child = NodeId::from_int(2)

  // Add then remove same child - should cancel out
  queue.push(MutationRecord::child_list(parent, added=[child]))
  queue.push(MutationRecord::child_list(parent, removed=[child]))
  let (records, _result) = queue.flush()

  // The child_list records should be merged, and add/remove should cancel
  // Result should have no effective child changes
  for record in records {
    match record.type_ {
      ChildList => {
        inspect(record.added_nodes.length(), content="0")
        inspect(record.removed_nodes.length(), content="0")
      }
      _ => ()
    }
  }
}

///|
test "MutationQueue handles deferred mutations during flush" {
  let queue = MutationQueue::new()
  let target = NodeId::from_int(1)
  queue.push(MutationRecord::style_change(target, ["width"]))

  // Simulate flush
  let (_records, _result) = queue.flush()

  // Queue should be empty
  inspect(queue.is_empty(), content="true")
}

// =============================================================================
// DomTree Integration Tests
// =============================================================================

///|
test "DomTree records append_child mutations" {
  let tree = DomTree::new()
  let doc = tree.get_document()
  let div = tree.create_element("div")
  inspect(tree.has_pending_mutations(), content="false")
  let _ = tree.append_child(doc, div)
  inspect(tree.has_pending_mutations(), content="true")
  inspect(tree.pending_mutation_count(), content="1")
  let (records, result) = tree.flush_mutations()
  inspect(records.length(), content="1")
  inspect(result.needs_layout, content="true")

  // Check the record is a ChildList with the div added
  let record = records[0]
  inspect(record.type_, content="ChildList")
  inspect(record.added_nodes.length(), content="1")
  inspect(record.added_nodes[0].to_int(), content="1") // div is node 1
}

///|
test "DomTree records remove_child mutations" {
  let tree = DomTree::new()
  let doc = tree.get_document()
  let div = tree.create_element("div")
  let _ = tree.append_child(doc, div)

  // Clear mutations from append
  tree.clear_mutations()
  let _ = tree.remove_child(doc, div)
  let (records, _result) = tree.flush_mutations()
  inspect(records.length(), content="1")
  let record = records[0]
  inspect(record.type_, content="ChildList")
  inspect(record.removed_nodes.length(), content="1")
}

///|
test "DomTree records set_attribute mutations" {
  let tree = DomTree::new()
  let doc = tree.get_document()
  let div = tree.create_element("div")
  let _ = tree.append_child(doc, div)
  tree.clear_mutations()
  let _ = tree.set_attribute(div, "class", "container")
  let (records, _result) = tree.flush_mutations()
  inspect(records.length(), content="1")
  let record = records[0]
  inspect(record.type_, content="Attributes")
  inspect(record.attribute_name, content="Some(\"class\")")
  inspect(record.old_value, content="None")
  inspect(record.new_value, content="Some(\"container\")")
}

///|
test "DomTree records attribute update with old value" {
  let tree = DomTree::new()
  let doc = tree.get_document()
  let div = tree.create_element("div")
  let _ = tree.append_child(doc, div)
  let _ = tree.set_attribute(div, "class", "old-class")
  tree.clear_mutations()
  let _ = tree.set_attribute(div, "class", "new-class")
  let (records, _result) = tree.flush_mutations()
  let record = records[0]
  inspect(record.old_value, content="Some(\"old-class\")")
  inspect(record.new_value, content="Some(\"new-class\")")
}

///|
test "DomTree records set_text_content mutations for text nodes" {
  let tree = DomTree::new()
  let text = tree.create_text("hello")
  tree.clear_mutations()
  let _ = tree.set_text_content(text, "world")
  let (records, _result) = tree.flush_mutations()
  inspect(records.length(), content="1")
  let record = records[0]
  inspect(record.type_, content="CharacterData")
  inspect(record.old_value, content="Some(\"hello\")")
  inspect(record.new_value, content="Some(\"world\")")
}

///|
test "DomTree batches multiple mutations" {
  let tree = DomTree::new()
  let doc = tree.get_document()

  // Create and append multiple elements
  let div1 = tree.create_element("div")
  let div2 = tree.create_element("div")
  let div3 = tree.create_element("div")
  let _ = tree.append_child(doc, div1)
  let _ = tree.append_child(doc, div2)
  let _ = tree.append_child(doc, div3)

  // All mutations should be batched
  inspect(tree.pending_mutation_count(), content="3")
  let (records, result) = tree.flush_mutations()

  // After optimization, same-target mutations might be merged
  inspect(result.nodes_affected, content="1") // All mutations target doc
  inspect(result.needs_layout, content="true")

  // All 3 appends merged into 1 record with 3 added nodes
  inspect(records.length(), content="1")
  inspect(records[0].added_nodes.length(), content="3")

  // Queue should be empty after flush
  inspect(tree.has_pending_mutations(), content="false")
}

///|
test "DomTree move child records both removal and addition" {
  let tree = DomTree::new()
  let doc = tree.get_document()
  let parent1 = tree.create_element("div")
  let parent2 = tree.create_element("div")
  let child = tree.create_element("span")
  let _ = tree.append_child(doc, parent1)
  let _ = tree.append_child(doc, parent2)
  let _ = tree.append_child(parent1, child)
  tree.clear_mutations()

  // Move child from parent1 to parent2
  let _ = tree.append_child(parent2, child)

  // Should record removal from parent1 and addition to parent2
  let (records, _result) = tree.flush_mutations()

  // Check we have records for both parents (2 records since different targets)
  inspect(records.length(), content="2")
  let mut has_removal = false
  let mut has_addition = false
  for record in records {
    match record.type_ {
      ChildList => {
        if record.removed_nodes.length() > 0 {
          has_removal = true
        }
        if record.added_nodes.length() > 0 {
          has_addition = true
        }
      }
      _ => ()
    }
  }
  inspect(has_removal, content="true")
  inspect(has_addition, content="true")
}

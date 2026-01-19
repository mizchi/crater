///|
test "NodeType enum coverage" {
  // Ensure all NodeType variants are used to avoid unused constructor warnings
  let types = [
    NodeType::Document,
    NodeType::DocumentType,
    NodeType::Element,
    NodeType::Text,
    NodeType::Comment,
  ]
  inspect(types.length(), content="5")
}

///|
test "aomx facade extracts content and computes grounding" {
  let html =
    #|<!DOCTYPE html>
    #|<html>
    #|  <body>
    #|    <header><a href="/home">Home</a></header>
    #|    <main>
    #|      <article>
    #|        <h1>Facade Title</h1>
    #|        <p>Main content body.</p>
    #|      </article>
    #|    </main>
    #|  </body>
    #|</html>
  let document = @dom.parse_document(html)
  let tree = @dom.build_accessibility_tree(document)
  let grounded_tree = @dom.AccessibilityTree::new(
    @dom.AccessibilityNode::new("hero", @dom.Role::Button).with_bounds(
      @dom.Bounds::new(480.0, 280.0, 120.0, 48.0),
    ),
  )

  let config = { ..ExtractConfig::default(), min_text_length: 1 }
  let extraction = extract_content(tree, config)
  let grounded = find_best(
    grounded_tree,
    SpatialQuery::InRegion(SpatialRegion::Center),
    { width: 1280.0, height: 720.0 },
  )

  inspect(extraction.main_content is Some(_), content="true")
  inspect(grounded is Some(_), content="true")
}

///|
test "aomx facade diffs accessibility trees" {
  let before = @dom.build_accessibility_tree(
    @dom.parse_document(
      "<html><body><main><button>Before</button></main></body></html>",
    ),
  )
  let after = @dom.build_accessibility_tree(
    @dom.parse_document(
      "<html><body><main><button>After</button></main></body></html>",
    ),
  )

  let diff = diff_trees(before, after, DiffConfig::default())

  inspect(diff.changed_count > 0, content="true")
  inspect(trees_equal(before, after), content="false")
}

///|
struct ComponentFixture {
  target_id : String
  html : String
  baseline_css : String
  component_css : String
  viewport_width : Int
  viewport_height : Int
}

///|
fn ComponentFixture::render_ctx(
  self : ComponentFixture,
) -> @renderer.RenderContext {
  make_render_ctx(self.viewport_width, self.viewport_height)
}

///|
fn ComponentFixture::external_css(self : ComponentFixture) -> Array[String] {
  [self.baseline_css, self.component_css]
}

///|
fn ComponentFixture::target_node_id(self : ComponentFixture) -> String {
  "vrt-target#" + self.target_id
}

///|
fn component_baseline_css() -> String {
  let css =
    #|:root {
    #|  color-scheme: light;
    #|  --bg: #f4f6fb;
    #|  --surface: #ffffff;
    #|  --surface-muted: #eef2f8;
    #|  --border: #d8dee8;
    #|  --text: #17212b;
    #|  --muted: #5f6b7a;
    #|  --accent: #1463ff;
    #|}
    #|* {
    #|  box-sizing: border-box;
    #|}
    #|html, body {
    #|  margin: 0;
    #|  padding: 0;
    #|  background: var(--bg);
    #|  color: var(--text);
    #|  font-family: ui-sans-serif, system-ui, sans-serif;
    #|}
    #|body {
    #|  padding: 24px;
    #|}
    #|main-shell {
    #|  display: grid;
    #|  gap: 20px;
    #|}
    #|fixture-noise {
    #|  display: grid;
    #|  grid-template-columns: repeat(3, minmax(0, 1fr));
    #|  gap: 12px;
    #|}
    #|fixture-noise > div {
    #|  min-height: 18px;
    #|  border-radius: 999px;
    #|  background: linear-gradient(90deg, #dfe5ee 0%, #eef2f7 100%);
    #|}
    #|vrt-target {
    #|  display: block;
    #|}
  css
}

///|
fn build_noise_blocks(count : Int) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<fixture-noise>")
  for i = 0; i < count; i = i + 1 {
    buf.write_string("<div data-noise=\"")
    buf.write_string(i.to_string())
    buf.write_string("\"></div>")
  }
  buf.write_string("</fixture-noise>")
  buf.to_string()
}

///|
fn wrap_component_fixture(
  target_id : String,
  component_inner : String,
  noise_before : Int,
  noise_after : Int,
) -> String {
  let buf = StringBuilder::new()
  buf.write_string("<!DOCTYPE html><html><body><main-shell>")
  buf.write_string(build_noise_blocks(noise_before))
  buf.write_string("<vrt-target id=\"")
  buf.write_string(target_id)
  buf.write_string("\">")
  buf.write_string(component_inner)
  buf.write_string("</vrt-target>")
  buf.write_string(build_noise_blocks(noise_after))
  buf.write_string("</main-shell></body></html>")
  buf.to_string()
}

///|
fn component_fixture_xs() -> ComponentFixture {
  let component_inner =
    #|<section class="card" role="region" aria-label="Billing Status">
    #|  <p class="eyebrow">Status</p>
    #|  <h2>Billing Ready</h2>
    #|  <p class="body">Invoice automation is active for the current workspace.</p>
    #|  <nav class="meta-row" aria-label="Billing tags">
    #|    <span class="chip">Auto</span>
    #|    <span class="chip">USD</span>
    #|    <span class="chip">Live</span>
    #|  </nav>
    #|  <button class="primary">Open</button>
    #|</section>
  let html = wrap_component_fixture("xs-root", component_inner, 6, 6)
  let component_css =
    #|.card {
    #|  width: 280px;
    #|  padding: 16px;
    #|  border: 1px solid var(--border);
    #|  border-radius: 16px;
    #|  background: var(--surface);
    #|}
    #|.eyebrow {
    #|  margin: 0 0 10px;
    #|  color: var(--muted);
    #|  font-size: 12px;
    #|  text-transform: uppercase;
    #|}
    #|.card h2 {
    #|  margin: 0 0 8px;
    #|  font-size: 20px;
    #|}
    #|.body {
    #|  margin: 0 0 12px;
    #|  font-size: 14px;
    #|  line-height: 1.45;
    #|}
    #|.meta-row {
    #|  display: flex;
    #|  gap: 8px;
    #|  margin-bottom: 14px;
    #|}
    #|.chip {
    #|  padding: 4px 8px;
    #|  border-radius: 999px;
    #|  background: var(--surface-muted);
    #|  font-size: 12px;
    #|}
    #|.primary {
    #|  display: block;
    #|  width: 100%;
    #|  border: 0;
    #|  border-radius: 10px;
    #|  padding: 10px 12px;
    #|  background: var(--accent);
    #|  color: #ffffff;
    #|}
  {
    target_id: "xs-root",
    html,
    baseline_css: component_baseline_css(),
    component_css,
    viewport_width: 480,
    viewport_height: 320,
  }
}

///|
fn component_fixture_s() -> ComponentFixture {
  let component_inner =
    #|<section class="panel" role="region" aria-label="Deployment Batch">
    #|  <header class="panel-header">
    #|    <div>
    #|      <p class="eyebrow">Queue</p>
    #|      <h2>Deployment Batch</h2>
    #|    </div>
    #|    <span class="status">Healthy</span>
    #|  </header>
    #|  <ul class="metrics">
    #|    <li><strong>18</strong><span>jobs</span></li>
    #|    <li><strong>3</strong><span>regions</span></li>
    #|    <li><strong>96%</strong><span>pass</span></li>
    #|  </ul>
    #|  <div class="events" role="navigation" aria-label="Regional queues">
    #|    <article><h3>Tokyo</h3><p>4 queued, 12s median startup.</p></article>
    #|    <article><h3>Virginia</h3><p>7 queued, 10s median startup.</p></article>
    #|    <article><h3>Frankfurt</h3><p>7 queued, 14s median startup.</p></article>
    #|  </div>
    #|  <footer class="actions" role="contentinfo" aria-label="Deployment actions">
    #|    <button class="ghost">Inspect</button>
    #|    <button class="primary">Promote</button>
    #|  </footer>
    #|</section>
  let html = wrap_component_fixture("s-root", component_inner, 12, 9)
  let component_css =
    #|.panel {
    #|  width: 520px;
    #|  padding: 20px;
    #|  border: 1px solid var(--border);
    #|  border-radius: 20px;
    #|  background: var(--surface);
    #|}
    #|.panel-header {
    #|  display: flex;
    #|  justify-content: space-between;
    #|  align-items: start;
    #|  gap: 16px;
    #|  margin-bottom: 18px;
    #|}
    #|.eyebrow {
    #|  margin: 0 0 8px;
    #|  color: var(--muted);
    #|  font-size: 12px;
    #|  text-transform: uppercase;
    #|}
    #|.panel-header h2 {
    #|  margin: 0;
    #|  font-size: 28px;
    #|}
    #|.status {
    #|  padding: 8px 12px;
    #|  border-radius: 999px;
    #|  background: #dff6e8;
    #|  color: #13693b;
    #|}
    #|.metrics {
    #|  display: grid;
    #|  grid-template-columns: repeat(3, minmax(0, 1fr));
    #|  gap: 12px;
    #|  margin: 0 0 18px;
    #|  padding: 0;
    #|  list-style: none;
    #|}
    #|.metrics li {
    #|  padding: 12px;
    #|  border-radius: 14px;
    #|  background: var(--surface-muted);
    #|}
    #|.metrics strong {
    #|  display: block;
    #|  font-size: 24px;
    #|}
    #|.metrics span {
    #|  color: var(--muted);
    #|  font-size: 13px;
    #|}
    #|.events {
    #|  display: grid;
    #|  gap: 10px;
    #|  margin-bottom: 18px;
    #|}
    #|.events article {
    #|  padding: 14px 16px;
    #|  border: 1px solid var(--border);
    #|  border-radius: 14px;
    #|}
    #|.events h3 {
    #|  margin: 0 0 6px;
    #|  font-size: 16px;
    #|}
    #|.events p {
    #|  margin: 0;
    #|  color: var(--muted);
    #|  line-height: 1.5;
    #|}
    #|.actions {
    #|  display: flex;
    #|  justify-content: end;
    #|  gap: 10px;
    #|}
    #|.ghost, .primary {
    #|  border-radius: 10px;
    #|  padding: 10px 14px;
    #|}
    #|.ghost {
    #|  border: 1px solid var(--border);
    #|  background: transparent;
    #|}
    #|.primary {
    #|  border: 0;
    #|  background: var(--accent);
    #|  color: #ffffff;
    #|}
  {
    target_id: "s-root",
    html,
    baseline_css: component_baseline_css(),
    component_css,
    viewport_width: 800,
    viewport_height: 600,
  }
}

///|
fn component_fixture_m() -> ComponentFixture {
  let buf = StringBuilder::new()
  buf.write_string(
    "<section class=\"dialog\" role=\"main\" aria-label=\"Release Checklist\">",
  )
  buf.write_string(
    "<header class=\"dialog-header\"><div><p class=\"eyebrow\">Editor</p><h2>Release Checklist</h2></div><p class=\"subtitle\">Scope, owners, rollout and verification for a single release train.</p></header>",
  )
  buf.write_string(
    "<div class=\"grid\" role=\"form\" aria-label=\"Release fields\">",
  )
  for section = 0; section < 3; section = section + 1 {
    buf.write_string("<section class=\"field-group\"><h3>Section ")
    buf.write_string(section.to_string())
    buf.write_string("</h3>")
    for row = 0; row < 4; row = row + 1 {
      buf.write_string("<label class=\"field\"><span>Field ")
      buf.write_string(section.to_string())
      buf.write_string("-")
      buf.write_string(row.to_string())
      buf.write_string("</span><input value=\"")
      buf.write_string("ready")
      buf.write_string("\" /></label>")
    }
    buf.write_string("</section>")
  }
  buf.write_string("</div>")
  buf.write_string(
    "<table class=\"matrix\" role=\"region\" aria-label=\"Release matrix\"><thead><tr><th>Step</th><th>Owner</th><th>Status</th><th>ETA</th></tr></thead><tbody>",
  )
  for row = 0; row < 10; row = row + 1 {
    buf.write_string("<tr><td>Phase ")
    buf.write_string(row.to_string())
    buf.write_string("</td><td>team-")
    buf.write_string((row % 4).to_string())
    buf.write_string(
      "</td><td><span class=\"status-chip\">green</span></td><td>",
    )
    buf.write_string((row * 3 + 4).to_string())
    buf.write_string(" min</td></tr>")
  }
  buf.write_string("</tbody></table>")
  buf.write_string(
    "<footer class=\"dialog-footer\" role=\"contentinfo\" aria-label=\"Dialog actions\"><button class=\"ghost\">Cancel</button><button class=\"primary\">Ship</button></footer>",
  )
  buf.write_string("</section>")
  let html = wrap_component_fixture("m-root", buf.to_string(), 18, 15)
  let component_css =
    #|.dialog {
    #|  width: 860px;
    #|  padding: 24px;
    #|  border: 1px solid var(--border);
    #|  border-radius: 24px;
    #|  background: var(--surface);
    #|}
    #|.dialog-header {
    #|  display: grid;
    #|  grid-template-columns: minmax(0, 1fr) 280px;
    #|  gap: 18px;
    #|  margin-bottom: 20px;
    #|}
    #|.eyebrow {
    #|  margin: 0 0 8px;
    #|  color: var(--muted);
    #|  font-size: 12px;
    #|  text-transform: uppercase;
    #|}
    #|.dialog-header h2 {
    #|  margin: 0;
    #|  font-size: 30px;
    #|}
    #|.subtitle {
    #|  margin: 0;
    #|  color: var(--muted);
    #|  line-height: 1.6;
    #|}
    #|.grid {
    #|  display: grid;
    #|  grid-template-columns: repeat(3, minmax(0, 1fr));
    #|  gap: 16px;
    #|  margin-bottom: 20px;
    #|}
    #|.field-group {
    #|  padding: 16px;
    #|  border-radius: 18px;
    #|  background: var(--surface-muted);
    #|}
    #|.field-group h3 {
    #|  margin: 0 0 12px;
    #|  font-size: 18px;
    #|}
    #|.field {
    #|  display: grid;
    #|  gap: 8px;
    #|  margin-bottom: 12px;
    #|}
    #|.field span {
    #|  font-size: 13px;
    #|  color: var(--muted);
    #|}
    #|.field input {
    #|  width: 100%;
    #|  padding: 10px 12px;
    #|  border: 1px solid var(--border);
    #|  border-radius: 10px;
    #|  background: #ffffff;
    #|}
    #|.matrix {
    #|  width: 100%;
    #|  border-collapse: collapse;
    #|  margin-bottom: 20px;
    #|}
    #|.matrix th, .matrix td {
    #|  padding: 12px 10px;
    #|  border-bottom: 1px solid var(--border);
    #|  text-align: left;
    #|}
    #|.matrix th {
    #|  color: var(--muted);
    #|  font-size: 13px;
    #|}
    #|.status-chip {
    #|  padding: 6px 10px;
    #|  border-radius: 999px;
    #|  background: #dff6e8;
    #|  color: #13693b;
    #|}
    #|.dialog-footer {
    #|  display: flex;
    #|  justify-content: end;
    #|  gap: 12px;
    #|}
    #|.ghost, .primary {
    #|  border-radius: 10px;
    #|  padding: 10px 16px;
    #|}
    #|.ghost {
    #|  border: 1px solid var(--border);
    #|  background: transparent;
    #|}
    #|.primary {
    #|  border: 0;
    #|  background: var(--accent);
    #|  color: #ffffff;
    #|}
  {
    target_id: "m-root",
    html,
    baseline_css: component_baseline_css(),
    component_css,
    viewport_width: 1280,
    viewport_height: 960,
  }
}

///|
fn component_fixture_l() -> ComponentFixture {
  let buf = StringBuilder::new()
  buf.write_string(
    "<section class=\"dashboard\" role=\"main\" aria-label=\"Operations Overview\">",
  )
  buf.write_string(
    "<header class=\"hero\"><div><p class=\"eyebrow\">Insights</p><h2>Operations Overview</h2><p class=\"lede\">A bounded dashboard fixture for higher-cost component snapshots.</p></div><div class=\"hero-stats\"><strong>128</strong><span>active incidents</span></div></header>",
  )
  buf.write_string(
    "<div class=\"tiles\" role=\"region\" aria-label=\"Summary tiles\">",
  )
  for tile = 0; tile < 8; tile = tile + 1 {
    buf.write_string("<article class=\"tile\"><p class=\"tile-label\">Tile ")
    buf.write_string(tile.to_string())
    buf.write_string("</p><strong>")
    buf.write_string((tile * 13 + 20).to_string())
    buf.write_string(
      "</strong><p class=\"tile-copy\">Synthetic tile data for artifact benchmarks.</p></article>",
    )
  }
  buf.write_string("</div>")
  buf.write_string("<section class=\"two-column\">")
  buf.write_string(
    "<div class=\"timeline\" role=\"navigation\" aria-label=\"Incident timeline\">",
  )
  for item = 0; item < 18; item = item + 1 {
    buf.write_string("<article class=\"event\"><h3>Event ")
    buf.write_string(item.to_string())
    buf.write_string("</h3><p>Deployment shard ")
    buf.write_string((item % 5).to_string())
    buf.write_string(
      " crossed the alert threshold and triggered operator review.</p></article>",
    )
  }
  buf.write_string(
    "</div><div class=\"summary\" role=\"region\" aria-label=\"Cluster summary\"><table class=\"matrix\"><thead><tr><th>Cluster</th><th>Load</th><th>Error</th></tr></thead><tbody>",
  )
  for row = 0; row < 24; row = row + 1 {
    buf.write_string("<tr><td>cluster-")
    buf.write_string(row.to_string())
    buf.write_string("</td><td>")
    buf.write_string((row * 7 + 30).to_string())
    buf.write_string("%</td><td>")
    buf.write_string((row % 4).to_string())
    buf.write_string(" ppm</td></tr>")
  }
  buf.write_string("</tbody></table></div></section>")
  buf.write_string("</section>")
  let html = wrap_component_fixture("l-root", buf.to_string(), 24, 20)
  let component_css =
    #|.dashboard {
    #|  width: 1120px;
    #|  padding: 28px;
    #|  border: 1px solid var(--border);
    #|  border-radius: 26px;
    #|  background: var(--surface);
    #|}
    #|.hero {
    #|  display: grid;
    #|  grid-template-columns: minmax(0, 1fr) 220px;
    #|  gap: 24px;
    #|  margin-bottom: 22px;
    #|}
    #|.eyebrow {
    #|  margin: 0 0 8px;
    #|  color: var(--muted);
    #|  font-size: 12px;
    #|  text-transform: uppercase;
    #|}
    #|.hero h2 {
    #|  margin: 0 0 8px;
    #|  font-size: 36px;
    #|}
    #|.lede {
    #|  margin: 0;
    #|  color: var(--muted);
    #|  line-height: 1.6;
    #|}
    #|.hero-stats {
    #|  padding: 20px;
    #|  border-radius: 18px;
    #|  background: var(--surface-muted);
    #|}
    #|.hero-stats strong {
    #|  display: block;
    #|  font-size: 42px;
    #|}
    #|.tiles {
    #|  display: grid;
    #|  grid-template-columns: repeat(4, minmax(0, 1fr));
    #|  gap: 14px;
    #|  margin-bottom: 22px;
    #|}
    #|.tile {
    #|  padding: 16px;
    #|  border-radius: 16px;
    #|  background: var(--surface-muted);
    #|}
    #|.tile-label {
    #|  margin: 0 0 8px;
    #|  color: var(--muted);
    #|}
    #|.tile strong {
    #|  display: block;
    #|  margin-bottom: 6px;
    #|  font-size: 26px;
    #|}
    #|.tile-copy {
    #|  margin: 0;
    #|  line-height: 1.5;
    #|}
    #|.two-column {
    #|  display: grid;
    #|  grid-template-columns: minmax(0, 1.3fr) minmax(0, 1fr);
    #|  gap: 18px;
    #|}
    #|.timeline, .summary {
    #|  padding: 16px;
    #|  border: 1px solid var(--border);
    #|  border-radius: 18px;
    #|}
    #|.event {
    #|  padding: 12px 0;
    #|  border-bottom: 1px solid var(--border);
    #|}
    #|.event h3 {
    #|  margin: 0 0 6px;
    #|  font-size: 17px;
    #|}
    #|.event p {
    #|  margin: 0;
    #|  color: var(--muted);
    #|  line-height: 1.55;
    #|}
    #|.matrix {
    #|  width: 100%;
    #|  border-collapse: collapse;
    #|}
    #|.matrix th, .matrix td {
    #|  padding: 10px 8px;
    #|  border-bottom: 1px solid var(--border);
    #|  text-align: left;
    #|}
    #|.matrix th {
    #|  color: var(--muted);
    #|  font-size: 13px;
    #|}
  {
    target_id: "l-root",
    html,
    baseline_css: component_baseline_css(),
    component_css,
    viewport_width: 1440,
    viewport_height: 1280,
  }
}

///|
struct LandmarkTree {
  role : String
  name : String?
  source_id : String?
  children : Array[LandmarkTree]
}

///|
fn find_component_element(
  element : @html.Element,
  target_id : String,
) -> @html.Element? {
  match element.id {
    Some(id) if id == target_id => return Some(element)
    _ => ()
  }
  for child in element.children {
    match child {
      @html.Node::Element(child_elem) =>
        match find_component_element(child_elem, target_id) {
          Some(found) => return Some(found)
          None => ()
        }
      _ => ()
    }
  }
  None
}

///|
fn parse_component_fixture_document(
  fixture : ComponentFixture,
) -> @html.Document {
  @html.assign_synthetic_ids(@html.parse_document(fixture.html))
}

///|
fn get_component_root_element(fixture : ComponentFixture) -> @html.Element {
  let doc = parse_component_fixture_document(fixture)
  match find_component_element(doc.root, fixture.target_id) {
    Some(element) => element
    None => panic()
  }
}

///|
fn build_component_a11y_tree(
  fixture : ComponentFixture,
) -> @aom.AccessibilityTree {
  @aom.build_accessibility_tree_from_element(
    get_component_root_element(fixture),
  )
}

///|
fn collect_landmark_forest(
  node : @aom.AccessibilityNode,
) -> Array[LandmarkTree] {
  let children : Array[LandmarkTree] = []
  for child in node.children {
    let child_landmarks = collect_landmark_forest(child)
    for landmark in child_landmarks {
      children.push(landmark)
    }
  }
  if @aom.role_is_landmark(node.role) {
    let landmark : LandmarkTree = {
      role: node.role.to_string(),
      name: node.name,
      source_id: node.source_id,
      children,
    }
    [landmark]
  } else {
    children
  }
}

///|
fn render_landmark_node_json(node : LandmarkTree, buf : StringBuilder) -> Unit {
  buf.write_string("{\"role\":\"")
  buf.write_string(node.role)
  buf.write_string("\"")
  match node.name {
    Some(name) if not(name.is_empty()) => {
      buf.write_string(",\"name\":\"")
      buf.write_string(name)
      buf.write_string("\"")
    }
    _ => ()
  }
  match node.source_id {
    Some(source_id) if not(source_id.is_empty()) => {
      buf.write_string(",\"sourceId\":\"")
      buf.write_string(source_id)
      buf.write_string("\"")
    }
    _ => ()
  }
  buf.write_string(",\"children\":[")
  for i = 0; i < node.children.length(); i = i + 1 {
    if i > 0 {
      buf.write_string(",")
    }
    render_landmark_node_json(node.children[i], buf)
  }
  buf.write_string("]}")
}

///|
fn render_landmark_forest_json(forest : Array[LandmarkTree]) -> String {
  let buf = StringBuilder::new()
  buf.write_string("[")
  for i = 0; i < forest.length(); i = i + 1 {
    if i > 0 {
      buf.write_string(",")
    }
    render_landmark_node_json(forest[i], buf)
  }
  buf.write_string("]")
  buf.to_string()
}

///|
fn render_component_landmark_artifact(fixture : ComponentFixture) -> String {
  let tree = build_component_a11y_tree(fixture)
  render_landmark_forest_json(collect_landmark_forest(tree.root))
}

///|
fn find_component_subtree(
  node : @node.Node,
  layout : @types.Layout,
  target_id : String,
) -> (@node.Node, @types.Layout)? {
  if node.id == target_id && layout.id == target_id {
    return Some((node, layout))
  }
  let child_count = if node.children.length() < layout.children.length() {
    node.children.length()
  } else {
    layout.children.length()
  }
  for i = 0; i < child_count; i = i + 1 {
    match
      find_component_subtree(node.children[i], layout.children[i], target_id) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
fn normalize_component_layout(layout : @types.Layout) -> @types.Layout {
  { ..layout, x: 0.0, y: 0.0 }
}

///|
fn pixel_span(value : Double) -> Int {
  let rounded = value.ceil().to_int()
  if rounded > 0 {
    rounded
  } else {
    1
  }
}

///|
fn render_fixture_node_and_layout(
  fixture : ComponentFixture,
) -> (@node.Node, @types.Layout) {
  @renderer.render_to_node_and_layout_with_external_css(
    fixture.html,
    fixture.render_ctx(),
    fixture.external_css(),
  )
}

///|
fn render_component_subtree(
  fixture : ComponentFixture,
) -> (@node.Node, @types.Layout) {
  let (node, layout) = render_fixture_node_and_layout(fixture)
  match find_component_subtree(node, layout, fixture.target_node_id()) {
    Some(found) => found
    None => panic()
  }
}

///|
fn render_component_layout_artifact(fixture : ComponentFixture) -> String {
  let (_, layout) = render_component_subtree(fixture)
  @renderer.layout_to_json(normalize_component_layout(layout))
}

///|
fn render_component_paint_node(
  fixture : ComponentFixture,
) -> (@paint.PaintNode, Int, Int) {
  let (node, layout) = render_component_subtree(fixture)
  let normalized = normalize_component_layout(layout)
  let paint_node = @paint.from_node_and_layout(node, normalized)
  let width = pixel_span(normalized.width)
  let height = pixel_span(normalized.height)
  (paint_node, width, height)
}

///|
fn raster_component_paint(
  paint_node : @paint.PaintNode,
  width : Int,
  height : Int,
) -> (@image.Framebuffer, @image.DynamicPalette) {
  let fb = @image.Framebuffer::new(width, height)
  let palette = @image.DynamicPalette::new()
  @image.render_paint_node_to_framebuffer(paint_node, fb, palette)
  (fb, palette)
}

///|
fn render_component_image_artifact(fixture : ComponentFixture) -> String {
  let (paint_node, width, height) = render_component_paint_node(fixture)
  let (fb, palette) = raster_component_paint(paint_node, width, height)
  @image.framebuffer_to_rgba_base64(fb, palette)
}

///|
test "component fixture subtree extraction resolves target root" {
  let fixture = component_fixture_s()
  let (node, layout) = render_fixture_node_and_layout(fixture)
  match find_component_subtree(node, layout, fixture.target_node_id()) {
    Some((target_node, target_layout)) => {
      inspect(target_node.id, content="vrt-target#s-root")
      inspect(target_layout.id, content="vrt-target#s-root")
      assert_true(target_layout.width > 0.0)
      assert_true(target_layout.height > 0.0)
    }
    None => panic()
  }
}

///|
test "component fixture normalization only re-anchors root layout" {
  let fixture = component_fixture_xs()
  let (_, layout) = render_component_subtree(fixture)
  let normalized = normalize_component_layout(layout)
  assert_eq(normalized.x, 0.0)
  assert_eq(normalized.y, 0.0)
  assert_eq(normalized.children.length(), layout.children.length())
}

///|
test "component fixture image artifact is non-empty" {
  let artifact = render_component_image_artifact(component_fixture_xs())
  assert_true(artifact.length() > 64)
}

///|
test "component fixture landmark artifact keeps component landmark structure" {
  let artifact = render_component_landmark_artifact(component_fixture_s())
  inspect(artifact.contains("\"role\":\"region\""), content="true")
  inspect(artifact.contains("\"role\":\"navigation\""), content="true")
  inspect(artifact.contains("\"role\":\"contentinfo\""), content="true")
}

///|
test "bench_component_landmarks_xs" (b : @bench.T) {
  let fixture = component_fixture_xs()
  b.bench(name="component_landmarks_xs", fn() {
    b.keep(render_component_landmark_artifact(fixture))
  })
}

///|
test "bench_component_landmarks_s" (b : @bench.T) {
  let fixture = component_fixture_s()
  b.bench(name="component_landmarks_s", fn() {
    b.keep(render_component_landmark_artifact(fixture))
  })
}

///|
test "bench_component_landmarks_m" (b : @bench.T) {
  let fixture = component_fixture_m()
  b.bench(name="component_landmarks_m", fn() {
    b.keep(render_component_landmark_artifact(fixture))
  })
}

///|
test "bench_component_landmarks_l" (b : @bench.T) {
  let fixture = component_fixture_l()
  b.bench(name="component_landmarks_l", fn() {
    b.keep(render_component_landmark_artifact(fixture))
  })
}

///|
test "bench_component_layout_xs" (b : @bench.T) {
  let fixture = component_fixture_xs()
  b.bench(name="component_layout_xs", fn() {
    b.keep(render_component_layout_artifact(fixture))
  })
}

///|
test "bench_component_layout_s" (b : @bench.T) {
  let fixture = component_fixture_s()
  b.bench(name="component_layout_s", fn() {
    b.keep(render_component_layout_artifact(fixture))
  })
}

///|
test "bench_component_layout_m" (b : @bench.T) {
  let fixture = component_fixture_m()
  b.bench(name="component_layout_m", fn() {
    b.keep(render_component_layout_artifact(fixture))
  })
}

///|
test "bench_component_layout_l" (b : @bench.T) {
  let fixture = component_fixture_l()
  b.bench(name="component_layout_l", fn() {
    b.keep(render_component_layout_artifact(fixture))
  })
}

///|
test "bench_component_image_xs" (b : @bench.T) {
  let fixture = component_fixture_xs()
  b.bench(name="component_image_xs", fn() {
    b.keep(render_component_image_artifact(fixture))
  })
}

///|
test "bench_component_image_s" (b : @bench.T) {
  let fixture = component_fixture_s()
  b.bench(name="component_image_s", fn() {
    b.keep(render_component_image_artifact(fixture))
  })
}

///|
test "bench_component_image_m" (b : @bench.T) {
  let fixture = component_fixture_m()
  b.bench(name="component_image_m", fn() {
    b.keep(render_component_image_artifact(fixture))
  })
}

///|
test "bench_component_image_l" (b : @bench.T) {
  let fixture = component_fixture_l()
  b.bench(name="component_image_l", fn() {
    b.keep(render_component_image_artifact(fixture))
  })
}

///|
test "bench_component_phase_node_layout_m" (b : @bench.T) {
  let fixture = component_fixture_m()
  let ctx = fixture.render_ctx()
  let css = fixture.external_css()
  b.bench(name="component_phase_node_layout_m", fn() {
    b.keep(
      @renderer.render_to_node_and_layout_with_external_css(
        fixture.html,
        ctx,
        css,
      ),
    )
  })
}

///|
test "bench_component_phase_extract_m" (b : @bench.T) {
  let fixture = component_fixture_m()
  let (node, layout) = render_fixture_node_and_layout(fixture)
  let target_id = fixture.target_node_id()
  b.bench(name="component_phase_extract_m", fn() {
    b.keep(find_component_subtree(node, layout, target_id))
  })
}

///|
test "bench_component_phase_layout_serialize_m" (b : @bench.T) {
  let fixture = component_fixture_m()
  let (_, layout) = render_component_subtree(fixture)
  let normalized = normalize_component_layout(layout)
  b.bench(name="component_phase_layout_serialize_m", fn() {
    b.keep(@renderer.layout_to_json(normalized))
  })
}

///|
test "bench_component_phase_aom_build_m" (b : @bench.T) {
  let fixture = component_fixture_m()
  let target = get_component_root_element(fixture)
  b.bench(name="component_phase_aom_build_m", fn() {
    b.keep(@aom.build_accessibility_tree_from_element(target))
  })
}

///|
test "bench_component_phase_landmark_extract_m" (b : @bench.T) {
  let fixture = component_fixture_m()
  let tree = build_component_a11y_tree(fixture)
  b.bench(name="component_phase_landmark_extract_m", fn() {
    b.keep(collect_landmark_forest(tree.root))
  })
}

///|
test "bench_component_phase_landmark_serialize_m" (b : @bench.T) {
  let fixture = component_fixture_m()
  let tree = build_component_a11y_tree(fixture)
  let landmarks = collect_landmark_forest(tree.root)
  b.bench(name="component_phase_landmark_serialize_m", fn() {
    b.keep(render_landmark_forest_json(landmarks))
  })
}

///|
test "bench_component_phase_paint_m" (b : @bench.T) {
  let fixture = component_fixture_m()
  let (node, layout) = render_component_subtree(fixture)
  let normalized = normalize_component_layout(layout)
  b.bench(name="component_phase_paint_m", fn() {
    b.keep(@paint.from_node_and_layout(node, normalized))
  })
}

///|
test "bench_component_phase_raster_m" (b : @bench.T) {
  let fixture = component_fixture_m()
  let (paint_node, width, height) = render_component_paint_node(fixture)
  b.bench(name="component_phase_raster_m", fn() {
    b.keep(raster_component_paint(paint_node, width, height))
  })
}

///|
test "bench_component_phase_encode_m" (b : @bench.T) {
  let fixture = component_fixture_m()
  let (paint_node, width, height) = render_component_paint_node(fixture)
  let (fb, palette) = raster_component_paint(paint_node, width, height)
  b.bench(name="component_phase_encode_m", fn() {
    b.keep(@image.framebuffer_to_rgba_base64(fb, palette))
  })
}

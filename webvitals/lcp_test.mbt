///|
test "LCPCandidate: basic creation" {
  let candidate = LCPCandidate::new(
    "img1",
    Image(src="hero.png"),
    0.0,
    0.0,
    800.0,
    400.0,
  )
  inspect(candidate.size, content="320000")
  inspect(candidate.is_rendered(), content="false")
}

///|
test "LCPCandidate: text block is immediately rendered" {
  let text = LCPCandidate::new("heading", TextBlock, 0.0, 0.0, 500.0, 50.0)
    .with_resource_loaded(true)
    .with_render_time(100.0)
  inspect(text.is_rendered(), content="true")
  inspect(text.get_lcp_time(), content="Some(100)")
}

///|
test "LCPCandidate: image requires resource load" {
  let img = LCPCandidate::new(
    "img1",
    Image(src="test.png"),
    0.0,
    0.0,
    200.0,
    100.0,
  ).with_render_time(100.0)
  // Not rendered yet (resource not loaded)
  inspect(img.is_rendered(), content="false")

  // After resource loaded
  let img2 = img.with_resource_loaded(true)
  inspect(img2.is_rendered(), content="true")
}

///|
test "LCPCandidate: LCP time for images is max of render and load time" {
  let img = LCPCandidate::new(
      "img1",
      Image(src="test.png"),
      0.0,
      0.0,
      200.0,
      100.0,
    )
    .with_resource_loaded(true)
    .with_render_time(100.0)
    .with_load_time(150.0)
  // LCP time is max(100, 150) = 150
  inspect(img.get_lcp_time(), content="Some(150)")
  let img2 = LCPCandidate::new(
      "img2",
      Image(src="test2.png"),
      0.0,
      0.0,
      200.0,
      100.0,
    )
    .with_resource_loaded(true)
    .with_render_time(200.0)
    .with_load_time(50.0)
  // LCP time is max(200, 50) = 200
  inspect(img2.get_lcp_time(), content="Some(200)")
}

///|
test "LCPTracker: tracks largest rendered candidate" {
  let tracker = LCPTracker::new(1920.0, 1080.0)

  // Small text block
  let small = LCPCandidate::new("small", TextBlock, 0.0, 0.0, 100.0, 20.0)
    .with_resource_loaded(true)
    .with_render_time(50.0)
  tracker.add_candidate(small)

  // Large image (not rendered yet)
  let large_img = LCPCandidate::new(
    "hero",
    Image(src="hero.png"),
    0.0,
    100.0,
    800.0,
    400.0,
  )
  tracker.add_candidate(large_img)

  // Current LCP is small text (only rendered candidate)
  match tracker.get_lcp() {
    Some(lcp) => inspect(lcp.element_id, content="small")
    None => panic()
  }

  // After image loads
  tracker.on_resource_loaded("hero", 100.0)
  tracker.on_element_rendered("hero", 120.0)

  // Now LCP is the larger image
  match tracker.get_lcp() {
    Some(lcp) => inspect(lcp.element_id, content="hero")
    None => panic()
  }
}

///|
test "LCPTracker: viewport filtering" {
  let tracker = LCPTracker::new(800.0, 600.0)

  // Element completely outside viewport (below)
  let outside = LCPCandidate::new("outside", TextBlock, 0.0, 700.0, 100.0, 50.0)
    .with_resource_loaded(true)
    .with_render_time(10.0)
  tracker.add_candidate(outside)

  // Should not be tracked
  inspect(tracker.get_lcp() is None, content="true")

  // Element partially in viewport
  let partial = LCPCandidate::new("partial", TextBlock, 750.0, 0.0, 100.0, 50.0)
    .with_resource_loaded(true)
    .with_render_time(20.0)
  tracker.add_candidate(partial)

  // Should be tracked
  match tracker.get_lcp() {
    Some(lcp) => inspect(lcp.element_id, content="partial")
    None => panic()
  }
}

///|
test "LCPTracker: finalization stops tracking" {
  let tracker = LCPTracker::new(800.0, 600.0)
  let text1 = LCPCandidate::new("text1", TextBlock, 0.0, 0.0, 200.0, 50.0)
    .with_resource_loaded(true)
    .with_render_time(10.0)
  tracker.add_candidate(text1)

  // Finalize (simulating user input)
  tracker.finalize()
  inspect(tracker.is_finalized(), content="true")

  // Try to add larger element after finalization
  let larger = LCPCandidate::new("larger", TextBlock, 0.0, 100.0, 400.0, 100.0)
    .with_resource_loaded(true)
    .with_render_time(50.0)
  tracker.add_candidate(larger)

  // LCP should still be text1
  match tracker.get_lcp() {
    Some(lcp) => inspect(lcp.element_id, content="text1")
    None => panic()
  }
}

///|
test "LCPTracker: LCP ready status" {
  let tracker = LCPTracker::new(800.0, 600.0)
  inspect(tracker.is_lcp_ready(), content="false")

  // Add unrendered image
  let img = LCPCandidate::new(
    "img",
    Image(src="test.png"),
    0.0,
    0.0,
    400.0,
    200.0,
  )
  tracker.add_candidate(img)
  inspect(tracker.is_lcp_ready(), content="false")

  // Render and load
  tracker.on_element_rendered("img", 100.0)
  inspect(tracker.is_lcp_ready(), content="false") // Still not loaded
  tracker.on_resource_loaded("img", 150.0)
  inspect(tracker.is_lcp_ready(), content="true") // Now ready
}

///|
test "ContentReadiness: interaction ready" {
  let readiness = ContentReadiness::new()
  inspect(readiness.is_interaction_ready(), content="false")
  let ready = ContentReadiness::{
    lcp_ready: true,
    lcp_time: Some(100.0),
    critical_resources_loaded: true,
    a11y_ready: true,
  }
  inspect(ready.is_interaction_ready(), content="true")
  let partial = ContentReadiness::{
    lcp_ready: true,
    lcp_time: Some(100.0),
    critical_resources_loaded: true,
    a11y_ready: false, // a11y not ready
  }
  inspect(partial.is_interaction_ready(), content="false")
}

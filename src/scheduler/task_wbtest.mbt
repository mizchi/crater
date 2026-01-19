///|
/// Scheduler Tests

// =============================================================================
// Task Tests
// =============================================================================

///|
test "Task creation with no dependencies starts as Ready" {
  reset_task_id_counter()
  let task = Task::new(ComputeLayout, MainThreadOnly)
  inspect(task.state, content="Ready")
  inspect(task.is_ready(), content="true")
}

///|
test "Task with dependencies starts as Pending" {
  reset_task_id_counter()
  let dep_id = TaskId(999)
  let task = Task::new(ComputeLayout, MainThreadOnly, dependencies=[dep_id])
  inspect(task.state, content="Pending")
  inspect(task.is_ready(), content="false")
}

///|
test "TaskAction source detection" {
  inspect(ParseHTMLChunk(html="<div>").source(), content="DOM")
  inspect(ParseCSS(source=".foo {}").source(), content="Styling")
  inspect(ComputeStyle(node_ids=[]).source(), content="Styling")
  inspect(ComputeLayout.source(), content="Layout")
  inspect(
    FetchResource(url="test.png", resource_type=Image).source(),
    content="Networking",
  )
  inspect(DecodeImage(resource_id=1).source(), content="ImageDecode")
  inspect(ExecuteScript(source="").source(), content="Scripting")
}

///|
test "TaskAction internal vs external" {
  inspect(ParseHTMLChunk(html="").is_internal(), content="true")
  inspect(ParseCSS(source="").is_internal(), content="true")
  inspect(ComputeStyle(node_ids=[]).is_internal(), content="true")
  inspect(ComputeLayout.is_internal(), content="true")
  inspect(
    FetchResource(url="", resource_type=Image).is_internal(),
    content="false",
  )
  inspect(DecodeImage(resource_id=1).is_internal(), content="false")
  inspect(ExecuteScript(source="").is_internal(), content="false")
}

// =============================================================================
// TaskQueue Tests
// =============================================================================

///|
test "TaskQueue basic operations" {
  reset_task_id_counter()
  let queue = TaskQueue::new()
  inspect(queue.is_empty(), content="true")
  let task = Task::new(ComputeLayout, MainThreadOnly)
  queue.push(task)
  inspect(queue.length(), content="1")
  inspect(queue.is_empty(), content="false")
}

///|
test "TaskQueue get ready tasks" {
  reset_task_id_counter()
  let queue = TaskQueue::new()

  // Ready task
  let task1 = Task::new(ComputeLayout, MainThreadOnly)
  queue.push(task1)

  // Pending task (has dependency)
  let task2 = Task::new(ComputeStyle(node_ids=[]), MainThreadOnly, dependencies=[
    TaskId(999),
  ])
  queue.push(task2)
  let ready = queue.get_ready()
  inspect(ready.length(), content="1")
}

///|
test "TaskQueue parallel vs main thread" {
  reset_task_id_counter()
  let queue = TaskQueue::new()

  // Parallel task
  let parallel = Task::new(DecodeImage(resource_id=1), Parallel)
  queue.push(parallel)

  // Main thread task
  let main = Task::new(ComputeLayout, MainThreadOnly)
  queue.push(main)
  inspect(queue.get_parallel_ready().length(), content="1")
  inspect(queue.get_main_thread_ready().length(), content="1")
}

// =============================================================================
// Scheduler Tests
// =============================================================================

///|
test "Scheduler enqueue and poll" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let task_id = scheduler.enqueue(ComputeLayout, MainThreadOnly)
  inspect(scheduler.task_count(), content="1")
  inspect(scheduler.ready_count(), content="1")
  let ready = scheduler.poll_ready()
  inspect(ready.length(), content="1")

  // Task should now be Running
  match scheduler.find_task(task_id) {
    Some(task) => inspect(task.state, content="Running")
    None => panic()
  }
}

///|
test "Scheduler dependency resolution" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()

  // First task (no dependencies)
  let first_id = scheduler.enqueue(ParseHTMLChunk(html="<div>"), MainThreadOnly)

  // Second task (depends on first)
  let second_id = scheduler.enqueue_after(
    ComputeStyle(node_ids=[]),
    MainThreadOnly,
    [first_id],
  )

  // Only first should be ready
  inspect(scheduler.ready_count(), content="1")
  inspect(scheduler.pending_count(), content="1")

  // Poll and complete first task
  let ready = scheduler.poll_ready()
  inspect(ready.length(), content="1")

  // Complete the first task
  let _ = scheduler.complete(first_id, Success(new_tasks=[]))

  // Now second should be ready
  inspect(scheduler.ready_count(), content="1")
  inspect(scheduler.pending_count(), content="0")

  // Verify second task is now ready
  match scheduler.find_task(second_id) {
    Some(task) => inspect(task.state, content="Ready")
    None => panic()
  }
}

///|
test "Scheduler parallel polling" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()

  // Add parallel task
  let _ = scheduler.enqueue(DecodeImage(resource_id=1), Parallel)

  // Add main thread task
  let _ = scheduler.enqueue(ComputeLayout, MainThreadOnly)

  // Poll parallel only
  let parallel = scheduler.poll_parallel()
  inspect(parallel.length(), content="1")

  // Main thread task should still be available
  let main = scheduler.poll_main_thread()
  match main {
    Some(_) => inspect(true, content="true")
    None => panic()
  }
}

///|
test "Scheduler blocking constraint" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()

  // Add blocking script task
  let script_id = scheduler.enqueue(
    ExecuteScript(source="console.log('hello')"),
    Blocking([DOM, Styling]),
  )

  // Apply blocks when task starts running
  match scheduler.find_task(script_id) {
    Some(task) => scheduler.apply_blocks(task)
    None => panic()
  }

  // Verify sources are blocked
  inspect(scheduler.is_source_blocked(DOM), content="true")
  inspect(scheduler.is_source_blocked(Styling), content="true")
  inspect(scheduler.is_source_blocked(Layout), content="false")

  // Complete the blocking task
  let _ = scheduler.complete(script_id, Success(new_tasks=[]))

  // Verify sources are unblocked
  inspect(scheduler.is_source_blocked(DOM), content="false")
  inspect(scheduler.is_source_blocked(Styling), content="false")
}

///|
test "Scheduler task completion with new tasks" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()

  // Parse HTML task
  let parse_id = scheduler.enqueue(
    ParseHTMLChunk(html="<img src='test.png'>"),
    MainThreadOnly,
  )

  // Complete parse, generate fetch task
  let new_ids = scheduler.complete(
    parse_id,
    Success(new_tasks=[FetchResource(url="test.png", resource_type=Image)]),
  )
  inspect(new_ids.length(), content="1")
  inspect(scheduler.task_count(), content="2") // Original + new task
}

///|
test "Scheduler is_idle" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  inspect(scheduler.is_idle(), content="true")
  let task_id = scheduler.enqueue(ComputeLayout, MainThreadOnly)
  inspect(scheduler.is_idle(), content="false")

  // Poll to make it running
  let _ = scheduler.poll_ready()
  inspect(scheduler.is_idle(), content="false")

  // Complete to finish
  let _ = scheduler.complete(task_id, Success(new_tasks=[]))
  inspect(scheduler.is_idle(), content="true")
}

///|
test "Scheduler cleanup" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let task_id = scheduler.enqueue(ComputeLayout, MainThreadOnly)
  let _ = scheduler.poll_ready()
  let _ = scheduler.complete(task_id, Success(new_tasks=[]))
  inspect(scheduler.task_count(), content="1")
  let removed = scheduler.cleanup()
  inspect(removed, content="1")
  inspect(scheduler.task_count(), content="0")
}

///|
test "Scheduler task failure" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let task_id = scheduler.enqueue(
    FetchResource(url="notfound.png", resource_type=Image),
    Parallel,
  )
  let _ = scheduler.poll_ready()
  scheduler.fail(task_id, "404 Not Found")
  match scheduler.find_task(task_id) {
    Some(task) =>
      match task.state {
        Failed(msg) => inspect(msg, content="404 Not Found")
        _ => panic()
      }
    None => panic()
  }
}

// =============================================================================
// HTML Integration Tests
// =============================================================================

///|
test "discover_resources finds images" {
  let html = "<div><img src=\"test.png\"><img src=\"test2.jpg\"></div>"
  let root = @html.parse_fragment_v2(html)
  let result = discover_resources(root)
  inspect(result.resources.length(), content="2")
  inspect(result.resources[0].url, content="test.png")
  inspect(result.resources[0].resource_type, content="Image")
  inspect(result.resources[1].url, content="test2.jpg")
}

///|
test "discover_resources finds stylesheets" {
  let html = "<head><link rel=\"stylesheet\" href=\"style.css\"></head>"
  let root = @html.parse_fragment_v2(html)
  let result = discover_resources(root)
  inspect(result.resources.length(), content="1")
  inspect(result.resources[0].url, content="style.css")
  inspect(result.resources[0].resource_type, content="Stylesheet")
  inspect(result.resources[0].blocking, content="true")
}

///|
test "discover_resources finds external scripts" {
  let html = "<script src=\"app.js\"></script>"
  let root = @html.parse_fragment_v2(html)
  let result = discover_resources(root)
  inspect(result.resources.length(), content="1")
  inspect(result.resources[0].url, content="app.js")
  inspect(result.resources[0].resource_type, content="Script")
  // No async/defer, so blocking
  inspect(result.resources[0].blocking, content="true")
}

///|
test "discover_resources async script is not blocking" {
  let html = "<script src=\"app.js\" async></script>"
  let root = @html.parse_fragment_v2(html)
  let result = discover_resources(root)
  inspect(result.resources.length(), content="1")
  inspect(result.resources[0].blocking, content="false")
  inspect(result.resources[0].is_async, content="true")
}

///|
test "discover_resources defer script is not blocking" {
  let html = "<script src=\"app.js\" defer></script>"
  let root = @html.parse_fragment_v2(html)
  let result = discover_resources(root)
  inspect(result.resources.length(), content="1")
  inspect(result.resources[0].blocking, content="false")
  inspect(result.resources[0].is_defer, content="true")
}

///|
test "discover_resources finds inline styles" {
  let html = "<style>.foo { color: red; }</style>"
  let root = @html.parse_fragment_v2(html)
  let result = discover_resources(root)
  inspect(result.inline_styles.length(), content="1")
  inspect(result.inline_styles[0], content=".foo { color: red; }")
}

///|
test "discover_resources finds inline scripts" {
  let html = "<script>console.log('hello');</script>"
  let root = @html.parse_fragment_v2(html)
  let result = discover_resources(root)
  inspect(result.inline_scripts.length(), content="1")
  inspect(result.inline_scripts[0].source, content="console.log('hello');")
  inspect(result.inline_scripts[0].blocking, content="true")
}

///|
test "parse_and_schedule creates tasks" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let html = "<div><img src=\"test.png\"><link rel=\"stylesheet\" href=\"style.css\"></div>"
  let result = parse_and_schedule(scheduler, html)
  inspect(result.resource_count, content="2")
  inspect(result.fetch_tasks.length(), content="2")
  // 2 fetch tasks created
  inspect(scheduler.task_count(), content="2")
}

///|
test "parse_and_schedule with blocking resources" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let html = "<link rel=\"stylesheet\" href=\"style.css\"><script src=\"app.js\"></script>"
  let result = parse_and_schedule(scheduler, html)
  // Both stylesheet and script are blocking
  inspect(result.blocking_tasks.length(), content="2")
}

///|
test "parse_and_schedule with inline content" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let html = "<style>.a{}</style><script>x=1</script>"
  let result = parse_and_schedule(scheduler, html)
  inspect(result.inline_style_count, content="1")
  inspect(result.inline_script_count, content="1")
  inspect(result.style_tasks.length(), content="1")
  inspect(result.script_tasks.length(), content="1")
}

// =============================================================================
// CSS Integration Tests
// =============================================================================

///|
test "StyleManager add stylesheet source" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let style_manager = StyleManager::new(scheduler)
  let css = ".foo { color: red; }"
  let stylesheet = style_manager.add_stylesheet_source(css)
  inspect(stylesheet.rules.length(), content="1")
}

///|
test "StyleManager add inline style" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let style_manager = StyleManager::new(scheduler)
  style_manager.add_inline_style("elem1", "color: blue; font-size: 16px")
  // Check inline styles are stored
  match style_manager.inline_styles.get("elem1") {
    Some(decls) => inspect(decls.length(), content="2")
    None => panic()
  }
}

///|
test "StyleManager compute style with element" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let style_manager = StyleManager::new(scheduler)

  // Add a stylesheet
  let _ = style_manager.add_stylesheet_source(".test { width: 100px; }")

  // Create a selector element with class "test"
  let elem = @selector.Element::new("div").add_class("test").set_id("myid")
  let cascaded = style_manager.compute_style(elem)

  // Should have width from the rule
  inspect(cascaded.has("width"), content="true")
  inspect(cascaded.get_value("width"), content="Some(\"100px\")")
}

///|
test "StyleManager invalidate styles" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let style_manager = StyleManager::new(scheduler)

  // Add a stylesheet
  let _ = style_manager.add_stylesheet_source(".test { width: 100px; }")

  // Compute style to cache it
  let elem = @selector.Element::new("div").add_class("test").set_id("myid")
  let _ = style_manager.compute_style(elem)

  // Cache should have the computed style
  inspect(style_manager.computed_styles.contains("myid"), content="true")

  // Invalidate
  style_manager.invalidate_all_styles()
  inspect(style_manager.computed_styles.is_empty(), content="true")
}

///|
test "StyleManager schedule css parse" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let style_manager = StyleManager::new(scheduler)
  let task_id = style_manager.schedule_parse_css(".foo { color: red; }")
  inspect(scheduler.task_count(), content="1")
  match scheduler.find_task(task_id) {
    Some(task) =>
      match task.action {
        ParseCSS(_) => inspect(true, content="true")
        _ => panic()
      }
    None => panic()
  }
}

///|
test "StyleManager on_css_parsed" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let style_manager = StyleManager::new(scheduler)
  let result = style_manager.on_css_parsed(".foo { color: red; }")
  inspect(result.rule_count, content="1")
  inspect(style_manager.stylesheets.length(), content="1")
}

///|
test "html_element_to_selector converts element" {
  let html_elem : @html.Element = {
    tag: "div",
    id: Some("myid"),
    classes: ["foo", "bar"],
    style: None,
    attributes: {},
    children: [],
  }
  let sel_elem = html_element_to_selector(html_elem)
  inspect(sel_elem.tag_name, content="div")
  inspect(sel_elem.id, content="Some(\"myid\")")
  inspect(sel_elem.has_class("foo"), content="true")
  inspect(sel_elem.has_class("bar"), content="true")
}

///|
test "DocumentStyleCoordinator basic flow" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let coordinator = DocumentStyleCoordinator::new(scheduler)

  // Initially not ready (no stylesheets registered yet)
  inspect(coordinator.is_ready_for_style(), content="false")

  // Simulate fetching a stylesheet
  let result = coordinator.on_stylesheet_fetched(".test { width: 50px; }")
  inspect(result.rule_count, content="1")
}

///|
test "split_by_semicolon" {
  let result = split_by_semicolon("a: 1; b: 2; c: 3")
  inspect(result.length(), content="3")
  inspect(result[0], content="a: 1")
  inspect(result[1], content=" b: 2")
  inspect(result[2], content=" c: 3")
}

///|
test "parse_inline_declarations" {
  let decls = parse_inline_declarations("color: red; font-size: 16px")
  inspect(decls.length(), content="2")
}

///|
test "parse_inline_declarations with important" {
  let decls = parse_inline_declarations("color: red !important")
  inspect(decls.length(), content="1")
  inspect(decls[0].importance, content="Important")
}

// =============================================================================
// Layout Integration Tests
// =============================================================================

///|
test "LayoutManager new" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let manager = LayoutManager::new(scheduler)
  inspect(manager.get_tree() is None, content="true")
  let stats = manager.get_stats()
  inspect(stats.full_layout_count, content="0")
  inspect(stats.incremental_layout_count, content="0")
}

///|
test "LayoutManager schedule layout" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let manager = LayoutManager::new(scheduler)
  let task_id = manager.schedule_layout()
  inspect(scheduler.task_count(), content="1")
  match scheduler.find_task(task_id) {
    Some(task) =>
      match task.action {
        ComputeLayout => inspect(true, content="true")
        _ => panic()
      }
    None => panic()
  }
}

///|
test "LayoutManager schedule layout after dependencies" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let manager = LayoutManager::new(scheduler)

  // Create dependency tasks
  let css_task = scheduler.enqueue(ParseCSS(source=".foo {}"), MainThreadOnly)
  let layout_task = manager.schedule_layout_after([css_task])

  // Layout task should be pending (waiting for CSS)
  match scheduler.find_task(layout_task) {
    Some(task) => inspect(task.state, content="Pending")
    None => panic()
  }

  // Complete CSS task
  let _ = scheduler.complete(css_task, Success(new_tasks=[]))

  // Layout task should now be ready
  match scheduler.find_task(layout_task) {
    Some(task) => inspect(task.state, content="Ready")
    None => panic()
  }
}

///|
test "LayoutManager schedule urgent layout" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let manager = LayoutManager::new(scheduler)
  let task_id = manager.schedule_layout_urgent()
  match scheduler.find_task(task_id) {
    Some(task) => inspect(task.priority, content="100")
    None => panic()
  }
}

///|
test "LayoutManager execute layout without tree" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let manager = LayoutManager::new(scheduler)
  let result = manager.execute_layout()
  // No tree means we can't do incremental layout
  inspect(result.was_incremental, content="false")
  inspect(result.pending_images, content="0")
  inspect(result.layout.width, content="0")
}

///|
test "LayoutManager schedule resize without tree" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let manager = LayoutManager::new(scheduler)
  let result = manager.schedule_resize(1024.0, 768.0)
  inspect(result.resized, content="false")
  inspect(result.layout_task is None, content="true")
}

///|
test "LayoutManager get pending images without tree" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let manager = LayoutManager::new(scheduler)
  let pending = manager.get_pending_images()
  inspect(pending.length(), content="0")
}

///|
test "LayoutManager schedule image decode" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let manager = LayoutManager::new(scheduler)
  let rid = @tree.ResourceId(42)
  let task_id = manager.schedule_image_decode(rid)
  inspect(scheduler.task_count(), content="1")
  match scheduler.find_task(task_id) {
    Some(task) =>
      match task.action {
        DecodeImage(resource_id=id) => inspect(id, content="42")
        _ => panic()
      }
    None => panic()
  }
}

///|
test "DocumentRenderCoordinator new" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let coordinator = DocumentRenderCoordinator::new(scheduler)
  inspect(coordinator.is_ready_for_render(), content="false")
}

///|
test "DocumentRenderCoordinator on stylesheet fetched" {
  reset_task_id_counter()
  let scheduler = Scheduler::new()
  let coordinator = DocumentRenderCoordinator::new(scheduler)
  let result = coordinator.on_stylesheet_fetched(".foo { width: 100px; }")
  inspect(result.rule_count, content="1")
}

///|
test "LayoutStats fields" {
  let stats : LayoutStats = {
    full_layout_count: 5,
    incremental_layout_count: 10,
    pending_images: 3,
  }
  inspect(stats.full_layout_count, content="5")
  inspect(stats.incremental_layout_count, content="10")
  inspect(stats.pending_images, content="3")
}

///|
test "LayoutComputeResult fields" {
  let layout : @types.Layout = {
    id: "test",
    x: 10.0,
    y: 20.0,
    width: 100.0,
    height: 50.0,
    margin: @types.Rect::all(0.0),
    padding: @types.Rect::all(0.0),
    border: @types.Rect::all(0.0),
    overflow_x: @types.Overflow::Visible,
    overflow_y: @types.Overflow::Visible,
    children: [],
    text: None,
  }
  let result : LayoutComputeResult = {
    layout,
    was_incremental: true,
    pending_images: 2,
  }
  inspect(result.was_incremental, content="true")
  inspect(result.pending_images, content="2")
  inspect(result.layout.width, content="100")
}

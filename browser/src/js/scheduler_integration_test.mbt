///|
/// Tests for Scheduler Integration

///|
test "enqueue_script creates ExecuteScript task" {
  @scheduler.reset_task_id_counter()
  let scheduler = @scheduler.Scheduler::new()
  let task_id = enqueue_script(scheduler, "console.log('hello')", false)

  // Verify task was created
  match scheduler.find_task(task_id) {
    Some(task) =>
      match task.action {
        @scheduler.ExecuteScript(source~) =>
          inspect(source, content="console.log('hello')")
        _ => assert_true(false) // Should be ExecuteScript
      }
    None => assert_true(false) // Task should exist
  }
}

///|
test "enqueue_script with blocking creates blocking task" {
  @scheduler.reset_task_id_counter()
  let scheduler = @scheduler.Scheduler::new()
  let task_id = enqueue_script(scheduler, "alert('blocking')", true)
  match scheduler.find_task(task_id) {
    Some(task) =>
      match task.constraint {
        @scheduler.Blocking(sources) =>
          // Should block DOM source
          assert_true(sources.contains(@scheduler.DOM))
        _ => assert_true(false) // Should be Blocking
      }
    None => assert_true(false)
  }
}

///|
test "ScriptExecutor executes script" {
  let dom = @dom.DomTree::new()

  // Create initial DOM structure
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let executor = ScriptExecutor::new(dom)

  // Create a script task manually
  @scheduler.reset_task_id_counter()
  let code =
    #|const div = document.createElement('div');
    #|div.setAttribute('id', 'from-scheduler');
    #|document.body.appendChild(div);
    #|'executed'
  let task = @scheduler.Task::new(
    @scheduler.ExecuteScript(source=code),
    @scheduler.MainThreadOnly,
  )
  let result = executor.execute(task)
  match result {
    @scheduler.Success(_) =>
      // Verify DOM was modified
      match dom.query_selector(doc, "#from-scheduler") {
        Ok(Some(_)) => () // Element exists - success
        _ => assert_true(false) // Element should exist
      }
    @scheduler.Failure(error~) => {
      println("Execution failed: " + error)
      assert_true(false)
    }
    @scheduler.Cancelled => assert_true(false)
  }
}

///|
test "process_script_tasks executes ready scripts" {
  @scheduler.reset_task_id_counter()
  let dom = @dom.DomTree::new()

  // Create initial DOM structure
  let html = dom.create_element("html")
  let body = dom.create_element("body")
  let doc = dom.get_document()
  let _ = dom.append_child(doc, html)
  let _ = dom.append_child(html, body)
  let scheduler = @scheduler.Scheduler::new()

  // Enqueue a script
  let _ = enqueue_script(
    scheduler, "document.body.setAttribute('data-test', 'processed')", false,
  )

  // Process script tasks
  let processed = process_script_tasks(scheduler, dom)
  inspect(processed, content="1")

  // Verify the script was executed (attribute was set)
  match dom.query_selector(doc, "body") {
    Ok(Some(body_id)) =>
      match dom.get_attribute(body_id, "data-test") {
        Ok(Some(value)) => inspect(value, content="processed")
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

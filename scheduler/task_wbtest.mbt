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

///|
/// MutationQueue - Batches DOM mutations for efficient processing
///
/// Collects mutations and processes them in batches, optimizing by:
/// - Merging multiple changes to the same node
/// - Canceling out add+remove pairs
/// - Coalescing style property changes

///|
/// Queue for batching mutations
pub struct MutationQueue {
  /// Pending mutation records
  mut records : Array[MutationRecord]
  /// Set of dirty node IDs (for dedup checking)
  dirty_nodes : Map[Int, Bool]
  /// Whether we're currently flushing (to handle re-entrant mutations)
  mut is_flushing : Bool
  /// Records that arrived during flush (processed in next batch)
  mut deferred : Array[MutationRecord]
}

///|
/// Result of flushing the mutation queue
pub struct FlushResult {
  /// Number of mutation records processed
  processed : Int
  /// Number of unique nodes affected
  nodes_affected : Int
  /// Whether any mutation affects layout (vs paint-only)
  needs_layout : Bool
} derive(Show)

///|
/// Create a new empty mutation queue
pub fn MutationQueue::new() -> MutationQueue {
  { records: [], dirty_nodes: {}, is_flushing: false, deferred: [] }
}

///|
/// Add a mutation record to the queue
pub fn MutationQueue::push(
  self : MutationQueue,
  record : MutationRecord,
) -> Unit {
  if self.is_flushing {
    // Queue for next batch to avoid mutation during iteration
    self.deferred.push(record)
  } else {
    self.records.push(record)
    self.dirty_nodes[record.target.to_int()] = true
  }
}

///|
/// Check if queue is empty
pub fn MutationQueue::is_empty(self : MutationQueue) -> Bool {
  self.records.is_empty()
}

///|
/// Get number of pending mutations
pub fn MutationQueue::length(self : MutationQueue) -> Int {
  self.records.length()
}

///|
/// Check if a node has pending mutations
pub fn MutationQueue::has_pending(self : MutationQueue, node : NodeId) -> Bool {
  self.dirty_nodes.get(node.to_int()).unwrap_or(false)
}

///|
/// Clear all pending mutations without processing
pub fn MutationQueue::clear(self : MutationQueue) -> Unit {
  self.records = []
  self.dirty_nodes.clear()
}

///|
/// Optimize the queue by merging related mutations
pub fn MutationQueue::optimize(self : MutationQueue) -> Array[MutationRecord] {
  if self.records.is_empty() {
    return []
  }

  // Group records by target node
  let by_node : Map[Int, Array[MutationRecord]] = {}
  for record in self.records {
    let key = record.target.to_int()
    match by_node.get(key) {
      Some(arr) => arr.push(record)
      None => by_node[key] = [record]
    }
  }

  // Merge records for each node
  let optimized : Array[MutationRecord] = []
  for _node_id, records in by_node {
    let merged = merge_node_records(records)
    for r in merged {
      optimized.push(r)
    }
  }
  optimized
}

///|
/// Merge multiple records for the same node
fn merge_node_records(records : Array[MutationRecord]) -> Array[MutationRecord] {
  // Separate by type
  let style_props : Array[String] = []
  let mut has_child_list = false
  let all_added : Array[NodeId] = []
  let all_removed : Array[NodeId] = []
  let mut has_char_data = false
  let mut char_old : String? = None
  let mut char_new : String? = None
  let attr_changes : Map[String, (String?, String?)] = {}
  let target = records[0].target
  for r in records {
    match r.type_ {
      StyleChange =>
        for prop in r.changed_properties {
          if not(style_props.contains(prop)) {
            style_props.push(prop)
          }
        }
      ChildList => {
        has_child_list = true
        for n in r.added_nodes {
          // Cancel out if also in removed
          let idx = all_removed.search(n)
          match idx {
            Some(i) => {
              let _ = all_removed.remove(i)

            }
            None => all_added.push(n)
          }
        }
        for n in r.removed_nodes {
          // Cancel out if also in added
          let idx = all_added.search(n)
          match idx {
            Some(i) => {
              let _ = all_added.remove(i)

            }
            None => all_removed.push(n)
          }
        }
      }
      CharacterData => {
        if not(has_char_data) {
          char_old = r.old_value
        }
        has_char_data = true
        char_new = r.new_value
      }
      Attributes =>
        match r.attribute_name {
          Some(name) => {
            let (old, _) = attr_changes
              .get(name)
              .unwrap_or((r.old_value, r.new_value))
            attr_changes[name] = (old, r.new_value)
          }
          None => ()
        }
    }
  }

  // Build merged records
  let result : Array[MutationRecord] = []
  if style_props.length() > 0 {
    result.push(MutationRecord::style_change(target, style_props))
  }
  if has_child_list && (all_added.length() > 0 || all_removed.length() > 0) {
    result.push(
      MutationRecord::child_list(target, added=all_added, removed=all_removed),
    )
  }
  if has_char_data {
    result.push(
      MutationRecord::character_data(
        target,
        old_value=char_old,
        new_value=char_new,
      ),
    )
  }
  for name, values in attr_changes {
    let (old, new) = values
    // Skip if value unchanged
    match (old, new) {
      (Some(o), Some(n)) if o == n => continue
      _ => ()
    }
    result.push(
      MutationRecord::attribute(target, name, old_value=old, new_value=new),
    )
  }
  result
}

///|
/// Flush the queue and return optimized records for processing
/// The caller is responsible for applying these to the layout tree
pub fn MutationQueue::flush(
  self : MutationQueue,
) -> (Array[MutationRecord], FlushResult) {
  if self.records.is_empty() {
    return ([], { processed: 0, nodes_affected: 0, needs_layout: false })
  }
  self.is_flushing = true
  let optimized = self.optimize()
  let nodes_affected = self.dirty_nodes.length()
  let needs_layout = optimized.iter().any(fn(r) { r.affects_layout() })
  let result : FlushResult = {
    processed: optimized.length(),
    nodes_affected,
    needs_layout,
  }

  // Clear current batch
  self.records = []
  self.dirty_nodes.clear()
  self.is_flushing = false

  // Move deferred to main queue for next batch
  if self.deferred.length() > 0 {
    self.records = self.deferred
    for r in self.deferred {
      self.dirty_nodes[r.target.to_int()] = true
    }
    self.deferred = []
  }
  (optimized, result)
}

///|
/// Process mutations with a callback for each record
/// Returns the flush result
pub fn[T] MutationQueue::flush_with(
  self : MutationQueue,
  handler : (MutationRecord) -> T,
) -> (Array[T], FlushResult) {
  let (records, result) = self.flush()
  let results : Array[T] = []
  for record in records {
    results.push(handler(record))
  }
  (results, result)
}

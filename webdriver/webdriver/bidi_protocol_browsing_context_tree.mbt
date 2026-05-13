///|
/// Build tree result for browsingContext.getTree
fn BidiProtocol::build_context_tree(
  self : BidiProtocol,
  max_depth : Int?,
) -> Array[Json] {
  let contexts : Array[Json] = []
  for ctx_id in self.manager.list_sessions() {
    if self.context_parent.get(ctx_id) == None {
      match self.build_context_entry(ctx_id, true, 0, max_depth) {
        Some(entry) => contexts.push(entry)
        None => ()
      }
    }
  }
  contexts
}

///|
fn BidiProtocol::resolve_get_tree_contexts(
  self : BidiProtocol,
  request_id : Int,
  params : Json?,
) -> Array[Json]? {
  match get_param_raw_with_alias(params, "maxDepth", "max_depth") {
    Some(Number(n, ..)) => {
      if n < 0.0 {
        self.send_error(
          request_id, "invalid argument", "maxDepth must be a non-negative integer",
        )
        return None
      }
      let int_val = n.to_int64()
      if n != int_val.to_double() || n > 9007199254740991.0 {
        self.send_error(
          request_id, "invalid argument", "maxDepth must be a non-negative integer",
        )
        return None
      }
    }
    None => ()
    Some(_) => {
      self.send_error(
        request_id, "invalid argument", "maxDepth must be a non-negative integer",
      )
      return None
    }
  }

  match get_param_raw(params, "root") {
    Some(String(root_id)) =>
      if !self.manager.has_session(root_id) {
        self.send_error(
          request_id,
          "no such frame",
          "Unknown context: " + root_id,
        )
        return None
      }
    Some(True)
    | Some(False)
    | Some(Number(_))
    | Some(Array(_))
    | Some(Object(_))
    | Some(Null) => {
      self.send_error(request_id, "invalid argument", "root must be a string")
      return None
    }
    None => ()
  }

  let max_depth = match
    get_param_raw_with_alias(params, "maxDepth", "max_depth") {
    Some(Number(n, ..)) => Some(n.to_int64().to_int())
    _ => None
  }
  let contexts = match get_string_param(params, "root") {
    Some(root_id) =>
      match self.build_context_entry(root_id, true, 0, max_depth) {
        Some(entry) => {
          let single : Array[Json] = []
          single.push(entry)
          single
        }
        None => []
      }
    None => self.build_context_tree(max_depth)
  }
  Some(contexts)
}

///|
/// Whitebox coverage for the single-pass DOM-ops JSON parser.
test "parse_dom_ops parses element / attribute / append ops" {
  let json =
    #|{"success":true,"value":"","logs":["a","b"],"domOps":[{"op":"createElement","id":7,"tagName":"div"},{"op":"setAttribute","id":7,"name":"class","value":"row item","hasName":true,"hasValue":true},{"op":"appendChild","parentId":0,"childId":7}]}
  let ops = parse_dom_ops(json)
  inspect(ops.length(), content="3")
  inspect(ops[0].op, content="createElement")
  inspect(ops[0].id, content="7")
  inspect(ops[0].tag_name, content="div")
  inspect(ops[1].op, content="setAttribute")
  inspect(ops[1].name, content="class")
  inspect(ops[1].value, content="row item")
  inspect(ops[1].has_name, content="true")
  inspect(ops[1].has_value, content="true")
  inspect(ops[2].op, content="appendChild")
  inspect(ops[2].parent_id, content="0")
  inspect(ops[2].child_id, content="7")
}

///|
test "parse_single_dom_op handles escapes, negatives, and missing fields" {
  let json =
    #|{"op":"setAttribute","id":-3,"name":"data","value":"a\"b\\c","hasName":true}
  let op = parse_single_dom_op(json)
  inspect(op.op, content="setAttribute")
  inspect(op.id, content="-3")
  inspect(op.name, content="data")
  inspect(
    op.value,
    content=(
      #|a"b\c
    ),
  )
  inspect(op.has_name, content="true")
  // Absent fields keep their defaults.
  inspect(op.has_value, content="false")
  inspect(op.child_id, content="0")
  inspect(op.text, content="")
}

///|
test "extract_json_field reads a top-level string field" {
  let json =
    #|{"success":true,"value":"hello","error":""}
  inspect(extract_json_field(json, "value"), content="hello")
  inspect(extract_json_field(json, "missing"), content="")
}

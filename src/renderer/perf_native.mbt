///|
/// Native-only performance counters for profiling build_render_root_node.
extern "C" fn renderer_clock() -> Int64 = "clock"

///|
pub let perf_selector_build_us : Ref[Int64] = { val: 0L }

///|
pub let perf_pre_checks_us : Ref[Int64] = { val: 0L }

///|
pub let perf_pseudo_us : Ref[Int64] = { val: 0L }

///|
pub let perf_child_loop_us : Ref[Int64] = { val: 0L }

///|
pub let perf_node_build_us : Ref[Int64] = { val: 0L }

///|
pub fn perf_clock_us() -> Int64 {
  renderer_clock()
}

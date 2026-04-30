///|
extern "js" fn begin_capture_perf_log(enabled : Bool) -> Unit =
  #| (enabled) => {
  #|   const g = globalThis;
  #|   if (!g.__craterPerfLogCapture) {
  #|     g.__craterPerfLogCapture = {};
  #|   }
  #|   const capture = g.__craterPerfLogCapture;
  #|   capture.output = "";
  #|   capture.previousValue = process.env.CRATER_PERF_LOG;
  #|   capture.previousWrite = process.stderr.write;
  #|   if (enabled) {
  #|     process.env.CRATER_PERF_LOG = "1";
  #|   } else {
  #|     delete process.env.CRATER_PERF_LOG;
  #|   }
  #|   process.stderr.write = (chunk) => {
  #|     capture.output += String(chunk);
  #|     return true;
  #|   };
  #| }

///|
extern "js" fn end_capture_perf_log() -> String =
  #| () => {
  #|   const capture = globalThis.__craterPerfLogCapture;
  #|   if (!capture) return "";
  #|   process.stderr.write = capture.previousWrite;
  #|   if (capture.previousValue === undefined) {
  #|     delete process.env.CRATER_PERF_LOG;
  #|   } else {
  #|     process.env.CRATER_PERF_LOG = capture.previousValue;
  #|   }
  #|   return capture.output || "";
  #| }

///|
test "perf_log is quiet by default and opt-in via env" {
  begin_capture_perf_log(false)
  perf_log("[perf:test] hidden")
  inspect(end_capture_perf_log(), content="")
  begin_capture_perf_log(true)
  perf_log("[perf:test] visible")
  inspect(end_capture_perf_log(), content="[perf:test] visible\n")
}

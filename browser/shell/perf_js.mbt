///|
extern "js" fn perf_now() -> Double =
  #| () => {
  #|   if (typeof performance !== 'undefined') return performance.now();
  #|   if (typeof process !== 'undefined') {
  #|     const [s, ns] = process.hrtime();
  #|     return s * 1000 + ns / 1e6;
  #|   }
  #|   return Date.now();
  #| }

///|
extern "js" fn perf_log(msg : String) -> Unit =
  #| (msg) => {
  #|   if (
  #|     typeof process !== 'undefined' &&
  #|     process.env &&
  #|     process.env.CRATER_PERF_LOG === '1'
  #|   ) {
  #|     process.stderr.write(msg + '\n');
  #|   }
  #| }

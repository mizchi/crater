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
  #|   if (typeof process !== 'undefined') process.stderr.write(msg + '\n');
  #| }

///|
extern "js" fn now_seconds_ffi() -> Double =
  #| () => Date.now()

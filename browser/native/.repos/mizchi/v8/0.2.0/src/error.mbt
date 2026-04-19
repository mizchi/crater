///|
/// Public error contract for V8 runtime operations.
pub suberror V8Error {
  DependencyMissing(String)
  ModuleClosed
  NativeError(String)
  PromiseClosed
  RuntimeClosed
} derive(Eq, Show)

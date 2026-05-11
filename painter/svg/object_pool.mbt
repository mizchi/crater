// ============================================================================
// Object Pooling
// ============================================================================

///|
/// Generic object pool for reusing objects
pub(all) struct ObjectPool[T] {
  available : Array[T]
  factory : () -> T
  reset : (T) -> Unit
}

///|
pub fn[T] ObjectPool::new(
  factory : () -> T,
  reset : (T) -> Unit,
  initial_size : Int,
) -> ObjectPool[T] {
  object_pool_from_msvg(@msvg.ObjectPool::new(factory, reset, initial_size))
}

///|
/// Acquire an object from the pool
pub fn[T] ObjectPool::acquire(self : ObjectPool[T]) -> T {
  object_pool_to_msvg(self).acquire()
}

///|
/// Release an object back to the pool
pub fn[T] ObjectPool::release(self : ObjectPool[T], obj : T) -> Unit {
  object_pool_to_msvg(self).release(obj)
}

///|
/// Get the number of available objects
pub fn[T] ObjectPool::available_count(self : ObjectPool[T]) -> Int {
  object_pool_to_msvg(self).available_count()
}

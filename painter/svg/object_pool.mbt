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
  ObjectPool::from_msvg(@msvg.ObjectPool::new(factory, reset, initial_size))
}

///|
/// Acquire an object from the pool
pub fn[T] ObjectPool::acquire(self : ObjectPool[T]) -> T {
  self.to_msvg().acquire()
}

///|
/// Release an object back to the pool
pub fn[T] ObjectPool::release(self : ObjectPool[T], obj : T) -> Unit {
  self.to_msvg().release(obj)
}

///|
/// Get the number of available objects
pub fn[T] ObjectPool::available_count(self : ObjectPool[T]) -> Int {
  self.to_msvg().available_count()
}

///|
fn[T] ObjectPool::from_msvg(pool : @msvg.ObjectPool[T]) -> ObjectPool[T] {
  { available: pool.available, factory: pool.factory, reset: pool.reset }
}

///|
fn[T] ObjectPool::to_msvg(self : ObjectPool[T]) -> @msvg.ObjectPool[T] {
  @msvg.ObjectPool::{
    available: self.available,
    factory: self.factory,
    reset: self.reset,
  }
}

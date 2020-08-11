import options,
       threading_primitives

# Simple fixed size thread safe ring buffer
type
  ThreadSafeRingBuffer*[capacity: static csize_t, T] = object
    data: array[capacity, T]
    head: csize_t
    tail: csize_t
    lock: SpinLock

proc addLast*[capacity: static csize_t, T](rb: var ThreadSafeRingBuffer[capacity, T]; item: T): bool =
  rb.lock.withLock:
    let next = (rb.head + 1) mod capacity
    if next != rb.tail:
      rb.data[rb.head] = item
      rb.head = next
      result = true

proc popFirst*[capacity: static csize_t, T](rb: var ThreadSafeRingBuffer[capacity, T]): Option[T] =
  rb.lock.withLock:
    if rb.tail != rb.head:
      result = some(rb.data[rb.tail])
      rb.tail = (rb.tail + 1) mod capacity
      

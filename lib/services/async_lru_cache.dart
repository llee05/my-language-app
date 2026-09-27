/// Shares pending loads and retains a bounded set of successful results.
/// Clearing or evicting a pending load prevents it from repopulating the cache.
class AsyncLruCache<K, V> {
  AsyncLruCache({required this.maxEntries, this.maxWeight, this.weightOf})
    : assert(maxEntries > 0),
      assert(maxWeight == null || maxWeight > 0);

  final int maxEntries;
  final int? maxWeight;
  final int Function(V value)? weightOf;
  final _entries = <K, _CacheEntry<V>>{};
  int _weight = 0;

  Future<V> get(K key, Future<V> Function() load) {
    final existing = _entries.remove(key);
    if (existing != null) {
      _entries[key] = existing;
      return existing.future;
    }
    final entry = _CacheEntry<V>();
    // Register the entry before even a SynchronousFuture can complete.
    entry.future = Future<V>.microtask(load).then(
      (value) {
        if (identical(_entries[key], entry)) {
          entry.weight = weightOf?.call(value) ?? 1;
          _weight += entry.weight;
          if (maxWeight != null && entry.weight > maxWeight!) {
            _remove(key);
          }
          _trim();
        }
        return value;
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_entries[key], entry)) _remove(key);
        Error.throwWithStackTrace(error, stack);
      },
    );
    _entries[key] = entry;
    _trim();
    return entry.future;
  }

  void clear() {
    _entries.clear();
    _weight = 0;
  }

  void _remove(K key) {
    final entry = _entries.remove(key);
    if (entry != null) _weight -= entry.weight;
  }

  void _trim() {
    while (_entries.length > maxEntries ||
        (maxWeight != null && _weight > maxWeight!)) {
      _remove(_entries.keys.first);
    }
  }
}

class _CacheEntry<V> {
  late final Future<V> future;
  int weight = 0;
}

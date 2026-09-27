import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/services/async_lru_cache.dart';

void main() {
  test('synchronous futures still count toward cache limits', () async {
    final cache = AsyncLruCache<String, String>(
      maxEntries: 4,
      maxWeight: 2,
      weightOf: (value) => value.length,
    );
    await cache.get('key', () => SynchronousFuture('oversized'));
    expect(await cache.get('key', () async => 'ok'), 'ok');
  });

  test('shares pending loads and retries failures', () async {
    final cache = AsyncLruCache<String, int>(maxEntries: 2);
    final pending = Completer<int>();
    var calls = 0;
    Future<int> load() {
      calls++;
      return pending.future;
    }

    final first = cache.get('word', load);
    expect(cache.get('word', load), same(first));
    final failure = expectLater(first, throwsStateError);
    pending.completeError(StateError('unavailable'));
    await failure;
    expect(calls, 1);
    expect(await cache.get('word', () async => 42), 42);
  });

  test('evicts least recently used entries and retains recent hits', () async {
    final cache = AsyncLruCache<String, int>(maxEntries: 2);
    var loads = 0;
    Future<int> read(String key) => cache.get(key, () async => ++loads);
    expect(await read('a'), 1);
    expect(await read('b'), 2);
    expect(await read('a'), 1);
    expect(await read('c'), 3);
    expect(await read('a'), 1);
    expect(await read('b'), 4);
  });

  test('invalidated pending loads cannot overwrite newer results', () async {
    final cache = AsyncLruCache<String, int>(maxEntries: 2);
    final pending = Completer<int>();
    final old = cache.get('key', () => pending.future);
    cache.clear();
    expect(await cache.get('key', () async => 2), 2);
    pending.complete(1);
    expect(await old, 1);
    expect(await cache.get('key', () async => 3), 2);
  });

  test('an old failure cannot evict a replacement load', () async {
    final cache = AsyncLruCache<String, int>(maxEntries: 1);
    final pending = Completer<int>();
    final old = cache.get('key', () => pending.future);
    final failure = expectLater(old, throwsStateError);
    cache.clear();
    await cache.get('key', () async => 2);
    pending.completeError(StateError('old failure'));
    await failure;
    expect(await cache.get('key', () async => 3), 2);
  });
}

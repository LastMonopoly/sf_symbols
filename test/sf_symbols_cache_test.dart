import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sf_symbols/sf_symbols.dart';
import 'package:sf_symbols/sf_symbols_platform_interface.dart';

class FakeSfSymbolsPlatform extends SfSymbolsPlatform
    with MockPlatformInterfaceMixin {
  int _nextTextureId = 1;
  final List<SfSymbolConfig> rendered = <SfSymbolConfig>[];
  final List<int> disposed = <int>[];

  @override
  Future<int?> init(SfSymbolConfig config) async {
    if (config.name == 'not.a.symbol') return null;
    rendered.add(config);
    return _nextTextureId++;
  }

  @override
  Future<Size?> render(int textureId) async => const Size(40, 32);

  @override
  Future<void> dispose(int textureId) async => disposed.add(textureId);

  @override
  Future<bool> isAvailable(String name) async => name != 'not.a.symbol';

  @override
  Future<SfSymbolEffectSupport> effectSupport() async =>
      SfSymbolEffectSupport.full;
}

void main() {
  late FakeSfSymbolsPlatform fake;
  late SfSymbolCache cache;

  SfSymbolConfig config(String name, {double size = 40}) =>
      SfSymbolConfig(name: name, size: size);

  setUp(() {
    fake = FakeSfSymbolsPlatform();
    SfSymbolsPlatform.instance = fake;
    cache = SfSymbolCache.instance;
    cache.clear();
    fake.disposed.clear();
    cache.maximumUnusedEntries = 48;
  });

  tearDown(() => cache.clear());

  test('renders a symbol once and shares it', () async {
    final a = await cache.acquire(config('camera'));
    final b = await cache.acquire(config('camera'));

    expect(a!.textureId, b!.textureId);
    expect(fake.rendered, hasLength(1));
    expect(cache.length, 1);
  });

  test('concurrent requests for one symbol share a single render', () async {
    final results = await Future.wait([
      for (var i = 0; i < 20; i++) cache.acquire(config('camera')),
    ]);

    expect(results.map((t) => t!.textureId).toSet(), hasLength(1));
    expect(fake.rendered, hasLength(1),
        reason: '20 concurrent requests must not register 20 textures');
  });

  test('different configs do not share a texture', () async {
    final a = await cache.acquire(config('camera'));
    final b = await cache.acquire(config('camera', size: 60));

    expect(a!.textureId, isNot(b!.textureId));
    expect(cache.length, 2);
  });

  test('keeps a released symbol for reuse rather than disposing it', () async {
    final first = await cache.acquire(config('camera'));
    cache.release(config('camera'));

    expect(fake.disposed, isEmpty);
    expect(cache.unusedLength, 1);

    final second = await cache.acquire(config('camera'));
    expect(second!.textureId, first!.textureId);
    expect(fake.rendered, hasLength(1), reason: 'must not re-render');
    expect(cache.unusedLength, 0);
  });

  test('only disposes once the last reference is gone', () async {
    cache.maximumUnusedEntries = 0;

    await cache.acquire(config('camera'));
    await cache.acquire(config('camera'));

    cache.release(config('camera'));
    expect(fake.disposed, isEmpty, reason: 'one holder remains');

    cache.release(config('camera'));
    expect(fake.disposed, [1]);
    expect(cache.length, 0);
  });

  test('evicts least recently released beyond the limit', () async {
    cache.maximumUnusedEntries = 2;

    for (final name in ['a', 'b']) {
      await cache.acquire(config(name));
      cache.release(config(name));
    }
    expect(fake.disposed, isEmpty);
    expect(cache.unusedLength, 2);

    // A third pushes past the limit, dropping the one released longest ago.
    await cache.acquire(config('c'));
    cache.release(config('c'));
    expect(fake.disposed, [1]);
    expect(cache.contains(config('a')), isFalse);

    await cache.acquire(config('d'));
    cache.release(config('d'));
    expect(fake.disposed, [1, 2]);
    expect(cache.contains(config('b')), isFalse);
    expect(cache.contains(config('d')), isTrue);
  });

  test('lowering the limit evicts immediately', () async {
    for (final name in ['a', 'b', 'c']) {
      await cache.acquire(config(name));
      cache.release(config(name));
    }

    cache.maximumUnusedEntries = 1;
    expect(fake.disposed, [1, 2]);
    expect(cache.unusedLength, 1);
  });

  test('evictUnused keeps symbols that are still in use', () async {
    await cache.acquire(config('kept'));
    await cache.acquire(config('dropped'));
    cache.release(config('dropped'));

    cache.evictUnused();

    expect(fake.disposed, [2]);
    expect(cache.contains(config('kept')), isTrue);
    expect(cache.contains(config('dropped')), isFalse);
  });

  test('an unknown symbol is not cached', () async {
    expect(await cache.acquire(config('not.a.symbol')), isNull);
    expect(cache.length, 0);
  });

  test('precache renders without holding the symbol in use', () async {
    await SfSymbol.precache(config('camera'));

    expect(fake.rendered, hasLength(1));
    expect(cache.unusedLength, 1);
    expect(cache.acquireCached(config('camera')), isNotNull);
  });

  test('acquireCached misses before a render and hits after', () async {
    expect(cache.acquireCached(config('camera')), isNull);
    await cache.acquire(config('camera'));
    expect(cache.acquireCached(config('camera')), isNotNull);
  });

  test('an animating symbol is dropped as soon as nothing shows it', () async {
    const animated = SfSymbolConfig(
      name: 'heart.fill',
      size: 40,
      effect: SfSymbolEffect.pulse,
    );

    await cache.acquire(animated);
    await cache.acquire(animated);

    // Shared while two widgets show it.
    expect(fake.rendered, hasLength(1));

    cache.release(animated);
    expect(fake.disposed, isEmpty, reason: 'one holder remains');

    cache.release(animated);
    // Not parked in the unused pool: it would keep a display link running.
    expect(fake.disposed, [1]);
    expect(cache.unusedLength, 0);
    expect(cache.contains(animated), isFalse);
  });

  test('an effect makes an otherwise identical config distinct', () {
    const still = SfSymbolConfig(name: 'heart.fill', size: 40);
    const beating = SfSymbolConfig(
      name: 'heart.fill',
      size: 40,
      effect: SfSymbolEffect.pulse,
    );

    expect(still, isNot(beating));
    expect(still.isAnimated, isFalse);
    expect(beating.isAnimated, isTrue);
  });

  test('releasing something never acquired is harmless', () {
    expect(() => cache.release(config('camera')), returnsNormally);
    expect(fake.disposed, isEmpty);
  });
}

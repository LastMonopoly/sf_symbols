import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'sf_symbols_config.dart';
import 'sf_symbols_platform_interface.dart';

/// A symbol that has been rendered natively and is ready to draw.
@immutable
class SfSymbolTexture {
  const SfSymbolTexture({required this.textureId, required this.size});

  /// The native texture, for use with a [Texture] widget.
  final int textureId;

  /// The symbol's size in logical pixels.
  final Size size;

  @override
  String toString() => 'SfSymbolTexture($textureId, $size)';
}

class _Entry {
  _Entry(this.texture);

  final SfSymbolTexture texture;
  int refCount = 0;
}

/// Shares rendered symbols between widgets.
///
/// Rendering a symbol costs a native texture and a pixel buffer, so a list of
/// a hundred rows showing the same icon would otherwise hold a hundred copies
/// of one image. Identical [SfSymbolConfig]s share a single texture instead,
/// and a symbol that is already cached is handed over synchronously, without
/// the frame of empty space an asynchronous load would leave behind.
///
/// Symbols no longer on screen are kept for a while in case they come back —
/// scrolling a list destroys and rebuilds rows constantly — up to
/// [maximumUnusedEntries], after which the least recently released is dropped.
class SfSymbolCache {
  SfSymbolCache._();

  static final SfSymbolCache instance = SfSymbolCache._();

  /// How many off-screen symbols to keep rendered. Symbols still on screen are
  /// always kept, and are not counted against this.
  int get maximumUnusedEntries => _maximumUnusedEntries;
  int _maximumUnusedEntries = 48;
  set maximumUnusedEntries(int value) {
    assert(value >= 0);
    _maximumUnusedEntries = value;
    _evict();
  }

  final Map<SfSymbolConfig, _Entry> _entries = <SfSymbolConfig, _Entry>{};
  final Map<SfSymbolConfig, Future<SfSymbolTexture?>> _pending =
      <SfSymbolConfig, Future<SfSymbolTexture?>>{};

  /// Configs with no live references, least recently released first.
  final Set<SfSymbolConfig> _unused = <SfSymbolConfig>{};

  /// How many symbols are rendered, in use or not.
  int get length => _entries.length;

  /// How many rendered symbols are currently off screen.
  int get unusedLength => _unused.length;

  /// Whether [config] is rendered and ready to hand out.
  bool contains(SfSymbolConfig config) => _entries.containsKey(config);

  /// Takes a reference to [config] if it is already rendered.
  ///
  /// Returns null if it is not, in which case use [acquire]. Callers that get
  /// a texture must [release] it.
  SfSymbolTexture? acquireCached(SfSymbolConfig config) {
    final entry = _entries[config];
    if (entry == null) return null;
    entry.refCount++;
    _unused.remove(config);
    return entry.texture;
  }

  /// Renders [config], or takes a reference to it if it is already rendered.
  ///
  /// Returns null if no symbol matches [config]. Callers that get a texture
  /// must [release] it.
  Future<SfSymbolTexture?> acquire(SfSymbolConfig config) async {
    final cached = acquireCached(config);
    if (cached != null) return cached;

    // Several widgets asking for the same symbol at once share one render
    // rather than each registering their own texture.
    final pending = _pending[config];
    if (pending != null) {
      final texture = await pending;
      if (texture == null) return null;

      final entry = _entries[config];
      // The render holds a reference until its own caller releases, so the
      // entry cannot have been evicted from under us.
      if (entry == null) return null;
      entry.refCount++;
      _unused.remove(config);
      return texture;
    }

    final render = _render(config);
    _pending[config] = render;
    // _render opens the entry already holding this call's reference.
    return render;
  }

  /// Renders [config] ahead of time, so a later [SfSymbol] draws immediately.
  Future<void> precache(SfSymbolConfig config) async {
    final texture = await acquire(config);
    if (texture != null) release(config);
  }

  /// Drops a reference taken by [acquire] or [acquireCached].
  void release(SfSymbolConfig config) {
    final entry = _entries[config];
    if (entry == null) return;

    entry.refCount--;
    if (entry.refCount > 0) return;

    entry.refCount = 0;
    _unused.add(config);
    _evict();
  }

  /// Releases every rendered symbol that is not currently on screen.
  ///
  /// Useful in response to memory pressure. Symbols still on screen are kept.
  void evictUnused() {
    for (final config in _unused.toList()) {
      _dispose(config);
    }
    _unused.clear();
  }

  Future<SfSymbolTexture?> _render(SfSymbolConfig config) async {
    try {
      final platform = SfSymbolsPlatform.instance;

      final textureId = await platform.init(config);
      if (textureId == null) return null;

      final size = await platform.render(textureId);
      if (size == null) {
        await platform.dispose(textureId);
        return null;
      }

      final texture = SfSymbolTexture(textureId: textureId, size: size);
      // Opens holding the calling acquire's reference, so the entry is never
      // evictable before that caller has seen it. Abandoning the load still
      // releases, which is what puts it in the unused pool.
      _entries[config] = _Entry(texture)..refCount = 1;
      return texture;
    } finally {
      _pending.remove(config);
    }
  }

  void _evict() {
    while (_unused.length > _maximumUnusedEntries) {
      final oldest = _unused.first;
      _unused.remove(oldest);
      _dispose(oldest);
    }
  }

  void _dispose(SfSymbolConfig config) {
    final entry = _entries.remove(config);
    if (entry == null) return;
    SfSymbolsPlatform.instance.dispose(entry.texture.textureId);
  }

  /// Drops everything, on screen or not. Only for tests.
  @visibleForTesting
  void clear() {
    for (final entry in _entries.values) {
      SfSymbolsPlatform.instance.dispose(entry.texture.textureId);
    }
    _entries.clear();
    _unused.clear();
    _pending.clear();
  }
}

import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../ast/ast.dart';

/// Entry in the LRU cache.
class _CacheEntry {
  final String key;
  final String source; // For collision detection
  final Program program;

  _CacheEntry({
    required this.key,
    required this.source,
    required this.program,
  });
}

/// LRU Cache for parsed AST programs.
/// Thread-safe for single-threaded Dart but uses LinkedHashMap for LRU ordering.
class ASTCache {
  final int capacity;
  final Map<String, _CacheEntry> _cache = {};

  ASTCache({this.capacity = 1000});

  /// Generate SHA-256 hash for source code (first 16 chars).
  String _hash(String source) {
    final bytes = utf8.encode(source);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// Retrieve cached AST program.
  /// Returns null if not found or source mismatch (collision).
  Program? get(String source) {
    final key = _hash(source);
    final entry = _cache[key];

    if (entry == null) return null;

    // Collision detection
    if (entry.source != source) return null;

    // Move to end (most recently used)
    _cache.remove(key);
    _cache[key] = entry;

    return entry.program;
  }

  /// Store AST program in cache.
  void set(String source, Program program) {
    final key = _hash(source);

    // Remove existing
    _cache.remove(key);

    // Evict oldest if at capacity
    if (_cache.length >= capacity) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest);
    }

    _cache[key] = _CacheEntry(key: key, source: source, program: program);
  }

  /// Clear all cached entries.
  void clear() {
    _cache.clear();
  }

  /// Get number of cached entries.
  int get size => _cache.length;

  /// Global default cache instance.
  static final ASTCache defaultCache = ASTCache(capacity: 1000);
}

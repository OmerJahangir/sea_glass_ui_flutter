/// 32-bit integer multiply with wraparound, matching JavaScript `Math.imul`.
///
/// Split into 16-bit halves so the product stays exact on the web, where
/// integers are doubles.
int imul32(int a, int b) {
  a &= 0xFFFFFFFF;
  b &= 0xFFFFFFFF;
  final ah = (a >> 16) & 0xFFFF;
  final al = a & 0xFFFF;
  final bh = (b >> 16) & 0xFFFF;
  final bl = b & 0xFFFF;
  final high = ((ah * bl + al * bh) & 0xFFFF) * 0x10000;
  return (al * bl + high) & 0xFFFFFFFF;
}

/// Mulberry32: a small, stable generator so a seed always tumbles the same way
/// on every platform. Matches the original JavaScript `seededRandom` exactly.
class SeededRandom {
  /// Creates a generator. Negative seeds wrap to their unsigned 32-bit value.
  SeededRandom(int seed) : _state = seed & 0xFFFFFFFF;

  int _state;

  /// Returns the next value in `[0, 1)`.
  double next() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    var n = _state;
    n = imul32(n ^ (n >> 15), n | 1);
    n = (n ^ ((n + imul32(n ^ (n >> 7), n | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    return ((n ^ (n >> 14)) & 0xFFFFFFFF) / 4294967296.0;
  }

  /// Advances the generator [count] times without using the values.
  void skip(int count) {
    for (var i = 0; i < count; i++) {
      next();
    }
  }
}

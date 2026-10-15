/// Identifier helpers. IDs are time-ordered and collision-resistant without an
/// external dependency.
library;

import 'dart:math' as math;

class Ids {
  const Ids._();
  static final math.Random _rnd = math.Random();

  static String newId([String prefix = 'id']) {
    final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final r = _rnd.nextInt(1 << 32).toRadixString(36);
    return '$prefix-$t-$r';
  }
}

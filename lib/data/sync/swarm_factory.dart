/// Selects the swarm node for the current platform.
library;

export 'swarm_factory_web.dart' if (dart.library.io) 'swarm_factory_io.dart';

/// Selects the model hub for the current platform.
library;

export 'model_hub_factory_web.dart' if (dart.library.io) 'model_hub_factory_io.dart';

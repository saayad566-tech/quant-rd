/// Selects the asset-pack manager for the current platform.
library;

export 'asset_pack_factory_web.dart' if (dart.library.io) 'asset_pack_factory_io.dart';

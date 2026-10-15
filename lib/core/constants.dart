/// Central application constants. No magic numbers or strings elsewhere.
library;

class AppInfo {
  const AppInfo._();
  static const String name = 'Quant RD';
  static const String tagline = 'Strategy Research & Backtesting';
  static const String version = '1.0.0';
  static const String buildNumber = '1';
  static const String packageId = 'com.quantrd.app';
}

class AppLimits {
  const AppLimits._();

  /// Maximum number of candles we will hold for a single dataset in memory.
  static const int maxCandlesPerDataset = 2000000;

  /// Maximum upload / import file size (bytes) for a CSV.
  static const int maxImportBytes = 250 * 1024 * 1024;

  /// Default network timeout.
  static const Duration networkTimeout = Duration(seconds: 30);

  /// Retry policy for remote fetches.
  static const int maxNetworkRetries = 3;
  static const Duration retryBaseDelay = Duration(milliseconds: 600);

  /// Asset pack download chunk size (bytes) for ranged/resumable downloads.
  static const int assetChunkBytes = 4 * 1024 * 1024;

  /// Trading days per year used for annualisation defaults.
  static const int defaultBarsPerYear = 252;
}

class StorageKeys {
  const StorageKeys._();
  static const String databaseName = 'quant_rd.db';
  static const String databaseVersion = '3';
  static const String settingsBox = 'quant_rd_settings';

  /// The workspace created on first run; also the fallback for legacy rows.
  static const String defaultWorkspaceId = 'ws-default';
  // v3 adds strategies.enabled
  static const String defaultWorkspaceName = 'Default project';

  // Secure-store keys for user supplied API credentials.
  static const String keyAlphaVantage = 'apikey.alphavantage';
  static const String keyTwelveData = 'apikey.twelvedata';
  static const String keyPolygon = 'apikey.polygon';
  static const String keyFinnhub = 'apikey.finnhub';
  static const String keyCustom = 'apikey.custom';
}

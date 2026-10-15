/// Persisted, non-secret application settings.
library;

import 'package:flutter/material.dart';

import '../../domain/knowledge/market_region.dart';
import 'backtest_config.dart';

class AppSettings {
  final ThemeMode themeMode;
  final BacktestConfig defaultConfig;
  final String currencySymbol;

  /// Base URL of the assets repository (raw or releases) used by the runtime
  /// asset-pack downloader. Empty disables remote packs.
  final String assetPackBaseUrl;

  /// Bundled sample data is offered when true (fully offline).
  final bool includeSampleData;

  /// Base URL of the model repository used by the local model hub
  /// (expects `<base>/manifest.json`). Empty disables remote models.
  final String modelBaseUrl;

  /// The active market region. Every listing in the app is filtered through it,
  /// so cross-market leakage cannot occur.
  final MarketRegion marketRegion;

  /// The User-Agent sent to SEC EDGAR. The SEC requires a descriptive agent and
  /// refuses requests without one.
  final String edgarUserAgent;

  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.defaultConfig = const BacktestConfig(),
    this.currencySymbol = '\u20b9',
    this.assetPackBaseUrl = '',
    this.includeSampleData = true,
    this.modelBaseUrl = '',
    this.marketRegion = MarketRegion.india,
    this.edgarUserAgent = '',
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    BacktestConfig? defaultConfig,
    String? currencySymbol,
    String? assetPackBaseUrl,
    bool? includeSampleData,
    String? modelBaseUrl,
    MarketRegion? marketRegion,
    String? edgarUserAgent,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        defaultConfig: defaultConfig ?? this.defaultConfig,
        currencySymbol: currencySymbol ?? this.currencySymbol,
        assetPackBaseUrl: assetPackBaseUrl ?? this.assetPackBaseUrl,
        includeSampleData: includeSampleData ?? this.includeSampleData,
        modelBaseUrl: modelBaseUrl ?? this.modelBaseUrl,
        marketRegion: marketRegion ?? this.marketRegion,
        edgarUserAgent: edgarUserAgent ?? this.edgarUserAgent,
      );

  Map<String, dynamic> toMap() => {
        'theme_mode': themeMode.name,
        'default_config': defaultConfig.toMap(),
        'currency_symbol': currencySymbol,
        'asset_pack_base_url': assetPackBaseUrl,
        'include_sample_data': includeSampleData ? 1 : 0,
        'model_base_url': modelBaseUrl,
        'market_region': marketRegion.name,
        'edgar_user_agent': edgarUserAgent,
      };

  factory AppSettings.fromMap(Map<String, dynamic> m) => AppSettings(
        themeMode: ThemeMode.values.firstWhere((e) => e.name == m['theme_mode'], orElse: () => ThemeMode.dark),
        defaultConfig: m['default_config'] is Map
            ? BacktestConfig.fromMap((m['default_config'] as Map).cast<String, dynamic>())
            : const BacktestConfig(),
        currencySymbol: (m['currency_symbol'] as String?) ?? '\u20b9',
        assetPackBaseUrl: (m['asset_pack_base_url'] as String?) ?? '',
        includeSampleData: ((m['include_sample_data'] as num?)?.toInt() ?? 1) == 1,
        modelBaseUrl: (m['model_base_url'] as String?) ?? '',
        marketRegion: MarketRegion.fromId(m['market_region'] as String?),
        edgarUserAgent: (m['edgar_user_agent'] as String?) ?? '',
      );
}

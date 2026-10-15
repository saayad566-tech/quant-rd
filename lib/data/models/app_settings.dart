/// Persisted, non-secret application settings.
library;

import 'package:flutter/material.dart';

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

  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.defaultConfig = const BacktestConfig(),
    this.currencySymbol = '\u20b9',
    this.assetPackBaseUrl = '',
    this.includeSampleData = true,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    BacktestConfig? defaultConfig,
    String? currencySymbol,
    String? assetPackBaseUrl,
    bool? includeSampleData,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        defaultConfig: defaultConfig ?? this.defaultConfig,
        currencySymbol: currencySymbol ?? this.currencySymbol,
        assetPackBaseUrl: assetPackBaseUrl ?? this.assetPackBaseUrl,
        includeSampleData: includeSampleData ?? this.includeSampleData,
      );

  Map<String, dynamic> toMap() => {
        'theme_mode': themeMode.name,
        'default_config': defaultConfig.toMap(),
        'currency_symbol': currencySymbol,
        'asset_pack_base_url': assetPackBaseUrl,
        'include_sample_data': includeSampleData ? 1 : 0,
      };

  factory AppSettings.fromMap(Map<String, dynamic> m) => AppSettings(
        themeMode: ThemeMode.values.firstWhere((e) => e.name == m['theme_mode'], orElse: () => ThemeMode.dark),
        defaultConfig: m['default_config'] is Map
            ? BacktestConfig.fromMap((m['default_config'] as Map).cast<String, dynamic>())
            : const BacktestConfig(),
        currencySymbol: (m['currency_symbol'] as String?) ?? '\u20b9',
        assetPackBaseUrl: (m['asset_pack_base_url'] as String?) ?? '',
        includeSampleData: ((m['include_sample_data'] as num?)?.toInt() ?? 1) == 1,
      );
}
